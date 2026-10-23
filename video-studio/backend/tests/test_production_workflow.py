import asyncio
import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from services.project_manager import ProjectManager
from services.render_jobs import RenderJobStore
from services.database import SQLiteDatabase
from services.voice_hub import VoiceHub
from services import render_service
from services.assembler_bridge import VideoAssemblerBridge
from services.omniroute_client import OmniRouteClient
from manim_engine import ai_scene_generator
import main as studio_api


class RenderJobStoreTests(unittest.TestCase):
    def test_job_persists_and_inflight_job_is_marked_interrupted_on_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            store = RenderJobStore(directory)
            job, created = store.create_or_get("proj_test")
            self.assertTrue(created)
            store.update(job["id"], status="rendering", progress=35)

            restarted = RenderJobStore(directory)

            self.assertEqual(restarted.get(job["id"])["status"], "interrupted")

    def test_duplicate_active_render_returns_existing_job(self):
        with tempfile.TemporaryDirectory() as directory:
            store = RenderJobStore(directory)
            first, created = store.create_or_get("proj_test")
            second, created_again = store.create_or_get("proj_test")
            self.assertTrue(created)
            self.assertFalse(created_again)
            self.assertEqual(first["id"], second["id"])

    def test_interrupted_render_reuses_job_id_when_requeued(self):
        with tempfile.TemporaryDirectory() as directory:
            store = RenderJobStore(directory)
            job, should_start = store.create_or_get("proj_test")
            self.assertTrue(should_start)
            store.update(job["id"], status="rendering", progress=52)
            store.db.update_job(job["id"], {"status": "interrupted", "message": "API reiniciada"})

            retried, should_start_again = store.create_or_get("proj_test")

            self.assertTrue(should_start_again)
            self.assertEqual(retried["id"], job["id"])
            self.assertEqual(retried["status"], "queued")
            self.assertTrue(retried["resumed"])

    def test_project_render_status_prefers_active_job_over_newer_completed_job(self):
        older_active = {"id": "render_active", "status": "rendering"}
        newer_completed = {"id": "render_done", "status": "completed"}
        fake_db = SimpleNamespace(list_jobs=lambda project_id: [newer_completed, older_active])
        with patch.object(studio_api.ProjectManager, "get_project", return_value={"project": {}, "scenes": []}), \
                patch.object(studio_api.ProjectManager, "db", fake_db):
            response = studio_api.get_latest_project_render_job("proj_test")

        self.assertEqual(response["job"], older_active)

    def test_project_render_status_returns_latest_terminal_job_when_no_job_is_active(self):
        latest = {"id": "render_failed", "status": "failed"}
        with patch.object(studio_api.ProjectManager, "get_project", return_value={"project": {}, "scenes": []}), \
                patch.object(studio_api.ProjectManager, "db", SimpleNamespace(list_jobs=lambda project_id: [latest])):
            response = studio_api.get_latest_project_render_job("proj_test")

        self.assertEqual(response["job"], latest)


class LongFormPlanningTests(unittest.TestCase):
    def test_scene_count_scales_for_one_hour_instead_of_stopping_at_45(self):
        self.assertEqual(OmniRouteClient.calculate_scene_count(3600), 300)

    def test_long_script_is_generated_in_bounded_act_calls(self):
        responses = [
            json.dumps({"title": "Acto A", "summary": "Inicio", "narration": "Texto A"}),
            json.dumps({"title": "Acto B", "summary": "Cierre", "narration": "Texto B"}),
        ]
        with patch.object(OmniRouteClient, "_chat", side_effect=responses) as chat:
            script = OmniRouteClient.generate_script("Tema largo", 360, "documental")

        self.assertEqual(script["duration_seconds"], 360)
        self.assertEqual(script["narration"], "Texto A\n\nTexto B")
        self.assertEqual(len(script["acts"]), 2)
        self.assertEqual(chat.call_count, 2)

    def test_storyboard_is_generated_in_batches_with_global_scene_ids(self):
        responses = [
            json.dumps({"visual_theme": "Vector", "scenes": [
                {"id": i, "act": 1, "title": f"Escena {i}", "narrative_text": f"Texto {i}",
                 "visual_description": "Formas vectoriales", "svg_prompt": "SVG original"}
                for i in range(1, 21)
            ]}),
            json.dumps({"visual_theme": "Vector", "scenes": [
                {"id": i, "act": 2, "title": f"Escena {i}", "narrative_text": f"Texto {i}",
                 "visual_description": "Formas vectoriales", "svg_prompt": "SVG original"}
                for i in range(21, 25)
            ]}),
        ]
        narration = " ".join(f"palabra{i}" for i in range(24))
        with patch.object(OmniRouteClient, "_chat", side_effect=responses) as chat:
            result = OmniRouteClient.generate_storyboard_from_script(
                {"topic": "Tema", "duration_seconds": 288, "narration": narration, "acts": []},
                "documental",
            )

        self.assertEqual(len(result["scenes"]), 24)
        self.assertEqual(result["scenes"][-1]["id"], 24)
        self.assertEqual(chat.call_count, 2)
        self.assertIn("palabra20", chat.call_args_list[1].args[0])
        self.assertNotIn("palabra0", chat.call_args_list[1].args[0])


class ManimSandboxTests(unittest.TestCase):
    def test_prompt_is_escaped_as_data_not_python_source(self):
        code = ai_scene_generator.generate_manim_code_heuristic('x")\nimport os; os.remove("important")')
        compile(code, "generated_scene.py", "exec")
        self.assertNotIn('import os; os.remove', code)

    def test_render_rejects_output_outside_project_motion_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(ai_scene_generator, "PROJECTS_DIR", Path(directory) / "projects"), patch.object(
                ai_scene_generator.subprocess, "run"
            ) as run:
                with self.assertRaisesRegex(ValueError, "motion/"):
                    ai_scene_generator.render_custom_scene("pass", Path(directory) / "outside" / "scene_1.webm")
            run.assert_not_called()

    def test_container_is_networkless_resource_limited_and_only_mounts_temp_workspace(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            projects = root / "projects"
            motion = projects / "proj_sandbox" / "motion"
            stickers = root / "video-studio" / "remotion" / "public" / "stickers"
            motion.mkdir(parents=True)
            stickers.mkdir(parents=True)
            calls = []

            def fake_run(command, **kwargs):
                calls.append((command, kwargs))
                if command[0] == "docker":
                    workspace = Path(next(arg.split(":", 1)[0] for arg in command if arg.endswith(":/workspace:rw")))
                    mov = workspace / "media" / "videos" / "scene_script" / "1920p30" / "scene_1.mov"
                    mov.parent.mkdir(parents=True)
                    mov.write_bytes(b"mov")
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                Path(command[-1]).write_bytes(b"webm")
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(ai_scene_generator, "BASE_DIR", root), patch.object(
                ai_scene_generator, "PROJECTS_DIR", projects
            ), patch.object(ai_scene_generator.subprocess, "run", side_effect=fake_run):
                result = ai_scene_generator.render_custom_scene("pass", motion / "scene_1.webm")

            docker_args = calls[0][0]
            self.assertIn("--network=none", docker_args)
            self.assertIn("--read-only", docker_args)
            self.assertIn("--memory=3g", docker_args)
            self.assertIn("--cpus=2", docker_args)
            self.assertEqual(sum(arg.endswith(":/workspace:rw") for arg in docker_args), 1)
            self.assertTrue(result["success"])


class ToolDiagnosticsTests(unittest.TestCase):
    def test_omniroute_reports_configuration_without_claiming_connectivity_or_exposing_key(self):
        with patch.object(studio_api, "OMNIROUTE_API_KEY", "secret-value"), patch.object(
            studio_api, "OMNIROUTE_BASE_URL", "https://omni.example"
        ):
            status = studio_api.get_tools_status()["omniroute"]

        self.assertEqual(status["status"], "configured")
        self.assertEqual(status["url"], "https://omni.example")
        self.assertNotIn("secret-value", json.dumps(status))
        self.assertIn("conectividad se comprueba", status["description"])


class SQLitePersistenceTests(unittest.TestCase):
    def test_project_and_scenes_survive_database_reopen(self):
        with tempfile.TemporaryDirectory() as directory:
            db_path = os.path.join(directory, "studio.sqlite3")
            legacy_dir = os.path.join(directory, "legacy")
            os.makedirs(legacy_dir)
            first = SQLiteDatabase(db_path, legacy_projects_dir=legacy_dir)
            metadata = {"id": "proj_persist", "status": "draft", "topic": "helado"}
            scenes = [{"id": 1, "title": "Inicio"}, {"id": 2, "title": "Cierre"}]
            first.save_project("proj_persist", metadata, scenes)

            reopened = SQLiteDatabase(db_path, legacy_projects_dir=legacy_dir)

            self.assertEqual(reopened.get_project("proj_persist"), {"project": metadata, "scenes": scenes})

    def test_failed_scene_batch_rolls_back_project_and_scene_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            db = SQLiteDatabase(os.path.join(directory, "studio.sqlite3"), legacy_projects_dir=os.path.join(directory, "legacy"))
            original = {"id": "proj_atomic", "status": "draft"}
            db.save_project("proj_atomic", original, [{"id": 1, "title": "Antes"}])

            with self.assertRaises(sqlite3.IntegrityError):
                db.save_project("proj_atomic", {"id": "proj_atomic", "status": "changed"}, [
                    {"id": 2, "title": "Primera"}, {"id": 2, "title": "Duplicada"},
                ])

            self.assertEqual(db.get_project("proj_atomic"), {
                "project": original, "scenes": [{"id": 1, "title": "Antes"}],
            })

    def test_legacy_json_is_imported_without_deleting_original_files(self):
        with tempfile.TemporaryDirectory() as directory:
            legacy_dir = os.path.join(directory, "legacy")
            project_dir = os.path.join(legacy_dir, "proj_legacy")
            os.makedirs(project_dir)
            metadata_path = os.path.join(project_dir, "project.json")
            scenes_path = os.path.join(project_dir, "scenes.json")
            metadata = {"id": "proj_legacy", "topic": "antiguo"}
            scenes = [{"id": 1, "title": "Persistida"}]
            with open(metadata_path, "w", encoding="utf-8") as stream:
                json.dump(metadata, stream)
            with open(scenes_path, "w", encoding="utf-8") as stream:
                json.dump(scenes, stream)

            db = SQLiteDatabase(os.path.join(directory, "studio.sqlite3"), legacy_projects_dir=legacy_dir)

            self.assertEqual(db.get_project("proj_legacy"), {"project": metadata, "scenes": scenes})
            self.assertTrue(os.path.isfile(metadata_path))
            self.assertTrue(os.path.isfile(scenes_path))

    def test_legacy_render_job_is_migrated_and_interrupted_job_can_be_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            legacy_dir = os.path.join(directory, "legacy")
            jobs_dir = os.path.join(legacy_dir, "render_jobs")
            os.makedirs(jobs_dir)
            legacy_job_path = os.path.join(jobs_dir, "render_old.json")
            old_job = {
                "id": "render_old", "project_id": "proj_legacy", "status": "rendering",
                "progress": 25, "created_at": 1, "updated_at": 2,
            }
            with open(legacy_job_path, "w", encoding="utf-8") as stream:
                json.dump(old_job, stream)

            db = SQLiteDatabase(os.path.join(directory, "studio.sqlite3"), legacy_projects_dir=legacy_dir)

            migrated = db.get_job("render_old")
            self.assertEqual(migrated["status"], "interrupted")
            self.assertTrue(os.path.isfile(legacy_job_path))
            retry, created = db.create_or_get_job("proj_legacy")
            self.assertTrue(created)
            self.assertEqual(retry["id"], "render_old")
            self.assertEqual(retry["status"], "queued")


class ProjectWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.projects_dir = os.path.join(self.tempdir.name, "projects")
        os.makedirs(self.projects_dir)
        self.project_id = "proj_test"
        self.project_dir = os.path.join(self.projects_dir, self.project_id)
        os.makedirs(os.path.join(self.project_dir, "assets"))
        self.meta = {
            "id": self.project_id,
            "script_approved": True,
            "storyboard_approved": True,
            "status": "visual_generation",
        }
        self.scene = {
            "id": 1, "title": "Escena", "narrative_text": "Texto original",
            "callout": "ORIGINAL", "visual_description": "Ilustración original",
            "svg_prompt": "Prompt original", "svg_markup": "<svg />",
            "audio_path": "/old/audio.mp3", "audio_url": "/old/audio.mp3",
            "audio_duration": 4.0, "words": [{"word": "viejo"}], "versions": [],
        }
        self._save("project.json", self.meta)
        self._save("scenes.json", [self.scene])
        with open(os.path.join(self.project_dir, "assets", "scene_1.svg"), "w", encoding="utf-8") as stream:
            stream.write("<svg />")
        self.test_db = SQLiteDatabase(
            os.path.join(self.tempdir.name, "studio.sqlite3"),
            legacy_projects_dir=self.projects_dir,
        )
        self.patch_projects = patch("services.project_manager.PROJECTS_DIR", self.projects_dir)
        self.patch_projects.start()
        self.patch_db = patch.object(ProjectManager, "db", self.test_db)
        self.patch_db.start()

    def tearDown(self):
        self.patch_projects.stop()
        self.patch_db.stop()
        self.tempdir.cleanup()

    def _save(self, name, value):
        with open(os.path.join(self.project_dir, name), "w", encoding="utf-8") as stream:
            json.dump(value, stream)

    def test_visual_edit_invalidates_approval_and_stale_assets_and_keeps_snapshot(self):
        ProjectManager.update_scene(self.project_id, 1, {"svg_prompt": "Nuevo prompt"})
        updated = ProjectManager.get_project(self.project_id)
        meta, scene = updated["project"], updated["scenes"][0]

        self.assertFalse(meta["storyboard_approved"])
        self.assertTrue(meta["script_approved"])
        self.assertEqual(meta["status"], "storyboard_pending_approval")
        self.assertEqual(scene["svg_markup"], "")
        self.assertIsNone(scene["audio_path"])
        self.assertEqual(len(scene["versions"]), 1)
        self.assertEqual(scene["versions"][0]["svg_markup"], "<svg />")
        self.assertEqual(scene["versions"][0]["svg_prompt"], "Prompt original")
        self.assertFalse(os.path.exists(os.path.join(self.project_dir, "assets", "scene_1.svg")))

    def test_project_id_rejects_path_traversal(self):
        with self.assertRaises(ValueError):
            ProjectManager.get_project_dir("../outside")

    def test_script_approval_persists_separate_storyboard_generation_and_retry_state(self):
        meta = {
            "id": self.project_id, "status": "script_pending_approval", "script_approved": False,
            "storyboard_approved": False, "script": {"topic": "Tema", "duration_seconds": 60, "narration": "Texto"},
            "style": "documental", "target_duration_seconds": 60,
        }
        ProjectManager._save_project(self.project_id, meta, [])
        with patch.object(OmniRouteClient, "generate_storyboard_from_script", side_effect=RuntimeError("OmniRoute temporalmente no disponible")):
            with self.assertRaisesRegex(RuntimeError, "temporalmente"):
                ProjectManager.approve_script(self.project_id)

        persisted = ProjectManager.get_project(self.project_id)["project"]
        self.assertTrue(persisted["script_approved"])
        self.assertEqual(persisted["status"], "storyboard_generation")
        self.assertIn("storyboard_error", persisted)

    def test_approved_script_creates_editable_storyboard_before_storyboard_approval(self):
        meta = {
            "id": self.project_id, "status": "script_pending_approval", "script_approved": False,
            "storyboard_approved": False, "script": {"topic": "Tema", "duration_seconds": 60, "narration": "Texto"},
            "style": "documental", "target_duration_seconds": 60,
        }
        ProjectManager._save_project(self.project_id, meta, [])
        scenes = [{"id": i, "title": f"Escena {i}", "narrative_text": "Narración", "visual_description": "Ilustración", "svg_prompt": "SVG original"} for i in range(1, 6)]
        with patch.object(OmniRouteClient, "generate_storyboard_from_script", return_value={"visual_theme": "vectorial", "scenes": scenes}):
            drafted = ProjectManager.approve_script(self.project_id)

        self.assertTrue(drafted["project"]["script_approved"])
        self.assertFalse(drafted["project"]["storyboard_approved"])
        self.assertEqual(drafted["project"]["status"], "storyboard_pending_approval")
        self.assertEqual(len(drafted["scenes"]), 5)
        approved = ProjectManager.approve_storyboard(self.project_id)
        self.assertTrue(approved["project"]["storyboard_approved"])
        self.assertEqual(approved["project"]["status"], "visual_generation")

    def test_assembler_manifest_contains_only_assigned_local_source_clips(self):
        media = {
            "id": "media_test", "project_id": self.project_id, "filename": "source.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/media_test.mp4",
            "url": f"/projects/{self.project_id}/source_media/media_test.mp4", "created_at": 1,
            "duration_seconds": 25.0, "has_audio": True,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {
            "source_media_id": media["id"], "source_start_seconds": 3.5,
            "source_clip_duration_seconds": 6.0, "source_media_duration_seconds": 25.0, "source_audio_enabled": True,
        })
        project = ProjectManager.get_project(self.project_id)
        manifest_path = os.path.join(self.project_dir, "assembler.json")

        manifest = VideoAssemblerBridge.export_manifest(project["project"], project["scenes"], manifest_path)
        with open(manifest_path, encoding="utf-8") as stream:
            self.assertEqual(json.load(stream), manifest)
        self.assertEqual(manifest["clips"], [{
            "file": media["url"], "trimIn": 3.5, "trimOut": 9.5,
            "speed": 1.0, "keepAudio": True, "audioVolume": 1.0,
        }])
        self.assertIsNone(manifest["voice"])
        self.assertIsNone(manifest["music"])
        portable_manifest = ProjectManager.save_assembler_manifest(self.project_id, {
            **manifest,
            "clips": [{**manifest["clips"][0], "file": "source_media/media_test.mp4"}],
        })
        self.assertEqual(portable_manifest["clips"][0]["file"], "source_media/media_test.mp4")

    def test_source_video_start_must_be_inside_actual_duration_even_without_source_audio(self):
        media = {
            "id": "media_short", "project_id": self.project_id, "filename": "short.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/short.mp4",
            "url": f"/projects/{self.project_id}/source_media/short.mp4", "created_at": 1,
            "duration_seconds": 5.0, "has_audio": False,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {"source_media_id": media["id"]})
        with self.assertRaisesRegex(ValueError, "inicio del clip"):
            ProjectManager.update_scene(self.project_id, 1, {"source_start_seconds": 5.0})

    def test_assembler_manifest_refuses_projects_without_source_clips(self):
        with self.assertRaisesRegex(ValueError, "clip fuente"):
            VideoAssemblerBridge.export_manifest(self.meta, [self.scene], os.path.join(self.project_dir, "assembler.json"))

    def test_assembler_manifest_round_trips_in_sqlite_and_rejects_out_of_bounds_edits(self):
        media = {
            "id": "media_saved", "project_id": self.project_id, "filename": "source.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/source.mp4",
            "url": f"/projects/{self.project_id}/source_media/source.mp4", "created_at": 1,
            "duration_seconds": 20.0, "has_audio": True,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {
            "source_media_id": media["id"], "source_start_seconds": 3,
            "source_clip_duration_seconds": 5, "source_media_duration_seconds": 20.0, "source_audio_enabled": True,
        })
        base = ProjectManager.get_project(self.project_id)
        manifest = VideoAssemblerBridge.export_manifest(base["project"], base["scenes"])
        manifest["clips"][0]["file"] = "source_media/source.mp4"
        manifest["clips"][0]["trimIn"] = 3.5
        manifest["clips"][0]["trimOut"] = 7.5
        manifest["projectId"] = self.project_id
        saved = ProjectManager.save_assembler_manifest(self.project_id, manifest)
        reopened = self.test_db.get_project(self.project_id)
        self.assertEqual(reopened["project"]["assembler_manifest"], saved)
        self.assertFalse(reopened["project"]["storyboard_approved"])

        invalid = {**saved, "clips": [{**saved["clips"][0], "trimOut": 30}]}
        with self.assertRaisesRegex(ValueError, "dentro del tramo"):
            ProjectManager.save_assembler_manifest(self.project_id, invalid)
        self.assertEqual(self.test_db.get_project(self.project_id)["project"]["assembler_manifest"], saved)

    def test_assembler_manifest_rejects_unassigned_files_and_external_audio(self):
        media = {
            "id": "media_only", "project_id": self.project_id, "filename": "source.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/source.mp4",
            "url": f"/projects/{self.project_id}/source_media/source.mp4", "created_at": 1,
            "duration_seconds": 20.0,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {"source_media_id": media["id"]})
        project = ProjectManager.get_project(self.project_id)
        manifest = VideoAssemblerBridge.export_manifest(project["project"], project["scenes"])
        manifest["clips"][0]["file"] = "source_media/source.mp4"
        with self.assertRaisesRegex(ValueError, "clips fuente"):
            ProjectManager.save_assembler_manifest(self.project_id, {
                **manifest, "clips": [{**manifest["clips"][0], "file": "../../secrets.mp4"}],
            })
        with self.assertRaisesRegex(ValueError, "audio original"):
            ProjectManager.save_assembler_manifest(self.project_id, {**manifest, "voice": {"file": "voice.mp3"}})

    def test_new_project_is_created_in_sqlite(self):
        with patch("services.project_manager.OmniRouteClient.generate_script", return_value={
            "title": "Prueba", "narration": "Guion de prueba", "duration_seconds": 60,
        }):
            result = ProjectManager.create_project("Un tema de prueba")

        self.assertTrue(result["project"]["id"].startswith("proj_"))
        self.assertEqual(ProjectManager.get_project(result["project"]["id"])["project"]["topic"], "Un tema de prueba")
        self.assertIn(result["project"], ProjectManager.list_projects())

    def test_source_video_is_streamed_validated_and_persisted_locally(self):
        async def body():
            yield b"video-part-one"
            yield b"video-part-two"

        probe = SimpleNamespace(returncode=0, stdout='{"format":{"duration":"12.5"},"streams":[{"codec_type":"video"}]}')
        with patch("subprocess.run", return_value=probe):
            media = asyncio.run(ProjectManager.add_source_media_stream(self.project_id, "talk.mp4", body()))

        media_file = os.path.join(self.project_dir, media["path"])
        with open(media_file, "rb") as stream:
            self.assertEqual(stream.read(), b"video-part-onevideo-part-two")
        self.assertEqual(os.stat(media_file).st_mode & 0o777, 0o600)
        self.assertEqual(media["duration_seconds"], 12.5)
        self.assertFalse(media["has_audio"])
        self.assertEqual(ProjectManager.list_source_media(self.project_id), [media])

    def test_source_media_catalog_records_original_audio_capability(self):
        async def body():
            yield b"audio-video"

        probe = SimpleNamespace(returncode=0, stdout='{"format":{"duration":"5"},"streams":[{"codec_type":"video"},{"codec_type":"audio"}]}')
        with patch("subprocess.run", return_value=probe):
            media = asyncio.run(ProjectManager.add_source_media_stream(self.project_id, "talk.mp4", body()))
        self.assertTrue(media["has_audio"])
        self.assertEqual(media["duration_seconds"], 5.0)

    def test_invalid_source_video_is_removed_instead_of_registered(self):
        async def body():
            yield b"not-a-video"

        probe = SimpleNamespace(returncode=1, stdout="")
        with patch("subprocess.run", return_value=probe):
            with self.assertRaisesRegex(ValueError, "FFprobe"):
                asyncio.run(ProjectManager.add_source_media_stream(self.project_id, "broken.mp4", body()))
        source_dir = os.path.join(self.project_dir, "source_media")
        self.assertEqual(os.listdir(source_dir), [])
        self.assertEqual(ProjectManager.list_source_media(self.project_id), [])

    def test_project_source_media_quota_rejects_upload_and_cleans_partial_file(self):
        async def body():
            yield b"payload-over-quota"

        with patch.object(ProjectManager, "MAX_PROJECT_SOURCE_MEDIA_BYTES", 8):
            with self.assertRaisesRegex(ValueError, "20 GiB"):
                asyncio.run(ProjectManager.add_source_media_stream(self.project_id, "large.mp4", body()))
        source_dir = os.path.join(self.project_dir, "source_media")
        self.assertEqual(os.listdir(source_dir), [])
        self.assertEqual(ProjectManager.list_source_media(self.project_id), [])

    def test_scene_source_assignment_is_project_scoped_and_invalidates_approval(self):
        media = {
            "id": "media_test", "project_id": self.project_id, "filename": "source.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/media_test.mp4",
            "url": f"/projects/{self.project_id}/source_media/media_test.mp4", "created_at": 1,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {"source_media_id": media["id"], "source_start_seconds": 3.5})
        updated = ProjectManager.get_project(self.project_id)
        scene = updated["scenes"][0]
        self.assertEqual(scene["source_video_src"], media["url"])
        self.assertEqual(scene["source_start_seconds"], 3.5)
        self.assertFalse(updated["project"]["storyboard_approved"])
        with self.assertRaisesRegex(ValueError, "no pertenece"):
            ProjectManager.update_scene(self.project_id, 1, {"source_media_id": "media_other"})

    def test_original_source_audio_uses_scene_segment_without_synthesizing_tts(self):
        media = {
            "id": "media_audio", "project_id": self.project_id, "filename": "source.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/media_audio.mp4",
            "url": f"/projects/{self.project_id}/source_media/media_audio.mp4", "created_at": 1,
            "duration_seconds": 25.0, "has_audio": True,
        }
        self.test_db.save_source_media(media)
        ProjectManager.update_scene(self.project_id, 1, {"source_media_id": media["id"]})
        ProjectManager.update_scene(self.project_id, 1, {"source_audio_enabled": True})

        with patch.object(VoiceHub, "synthesize", side_effect=AssertionError("TTS must be skipped")) as synthesize:
            result = asyncio.run(ProjectManager.synthesize_scene_audio(self.project_id, 1))

        synthesize.assert_not_called()
        self.assertEqual(result["scene"]["status"], "source_audio_ready")
        self.assertEqual(result["scene"]["audio_duration"], 10.0)
        self.assertIsNone(result["scene"]["audio_path"])

    def test_original_audio_segment_must_fit_inside_source_media(self):
        media = {
            "id": "media_short", "project_id": self.project_id, "filename": "short.mp4",
            "media_type": "video/mp4", "size_bytes": 10, "path": "source_media/media_short.mp4",
            "url": f"/projects/{self.project_id}/source_media/media_short.mp4", "created_at": 1,
            "duration_seconds": 5.0, "has_audio": True,
        }
        self.test_db.save_source_media(media)
        with self.assertRaisesRegex(ValueError, "dentro de la duración"):
            ProjectManager.update_scene(self.project_id, 1, {
                "source_media_id": media["id"], "source_audio_enabled": True,
                "source_start_seconds": 2.0, "source_clip_duration_seconds": 4.0,
            })


class VoiceProviderTests(unittest.TestCase):
    def test_unconfigured_vibevoice_does_not_silently_use_edge_tts(self):
        with self.assertRaises(NotImplementedError):
            asyncio.run(VoiceHub._synthesize_vibevoice("Hola", "/tmp/unused.mp3", "voice"))




class LegacyRenderPathTests(unittest.TestCase):
    def test_long_render_reuses_verified_frame_checkpoints_after_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output_dir = root / "output"
            checkpoint_dir = root / "checkpoints"
            remotion_dir = root / "remotion"
            public_dir = remotion_dir / "public"
            (remotion_dir / "src").mkdir(parents=True)
            public_dir.mkdir()
            output_dir.mkdir()
            ranges = []
            fail_second_segment_once = {"pending": True}

            class FakeProcess:
                def __init__(self, returncode=0):
                    self.stdout = iter(["Rendered 30/30\n"])
                    self.returncode = returncode
                    self.pid = 12345

                def poll(self):
                    return self.returncode

                def wait(self, timeout=None):
                    return self.returncode

            def fake_popen(command, **kwargs):
                if command[0] == "npx":
                    frame_range = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--frames="))
                    ranges.append(frame_range)
                    if frame_range == "3600-3659" and fail_second_segment_once["pending"]:
                        fail_second_segment_once["pending"] = False
                        return FakeProcess(returncode=1)
                    Path(command[5]).write_bytes(b"rendered-segment")
                elif command[0] == "ffmpeg":
                    Path(command[-1]).write_bytes(b"assembled-render")
                return FakeProcess()

            def fake_probe(command, **kwargs):
                candidate = command[-1]
                if "segment-0000" in candidate:
                    duration = "120.0"
                elif "segment-0001" in candidate:
                    duration = "2.0"
                else:
                    duration = "122.0"
                return SimpleNamespace(returncode=0, stdout=json.dumps({
                    "format": {"duration": duration},
                    "streams": [{"codec_type": "video"}, {"codec_type": "audio"}],
                }), stderr="")

            scene = {"id": 1, "title": "Largo", "narrative_text": "Prueba", "audio_duration": 122,
                     "svg_markup": "<svg viewBox='0 0 1 1'></svg>", "words": []}
            with patch.object(render_service, "OUTPUT_DIR", str(output_dir)), \
                    patch.object(render_service, "CHECKPOINTS_DIR", str(checkpoint_dir)), \
                    patch.object(render_service, "REMOTION_DIR", str(remotion_dir)), \
                    patch.object(render_service, "PUBLIC_DIR", str(public_dir)), \
                    patch.object(render_service, "PROJECTS_DIR", str(root / "projects")), \
                    patch.object(render_service, "RENDER_CHECKPOINT_CHUNK_SECONDS", 120), \
                    patch.object(render_service.subprocess, "run", side_effect=fake_probe), \
                    patch.object(render_service.subprocess, "Popen", side_effect=fake_popen):
                with self.assertRaisesRegex(RuntimeError, "Error en subproceso"):
                    render_service.render_project({}, [scene], "resumable.mp4", checkpoint_id="render_checkpoint")

                self.assertTrue((checkpoint_dir / "render_checkpoint" / "segment-0000.mp4").is_file())
                result = render_service.render_project({}, [scene], "resumable.mp4", checkpoint_id="render_checkpoint")

            self.assertEqual(ranges, ["0-3599", "3600-3659", "3600-3659"])
            self.assertTrue(os.path.isfile(result["video_path"]))
            self.assertFalse((checkpoint_dir / "render_checkpoint").exists())

    def test_stale_checkpoint_fingerprint_clears_old_segments_and_restarts_clean(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output_dir = root / "output"
            checkpoint_dir = root / "checkpoints"
            remotion_dir = root / "remotion"
            public_dir = remotion_dir / "public"
            (remotion_dir / "src").mkdir(parents=True)
            public_dir.mkdir()
            output_dir.mkdir()
            specific_chk = checkpoint_dir / "render_stale"
            specific_chk.mkdir(parents=True)
            # Create a stale segment and state file with a different fingerprint
            stale_segment = specific_chk / "segment-0000.mp4"
            stale_segment.write_bytes(b"stale-segment")
            state_file = specific_chk / "state.json"
            state_file.write_text(json.dumps({
                "fingerprint": "old_obsolete_fingerprint_12345",
                "total_frames": 3660,
                "fps": 30,
                "chunk_frames": 3600
            }), encoding="utf-8")

            class FakeProcess:
                stdout = iter(["Rendered 30/30\n"])
                returncode = 0
                pid = 54321
                def poll(self): return 0
                def wait(self, timeout=None): return 0

            ranges = []
            def fake_popen(command, **kwargs):
                if command[0] == "npx":
                    frame_range = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--frames="))
                    ranges.append(frame_range)
                    Path(command[5]).write_bytes(b"fresh-segment")
                elif command[0] == "ffmpeg":
                    Path(command[-1]).write_bytes(b"assembled-render")
                return FakeProcess()

            def fake_probe(command, **kwargs):
                candidate = command[-1]
                if "segment-0000" in candidate:
                    duration = "120.0"
                elif "segment-0001" in candidate:
                    duration = "2.0"
                else:
                    duration = "122.0"
                return SimpleNamespace(returncode=0, stdout=json.dumps({
                    "format": {"duration": duration},
                    "streams": [{"codec_type": "video"}, {"codec_type": "audio"}],
                }), stderr="")

            scene = {"id": 1, "title": "Largo", "narrative_text": "Prueba", "audio_duration": 122,
                     "svg_markup": "<svg viewBox='0 0 1 1'></svg>", "words": []}
            with patch.object(render_service, "OUTPUT_DIR", str(output_dir)), \
                    patch.object(render_service, "CHECKPOINTS_DIR", str(checkpoint_dir)), \
                    patch.object(render_service, "REMOTION_DIR", str(remotion_dir)), \
                    patch.object(render_service, "PUBLIC_DIR", str(public_dir)), \
                    patch.object(render_service, "PROJECTS_DIR", str(root / "projects")), \
                    patch.object(render_service, "RENDER_CHECKPOINT_CHUNK_SECONDS", 120), \
                    patch.object(render_service.subprocess, "run", side_effect=fake_probe), \
                    patch.object(render_service.subprocess, "Popen", side_effect=fake_popen):
                result = render_service.render_project({}, [scene], "fresh.mp4", checkpoint_id="render_stale")

            # Verify both segments were re-rendered from scratch because the fingerprint was stale
            self.assertEqual(ranges, ["0-3599", "3600-3659"])
            self.assertTrue(os.path.isfile(result["video_path"]))

    def test_checkpoint_directory_permissions_and_cancellation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output_dir = root / "output"
            checkpoint_dir = root / "checkpoints"
            remotion_dir = root / "remotion"
            public_dir = remotion_dir / "public"
            (remotion_dir / "src").mkdir(parents=True)
            public_dir.mkdir()
            output_dir.mkdir()

            class FakeProcess:
                stdout = iter(["Rendered 10/30\n"])
                returncode = 0
                pid = 99999
                def poll(self): return 0
                def wait(self, timeout=None): return 0

            scene = {"id": 1, "title": "Largo", "narrative_text": "Cancel Me", "audio_duration": 122,
                     "svg_markup": "<svg viewBox='0 0 1 1'></svg>", "words": []}
            with patch.object(render_service, "OUTPUT_DIR", str(output_dir)), \
                    patch.object(render_service, "CHECKPOINTS_DIR", str(checkpoint_dir)), \
                    patch.object(render_service, "REMOTION_DIR", str(remotion_dir)), \
                    patch.object(render_service, "PUBLIC_DIR", str(public_dir)), \
                    patch.object(render_service, "PROJECTS_DIR", str(root / "projects")), \
                    patch.object(render_service, "RENDER_CHECKPOINT_CHUNK_SECONDS", 120), \
                    patch.object(render_service.subprocess, "Popen", return_value=FakeProcess()):
                with self.assertRaisesRegex(RuntimeError, "Render cancelado por el usuario"):
                    render_service.render_project(
                        {}, [scene], "cancel.mp4",
                        checkpoint_id="render_cancel",
                        cancel_check=lambda: True,
                    )
            # Checkpoint dir was created with mode 0o700
            specific_chk = checkpoint_dir / "render_cancel"
            self.assertTrue(specific_chk.exists())
            self.assertEqual(oct(specific_chk.stat().st_mode & 0o777), "0o700")


    def test_render_output_validation_rejects_truncated_or_video_free_files(self):
        with tempfile.TemporaryDirectory() as directory:
            output = os.path.join(directory, "candidate.partial.mp4")
            with open(output, "wb") as stream:
                stream.write(b"candidate")

            with patch.object(render_service.subprocess, "run", return_value=SimpleNamespace(
                returncode=0, stdout=json.dumps({"format": {"duration": "1.2"}, "streams": [{"codec_type": "video"}]}), stderr=""
            )):
                with self.assertRaisesRegex(RuntimeError, "no coincide"):
                    render_service._validate_rendered_video(output, 20.0, 30)

            with patch.object(render_service.subprocess, "run", return_value=SimpleNamespace(
                returncode=0, stdout=json.dumps({"format": {"duration": "20.0"}, "streams": [{"codec_type": "audio"}]}), stderr=""
            )):
                with self.assertRaisesRegex(RuntimeError, "pista de video"):
                    render_service._validate_rendered_video(output, 20.0, 30)

    def test_render_output_is_atomically_published_only_after_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            partial = os.path.join(directory, ".final.mp4.partial.mp4")
            final = os.path.join(directory, "final.mp4")
            with open(partial, "wb") as stream:
                stream.write(b"valid-candidate")
            metadata = json.dumps({"format": {"duration": "2.0"}, "streams": [{"codec_type": "video"}]})

            with patch.object(render_service.subprocess, "run", return_value=SimpleNamespace(
                returncode=0, stdout=metadata, stderr=""
            )):
                result = render_service._publish_validated_output(partial, final, 2.0, 30)

            self.assertFalse(os.path.exists(partial))
            self.assertTrue(os.path.isfile(final))
            self.assertEqual(result["duration_seconds"], 2.0)

    def test_render_output_publication_never_overwrites_a_racing_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            partial = os.path.join(directory, ".final.mp4.partial.mp4")
            final = os.path.join(directory, "final.mp4")
            with open(partial, "wb") as stream:
                stream.write(b"candidate")
            with open(final, "wb") as stream:
                stream.write(b"existing-user-output")
            metadata = json.dumps({"format": {"duration": "2.0"}, "streams": [{"codec_type": "video"}]})

            with patch.object(render_service.subprocess, "run", return_value=SimpleNamespace(
                returncode=0, stdout=metadata, stderr=""
            )):
                with self.assertRaises(FileExistsError):
                    render_service._publish_validated_output(partial, final, 2.0, 30)

            with open(final, "rb") as stream:
                self.assertEqual(stream.read(), b"existing-user-output")

    def test_render_project_stops_process_when_progress_callback_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            output_dir = os.path.join(directory, "output")
            os.makedirs(output_dir)
            process = SimpleNamespace(pid=12345, stdout=iter([]), returncode=None)
            process.poll = lambda: process.returncode
            process.wait = lambda timeout=None: setattr(process, "returncode", -15) or -15

            with patch.object(render_service, "OUTPUT_DIR", output_dir), patch.object(
                render_service.subprocess, "Popen", return_value=process
            ), patch.object(render_service.os, "killpg") as killpg:
                with self.assertRaisesRegex(RuntimeError, "cancel check roto"):
                    render_service.render_project(
                        {}, [{"id": 1, "title": "A", "narrative_text": "", "audio_duration": 2}],
                        "callback_failure.mp4", cancel_check=lambda: (_ for _ in ()).throw(
                            RuntimeError("cancel check roto")
                        ),
                    )

            killpg.assert_called_once_with(process.pid, render_service.signal.SIGTERM)
            self.assertEqual(process.returncode, -15)
            self.assertEqual(os.listdir(output_dir), [".props"])
            self.assertEqual(os.listdir(os.path.join(output_dir, ".props")), [])

    def test_render_output_filename_and_concurrency_configuration_are_validated(self):
        with self.assertRaisesRegex(ValueError, "Nombre de salida"):
            render_service.render_video({}, {}, "../../outside.mp4")
        with self.assertRaisesRegex(ValueError, "FPS debe ser"):
            render_service.render_video({}, {}, "valid.mp4", fps=0)
        self.assertEqual(render_service._validate_fps(24), 24)
        with patch.dict(os.environ, {"VIDEO_STUDIO_RENDER_CONCURRENCY": "101%"}):
            with self.assertRaisesRegex(ValueError, "no puede superar"):
                render_service._render_concurrency()
        with patch.dict(os.environ, {"VIDEO_STUDIO_RENDER_CONCURRENCY": "25%"}):
            self.assertEqual(render_service._render_concurrency(), "25%")

    def test_existing_output_file_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            existing_path = os.path.join(directory, "keep.mp4")
            with open(existing_path, "wb") as stream:
                stream.write(b"user-video")
            with patch.object(render_service, "OUTPUT_DIR", directory):
                with self.assertRaises(FileExistsError):
                    render_service.render_video({}, {}, "keep.mp4")
            with open(existing_path, "rb") as stream:
                self.assertEqual(stream.read(), b"user-video")

    def test_legacy_render_uses_unique_props_file_and_cleans_it(self):
        with tempfile.TemporaryDirectory() as directory:
            output_dir = os.path.join(directory, "output")
            os.makedirs(output_dir)
            seen = {}

            class FakeProcess:
                stdout = iter(["render complete\n"])
                returncode = 0

                def poll(self):
                    return 0

                def wait(self, timeout=None):
                    return 0

            def fake_popen(command, **kwargs):
                props_path = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--props="))
                seen["props_path"] = props_path
                with open(props_path, encoding="utf-8") as stream:
                    seen["props"] = json.load(stream)
                with open(command[5], "wb") as stream:
                    stream.write(b"mp4")
                return FakeProcess()

            with patch.object(render_service, "OUTPUT_DIR", output_dir), patch.object(
                render_service.subprocess, "Popen", side_effect=fake_popen
            ), patch.object(
                render_service.subprocess, "run", return_value=SimpleNamespace(
                    returncode=0, stdout=json.dumps({"format": {"duration": "3.0"}, "streams": [{"codec_type": "video"}]}), stderr=""
                )
            ):
                result = render_service.render_video(
                    {"scenes": [{"id": 1, "text": "Narración"}]},
                    {"duration": 3, "words": [], "audio_path": None},
                    "legacy_test.mp4",
                )

            self.assertTrue(seen["props_path"].startswith(os.path.join(output_dir, ".props")))
            self.assertFalse(os.path.exists(seen["props_path"]))
            self.assertEqual(seen["props"]["scenes"][0]["text"], "Narración")
            self.assertTrue(os.path.isfile(result["video_path"]))

    def test_source_clip_is_staged_for_remotion_and_temp_assets_are_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            output_dir = os.path.join(directory, "output")
            projects_dir = os.path.join(directory, "projects")
            source_dir = os.path.join(projects_dir, "proj_test", "source_media")
            assets_dir = os.path.join(projects_dir, "proj_test", "assets")
            motion_dir = os.path.join(projects_dir, "proj_test", "motion")
            os.makedirs(source_dir)
            os.makedirs(assets_dir)
            os.makedirs(motion_dir)
            os.makedirs(output_dir)
            source_path = os.path.join(source_dir, "source.mp4")
            with open(source_path, "wb") as stream:
                stream.write(b"local-video")
            audio_path = os.path.join(assets_dir, "voice.mp3")
            with open(audio_path, "wb") as stream:
                stream.write(b"local-audio")
            manim_path = os.path.join(motion_dir, "scene_1.webm")
            with open(manim_path, "wb") as stream:
                stream.write(b"local-manim-video")
            seen = {}

            class FakeProcess:
                stdout = iter(["render complete\n"])
                returncode = 0

                def poll(self):
                    return 0

                def wait(self, timeout=None):
                    return 0

            def fake_popen(command, **kwargs):
                props_path = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--props="))
                public_dir = next(arg.split("=", 1)[1] for arg in command if arg.startswith("--public-dir="))
                with open(props_path, encoding="utf-8") as stream:
                    props = json.load(stream)
                source_ref = props["scenes"][0]["source_video_src"]
                audio_ref = props["scenes"][0]["audio_src"]
                manim_ref = props["scenes"][0]["manim_clip"]
                seen.update(props=props, staged_source=os.path.join(public_dir, source_ref),
                            staged_audio=os.path.join(public_dir, audio_ref),
                            staged_manim=os.path.join(public_dir, manim_ref), public_dir=public_dir)
                self.assertIn("--fps=30", command)
                self.assertTrue(os.path.isfile(seen["staged_source"]))
                self.assertTrue(os.path.isfile(seen["staged_audio"]))
                self.assertTrue(os.path.isfile(seen["staged_manim"]))
                with open(command[5], "wb") as stream:
                    stream.write(b"rendered-mp4")
                return FakeProcess()

            with patch.object(render_service, "OUTPUT_DIR", output_dir), patch.object(
                render_service, "PROJECTS_DIR", projects_dir
            ), patch.object(
                render_service.subprocess, "run", return_value=SimpleNamespace(
                    returncode=0, stdout=json.dumps({"format": {"duration": "2.0"}, "streams": [{"codec_type": "video"}]}), stderr=""
                )
            ), patch.object(render_service.subprocess, "Popen", side_effect=fake_popen):
                result = render_service.render_project(
                    {"output_format": "horizontal"},
                    [{"id": 1, "title": "Clip", "narrative_text": "", "audio_duration": 2,
                      "source_video_src": "/projects/proj_test/source_media/source.mp4", "source_start_seconds": 1.25,
                      "source_media_duration_seconds": 24.0, "source_clip_duration_seconds": 3.5,
                      "audio_path": audio_path, "source_audio_enabled": True,
                      "manim_clip": "/projects/proj_test/motion/scene_1.webm"}],
                    "source_test.mp4",
                )

            self.assertEqual(seen["props"]["width"], 1920)
            self.assertEqual(seen["props"]["durationInFrames"], 60)
            self.assertEqual(seen["props"]["scenes"][0]["source_start_seconds"], 1.25)
            self.assertEqual(seen["props"]["scenes"][0]["source_media_duration_seconds"], 24.0)
            self.assertEqual(seen["props"]["scenes"][0]["source_clip_duration_seconds"], 3.5)
            self.assertEqual(seen["props"]["scenes"][0]["audio_data_uri"], "")
            self.assertTrue(seen["props"]["scenes"][0]["source_audio_enabled"])
            self.assertFalse(os.path.exists(os.path.dirname(seen["staged_source"])))
            self.assertTrue(os.path.isfile(result["video_path"]))


if __name__ == "__main__":
    unittest.main()
