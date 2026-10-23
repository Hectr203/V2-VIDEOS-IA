import os
import asyncio
import time
import shutil
import uuid
import re
import json
import xml.etree.ElementTree as ET
from typing import Dict, Any, List, Optional
import math
from services.omniroute_client import OmniRouteClient
from services.voice_hub import VoiceHub
from services.database import database
from services.assembler_bridge import VideoAssemblerBridge

PROJECTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../projects"))
os.makedirs(PROJECTS_DIR, exist_ok=True)

class ProjectManager:
    """
    Gestor de persistencia, proyectos, escenas, sincronización y versionado recuperable.
    """
    db = database
    MAX_SOURCE_MEDIA_BYTES = 2 * 1024 * 1024 * 1024
    MAX_PROJECT_SOURCE_MEDIA_BYTES = 20 * 1024 * 1024 * 1024
    SOURCE_MEDIA_TYPES = {
        ".mp4": "video/mp4", ".mov": "video/quicktime", ".m4v": "video/x-m4v",
        ".webm": "video/webm", ".mkv": "video/x-matroska",
    }

    @classmethod
    def get_project_dir(cls, project_id: str) -> str:
        # Project IDs are path components, never arbitrary filesystem paths.
        if not re.fullmatch(r"proj_[A-Za-z0-9_-]+", project_id):
            raise ValueError("ID de proyecto inválido")
        return os.path.join(PROJECTS_DIR, project_id)

    @classmethod
    async def add_source_media_stream(cls, project_id: str, filename: str, source_stream) -> Dict[str, Any]:
        project = cls.get_project(project_id)
        if not project:
            raise FileNotFoundError("Proyecto no encontrado")
        safe_name = os.path.basename(filename.replace("\\", "/"))
        extension = os.path.splitext(safe_name)[1].lower()
        media_type = cls.SOURCE_MEDIA_TYPES.get(extension)
        if not media_type:
            raise ValueError("Formato no admitido; usa MP4, MOV, M4V, WebM o MKV")
        used_bytes = sum(item.get("size_bytes", 0) for item in cls.db.list_source_media(project_id))
        if used_bytes >= cls.MAX_PROJECT_SOURCE_MEDIA_BYTES:
            raise ValueError("El proyecto alcanzó el límite local de medios fuente de 20 GiB")
        media_id = f"media_{uuid.uuid4().hex}"
        media_dir = os.path.join(cls.get_project_dir(project_id), "source_media")
        os.makedirs(media_dir, exist_ok=True)
        target = os.path.join(media_dir, f"{media_id}{extension}")
        size = 0
        try:
            output = os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb")
            try:
                async for chunk in source_stream:
                    size += len(chunk)
                    if size > cls.MAX_SOURCE_MEDIA_BYTES:
                        raise ValueError("El video supera el límite local de 2 GiB")
                    if used_bytes + size > cls.MAX_PROJECT_SOURCE_MEDIA_BYTES:
                        raise ValueError("El proyecto alcanzó el límite local de medios fuente de 20 GiB")
                    await asyncio.to_thread(output.write, chunk)
            finally:
                await asyncio.to_thread(output.close)
            if size == 0:
                raise ValueError("El archivo de video está vacío")
            media = {
                "id": media_id, "project_id": project_id, "filename": safe_name,
                "media_type": media_type, "size_bytes": size,
                "path": os.path.relpath(target, cls.get_project_dir(project_id)).replace(os.sep, "/"),
                "url": f"/projects/{project_id}/{os.path.relpath(target, cls.get_project_dir(project_id)).replace(os.sep, '/')}",
                "duration_seconds": None, "has_audio": False, "created_at": time.time(),
            }
            try:
                import subprocess
                probe = await asyncio.to_thread(
                    subprocess.run,
                    ["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "json", target],
                    capture_output=True, text=True, timeout=30, check=False,
                )
                if probe.returncode != 0:
                    raise ValueError("FFprobe no pudo leer el archivo; comprueba que sea un video válido")
                probe_data = json.loads(probe.stdout)
                streams = probe_data.get("streams", [])
                if not any(stream.get("codec_type") == "video" for stream in streams):
                    raise ValueError("El archivo no contiene una pista de video válida")
                media["has_audio"] = any(stream.get("codec_type") == "audio" for stream in streams)
                duration = float(probe_data.get("format", {}).get("duration", 0) or 0)
                if duration > 0:
                    media["duration_seconds"] = duration
            except OSError as error:
                raise ValueError("FFprobe es necesario para validar los videos fuente") from error
            except subprocess.TimeoutExpired as error:
                raise ValueError("La validación del video excedió 30 segundos") from error
            except json.JSONDecodeError as error:
                raise ValueError("FFprobe devolvió metadatos inválidos") from error
            cls.db.save_source_media(media)
            return media
        except Exception:
            try:
                os.remove(target)
            except OSError:
                pass
            raise

    @classmethod
    def list_source_media(cls, project_id: str) -> List[Dict[str, Any]]:
        if not cls.get_project(project_id):
            raise FileNotFoundError("Proyecto no encontrado")
        return cls.db.list_source_media(project_id)

    @classmethod
    def create_project(
        cls,
        topic: str,
        target_duration: int = 60,
        style: str = "curiosity",
        voice_provider: str = "edge-tts",
        voice_id: str = "es-ES-AlvaroNeural",
        output_format: str = "vertical",
    ) -> Dict[str, Any]:
        """Crea un proyecto persistido y genera su storyboard adaptativo."""
        script = OmniRouteClient.generate_script(topic, target_duration, style)
        project_id = f"proj_{int(time.time())}_{uuid.uuid4().hex[:6]}"
        pdir = cls.get_project_dir(project_id)
        assets_dir = os.path.join(pdir, "assets")
        os.makedirs(assets_dir, exist_ok=True)
        scenes: List[Dict[str, Any]] = []

        project_meta = {
            "id": project_id,
            "topic": topic,
            "target_duration_seconds": target_duration,
            "style": style,
            "voice_provider": voice_provider,
            "voice_id": voice_id,
            "output_format": output_format,
            "visual_theme": "",
            "script": script,
            "script_approved": False,
            "storyboard_approved": False,
            "status": "script_pending_approval",
            "total_real_duration": 0.0,
            "scene_count": len(scenes),
            "created_at": time.time(),
            "updated_at": time.time(),
            "final_video_url": None
        }

        cls._save_project(project_id, project_meta, scenes)

        return {"project": project_meta, "scenes": scenes}

    @classmethod
    def approve_script(cls, project_id: str) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        meta = proj["project"]
        if meta.get("status") != "script_pending_approval":
            raise ValueError("El guion no está pendiente de aprobación")
        meta.update({"script_approved": True, "status": "storyboard_generation", "updated_at": time.time()})
        cls._save_project(project_id, meta, proj["scenes"])
        return cls.generate_storyboard(project_id)

    @classmethod
    def generate_storyboard(cls, project_id: str) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        meta = proj["project"]
        if not meta.get("script_approved") or meta.get("storyboard_approved"):
            raise ValueError("Aprueba el guion antes de generar el storyboard")
        if meta.get("status") != "storyboard_generation":
            raise ValueError("No hay un storyboard pendiente de generación")
        try:
            storyboard = OmniRouteClient.generate_storyboard_from_script(meta["script"], meta["style"])
        except Exception as error:
            meta.update({"status": "storyboard_generation", "storyboard_error": str(error)[:1000], "updated_at": time.time()})
            cls._save_project(project_id, meta, proj["scenes"])
            raise
        expected_scenes = OmniRouteClient.calculate_scene_count(int(meta.get("target_duration_seconds", 60)))
        if not isinstance(storyboard, dict) or not isinstance(storyboard.get("scenes"), list) or len(storyboard["scenes"]) != expected_scenes:
            meta.update({"status": "storyboard_generation", "storyboard_error": f"Storyboard incompleto: se esperaban {expected_scenes} escenas", "updated_at": time.time()})
            cls._save_project(project_id, meta, proj["scenes"])
            raise ValueError(f"Storyboard inválido: se esperaban {expected_scenes} escenas")
        scenes = [{
            "id": index + 1, "act": s.get("act", 1), "title": s["title"],
            "narrative_text": s["narrative_text"], "visual_description": s.get("visual_description", ""),
            "svg_prompt": s.get("svg_prompt", s.get("visual_description", "")), "svg_markup": "",
            "callout": s.get("callout", ""), "visual_type": "svg", "visual_asset_url": None,
            "sticker": "", "sfx": s.get("sfx", "pop"), "bg_color": s.get("bg_color", "#FEF3C7"),
            "source_media_id": None, "source_video_src": None, "source_start_seconds": 0.0,
            "source_media_duration_seconds": None, "source_audio_enabled": False,
            "source_clip_duration_seconds": None,
            "audio_path": None, "audio_url": None, "audio_duration": 0.0, "words": [],
            "status": "pending_visual", "versions": []
        } for index, s in enumerate(storyboard["scenes"])]
        if any(not scene["title"].strip() or not scene["narrative_text"].strip() or not scene["visual_description"].strip() or not scene["svg_prompt"].strip() for scene in scenes):
            meta.update({"status": "storyboard_generation", "storyboard_error": "OmniRoute devolvió escenas incompletas", "updated_at": time.time()})
            cls._save_project(project_id, meta, proj["scenes"])
            raise ValueError("OmniRoute devolvió escenas incompletas; vuelve a generar el storyboard")
        meta.update({"visual_theme": storyboard.get("visual_theme", ""), "storyboard_error": None,
                     "scene_count": len(scenes), "status": "storyboard_pending_approval", "updated_at": time.time()})
        cls._save_project(project_id, meta, scenes)
        return {"project": meta, "scenes": scenes}

    @classmethod
    def update_script(cls, project_id: str, narration: str) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        if proj["project"].get("status") != "script_pending_approval":
            raise ValueError("El guion solo puede editarse antes de su aprobación")
        if not narration.strip() or len(narration) > 500_000:
            raise ValueError("El guion no puede estar vacío ni superar 500 000 caracteres")
        proj["project"]["script"]["narration"] = narration.strip()
        proj["project"]["updated_at"] = time.time()
        cls._save_project(project_id, proj["project"], proj["scenes"])
        return proj

    @classmethod
    def approve_storyboard(cls, project_id: str) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        meta, scenes = proj["project"], proj["scenes"]
        if not meta.get("script_approved") or meta.get("status") != "storyboard_pending_approval":
            raise ValueError("El storyboard todavía no puede aprobarse")
        if not scenes or any(not scene.get("narrative_text", "").strip() or not scene.get("visual_description", "").strip() or not scene.get("svg_prompt", "").strip() for scene in scenes):
            raise ValueError("Completa la narración y la descripción visual de todas las escenas")
        meta.update({"storyboard_approved": True, "status": "visual_generation", "updated_at": time.time()})
        cls._save_project(project_id, meta, scenes)
        return {"project": meta, "scenes": scenes}

    @classmethod
    def generate_scene_svg(cls, project_id: str, scene_id: int) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        meta, scenes = proj["project"], proj["scenes"]
        if not meta.get("storyboard_approved"):
            raise ValueError("Aprueba el storyboard antes de generar ilustraciones")
        if meta.get("status") != "visual_generation":
            raise ValueError("El storyboard debe estar aprobado y sin cambios antes de generar ilustraciones")
        scene = next((item for item in scenes if item["id"] == scene_id), None)
        if not scene:
            raise ValueError(f"Escena {scene_id} no encontrada")
        markup = OmniRouteClient.generate_scene_svg(scene.get("svg_prompt") or scene["visual_description"], meta.get("visual_theme", ""))
        markup = cls._validate_svg(markup)
        scene["svg_markup"] = markup
        scene["status"] = "visual_ready"
        scene["visual_asset_url"] = f"/projects/{project_id}/assets/scene_{scene_id}.svg"
        assets_dir = os.path.join(cls.get_project_dir(project_id), "assets")
        os.makedirs(assets_dir, exist_ok=True)
        with open(os.path.join(assets_dir, f"scene_{scene_id}.svg"), "w", encoding="utf-8") as f:
            f.write(markup)
        cls._save_project(project_id, meta, scenes)
        return {"project": meta, "scene": scene}

    @staticmethod
    def _validate_svg(markup: str) -> str:
        allowed_tags = {"svg", "g", "path", "circle", "ellipse", "rect", "line", "polyline", "polygon", "defs", "linearGradient", "radialGradient", "stop", "clipPath"}
        allowed_attrs = {"xmlns", "viewBox", "width", "height", "version", "fill", "fill-rule", "fill-opacity", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-dasharray", "stroke-dashoffset", "stroke-opacity", "opacity", "transform", "d", "cx", "cy", "r", "rx", "ry", "x", "y", "x1", "y1", "x2", "y2", "points", "id", "offset", "stop-color", "stop-opacity", "clip-path", "preserveAspectRatio", "shape-rendering"}
        if len(markup) > 150_000 or re.search(r"<!DOCTYPE|<!ENTITY", markup, re.I):
            raise ValueError("SVG rechazado: tamaño o declaración XML no permitida")
        ET.register_namespace("", "http://www.w3.org/2000/svg")
        root = ET.fromstring(markup)
        if root.tag.split("}")[-1] != "svg":
            raise ValueError("La respuesta no contiene un SVG válido")
        if not root.attrib.get("viewBox"):
            raise ValueError("SVG rechazado: falta viewBox")
        root.set("width", "100%")
        root.set("height", "100%")
        for element in root.iter():
            tag = element.tag.split("}")[-1]
            if tag not in allowed_tags or any(key.split("}")[-1] not in allowed_attrs for key in element.attrib):
                raise ValueError("SVG rechazado: contiene etiquetas o atributos no permitidos")
            for value in element.attrib.values():
                if ("url(" in value.lower() and not re.fullmatch(r"url\(#[A-Za-z0-9_.-]+\)", value)) or "javascript:" in value.lower() or "http:" in value.lower() or "https:" in value.lower():
                    raise ValueError("SVG rechazado: no se permiten referencias externas")
        return ET.tostring(root, encoding="unicode")

    @classmethod
    def _save_project(cls, project_id: str, meta: Dict[str, Any], scenes: List[Dict[str, Any]]) -> None:
        cls.db.save_project(project_id, meta, scenes)

    @classmethod
    def list_projects(cls) -> List[Dict[str, Any]]:
        return cls.db.list_projects()

    @classmethod
    def get_project(cls, project_id: str) -> Optional[Dict[str, Any]]:
        return cls.db.get_project(project_id)

    @classmethod
    def save_assembler_manifest(cls, project_id: str, manifest: Dict[str, Any]) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError("Proyecto no encontrado")
        if manifest.get("projectId") not in (None, project_id):
            raise ValueError("El montaje pertenece a otro proyecto")
        expected = VideoAssemblerBridge.export_manifest(proj["project"], proj["scenes"])
        for clip in expected["clips"]:
            clip["file"] = clip["file"].replace(f"/projects/{project_id}/", "", 1)
        expected["projectId"] = project_id
        if proj["project"].get("assembler_manifest"):
            stored_clips = proj["project"]["assembler_manifest"].get("clips", [])
            expected["clips"] = expected["clips"] + [
                clip for clip in stored_clips if clip["file"] not in {item["file"] for item in expected["clips"]}
            ]
        if not isinstance(manifest, dict) or manifest.get("name") != expected["name"]:
            raise ValueError("El manifiesto no corresponde a este proyecto")
        if len(json.dumps(manifest, ensure_ascii=False)) > 2_000_000:
            raise ValueError("El manifiesto supera el tamaño máximo de 2 MiB")
        clips = manifest.get("clips")
        if not isinstance(clips, list) or not clips or len(clips) > 500:
            raise ValueError("El montaje debe contener entre 1 y 500 clips")
        allowed_files = {clip["file"] for clip in expected["clips"]}
        normalized = []
        for clip in clips:
            if not isinstance(clip, dict) or clip.get("file") not in allowed_files:
                raise ValueError("El montaje solo puede referenciar clips fuente asignados a este proyecto")
            try:
                start = float(clip.get("trimIn", 0))
                end = float(clip.get("trimOut", 0))
                speed = float(clip.get("speed", 1))
                volume = float(clip.get("audioVolume", 1))
            except (TypeError, ValueError) as error:
                raise ValueError("El clip contiene recortes o parámetros inválidos") from error
            source_scene = next((scene for scene in proj["scenes"] if (scene.get("source_video_src") or "").endswith("/" + clip["file"])), None)
            source_duration = float(source_scene.get("source_media_duration_seconds") or 0) if source_scene else 0
            if source_scene and source_duration <= 0:
                media = cls.db.get_source_media(project_id, source_scene.get("source_media_id"))
                source_duration = float((media or {}).get("duration_seconds") or 0)
            if source_scene and (start < 0 or (source_duration and end > source_duration + 0.05)):
                raise ValueError("El recorte debe permanecer dentro del tramo fuente asignado a la escena")
            if not all(math.isfinite(value) for value in (start, end, speed, volume)) or start < 0 or end <= start or speed <= 0 or not 0 <= volume <= 5:
                raise ValueError("El clip contiene recortes o parámetros fuera de rango")
            if end - start > 3600 or speed > 8:
                raise ValueError("El clip excede la duración o velocidad máxima permitida")
            if clip.get("cuts") is not None and (not isinstance(clip["cuts"], list) or len(clip["cuts"]) > 500):
                raise ValueError("Lista de cortes inválida")
            cuts = []
            for cut in clip.get("cuts", []):
                try:
                    cut_start, cut_end = float(cut["from"]), float(cut["to"])
                except (KeyError, TypeError, ValueError) as error:
                    raise ValueError("Corte inválido") from error
                if not math.isfinite(cut_start) or not math.isfinite(cut_end) or cut_start < start or cut_end > end or cut_end <= cut_start:
                    raise ValueError("Los cortes deben quedar dentro del tramo del clip")
                cuts.append({"from": cut_start, "to": cut_end})
            normalized.append({
                "file": clip["file"], "trimIn": start, "trimOut": end, "speed": speed,
                "keepAudio": bool(clip.get("keepAudio", False)), "audioVolume": volume,
                **({"cuts": cuts} if cuts else {}),
            })
        outputs = manifest.get("outputs")
        if not isinstance(outputs, list) or not outputs or any(value not in {"vertical", "horizontal"} for value in outputs):
            raise ValueError("Selecciona al menos un formato de salida compatible")
        if not isinstance(manifest.get("voice"), (dict, type(None))) or not isinstance(manifest.get("music"), (dict, type(None))):
            raise ValueError("Formato de audio inválido")
        for track_name in ("voice", "music"):
            track = manifest.get(track_name)
            if track is not None:
                raise ValueError("El montaje solo puede usar el audio original de clips asignados; la voz y música se mezclan en Remotion")
        if manifest.get("overlays"):
            raise ValueError("Las capas de video externas todavía no están habilitadas en el flujo de proyecto")
        saved = {
            "name": expected["name"], "clips": normalized,
            "voice": None, "music": None, "outputs": list(dict.fromkeys(outputs)),
            "projectId": project_id,
        }
        proj["project"]["assembler_manifest"] = saved
        proj["project"]["assembler_manifest_updated_at"] = time.time()
        proj["project"]["updated_at"] = time.time()
        cls._save_project(project_id, proj["project"], proj["scenes"])
        return saved

    @classmethod
    def update_scene(cls, project_id: str, scene_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        scenes = proj["scenes"]
        target = next((s for s in scenes if s["id"] == scene_id), None)
        if not target:
            raise ValueError(f"Escena {scene_id} no encontrada en proyecto {project_id}")

        if "source_media_id" in updates:
            media_id = updates["source_media_id"]
            media = cls.db.get_source_media(project_id, media_id) if media_id else None
            if media_id and not media:
                raise ValueError("El video fuente no pertenece a este proyecto")
            updates["source_media_id"] = media_id or None
            updates["source_video_src"] = f"/projects/{project_id}/{media['path']}" if media else None
            updates["source_media_duration_seconds"] = media.get("duration_seconds") if media else None
            if media and not updates.get("source_clip_duration_seconds"):
                source_duration = float(media.get("duration_seconds") or 10)
                start = float(updates.get("source_start_seconds", target.get("source_start_seconds", 0)) or 0)
                updates["source_clip_duration_seconds"] = min(10.0, max(0.1, source_duration - start))
            if not media:
                updates["source_audio_enabled"] = False
                updates["source_clip_duration_seconds"] = None

        assigned_media_id = updates.get("source_media_id", target.get("source_media_id"))
        if assigned_media_id:
            media = cls.db.get_source_media(project_id, assigned_media_id)
            if not media:
                raise ValueError("El video fuente no pertenece a este proyecto")
            media_duration = float(media.get("duration_seconds") or 0)
            start_seconds = float(updates.get("source_start_seconds", target.get("source_start_seconds", 0)) or 0)
            if not math.isfinite(start_seconds) or start_seconds < 0 or (media_duration and start_seconds >= media_duration):
                raise ValueError("El inicio del clip debe quedar dentro de la duración del video fuente")

        wants_original_audio = updates.get("source_audio_enabled", target.get("source_audio_enabled", False))
        if wants_original_audio:
            media_id = updates.get("source_media_id", target.get("source_media_id"))
            media = cls.db.get_source_media(project_id, media_id) if media_id else None
            if not media or not media.get("has_audio"):
                raise ValueError("Asigna un video fuente con pista de audio antes de activar su audio original")
            start = float(updates.get("source_start_seconds", target.get("source_start_seconds", 0)) or 0)
            duration = float(updates.get("source_clip_duration_seconds", target.get("source_clip_duration_seconds") or 0) or 0)
            media_duration = float(media.get("duration_seconds") or 0)
            if duration <= 0 or (media_duration and start + duration > media_duration + 0.05):
                raise ValueError("El tramo de audio debe quedar dentro de la duración del video fuente")

        visual_changed = any(
            key in updates and updates[key] != target.get(key)
            for key in ("narrative_text", "visual_description", "svg_prompt", "callout", "bg_color")
        )
        source_changed = any(
            key in updates and updates[key] != target.get(key)
            for key in ("source_media_id", "source_start_seconds", "source_audio_enabled", "source_clip_duration_seconds")
        )
        if visual_changed or source_changed:
            target["versions"].append({
                "timestamp": time.time(),
                "narrative_text": target.get("narrative_text", ""),
                "callout": target.get("callout", ""),
                "visual_description": target.get("visual_description", ""),
                "svg_prompt": target.get("svg_prompt", ""),
                "svg_markup": target.get("svg_markup", ""),
                "source_media_id": target.get("source_media_id"),
                "source_video_src": target.get("source_video_src"),
                "source_start_seconds": target.get("source_start_seconds", 0),
                "source_audio_enabled": target.get("source_audio_enabled", False),
                "source_clip_duration_seconds": target.get("source_clip_duration_seconds"),
                "audio_path": target.get("audio_path"),
                "audio_duration": target.get("audio_duration", 0),
            })

        for k, v in updates.items():
            if k not in ["id", "versions"]:
                target[k] = v

        if "source_media_id" in updates and updates["source_media_id"] is None:
            target["source_video_src"] = None
        if target.get("source_media_id") is None:
            target["source_video_src"] = None

        if visual_changed:
            target["audio_path"] = None
            target["audio_url"] = None
            target["audio_duration"] = 0.0
            target["words"] = []
            target["svg_markup"] = ""
            target["status"] = "pending_visual"
        elif source_changed:
            target["audio_path"] = None
            target["audio_url"] = None
            target["words"] = []
            if target.get("source_audio_enabled"):
                target["audio_duration"] = float(target.get("source_clip_duration_seconds") or 0)
                target["status"] = "source_audio_ready"
            else:
                target["audio_duration"] = 0.0
                target["status"] = "pending_audio"
        if visual_changed or source_changed:
            proj["project"]["storyboard_approved"] = False
            proj["project"]["script_approved"] = True
            proj["project"]["status"] = "storyboard_pending_approval"
            proj["project"]["updated_at"] = time.time()
        if visual_changed:
            asset_path = os.path.join(cls.get_project_dir(project_id), "assets", f"scene_{scene_id}.svg")
            if os.path.isfile(asset_path):
                os.remove(asset_path)

        cls._save_project(project_id, proj["project"], scenes)

        return {"project_id": project_id, "scene": target}

    @classmethod
    async def synthesize_scene_audio(cls, project_id: str, scene_id: int) -> Dict[str, Any]:
        """Sintetiza la voz exclusivamente de una escena y actualiza duraciones sin afectar otras."""
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        meta = proj["project"]
        scenes = proj["scenes"]
        scene = next((s for s in scenes if s["id"] == scene_id), None)
        if not scene:
            raise ValueError(f"Escena {scene_id} no encontrada")

        if scene.get("source_audio_enabled"):
            duration = float(scene.get("source_clip_duration_seconds") or 0)
            if duration <= 0:
                raise ValueError("Define la duración del tramo de audio fuente")
            scene["audio_path"] = None
            scene["audio_url"] = None
            scene["audio_duration"] = duration
            scene["words"] = []
            scene["status"] = "source_audio_ready"
            meta["total_real_duration"] = round(sum(float(item.get("audio_duration") or 0) for item in scenes), 2)
            meta["updated_at"] = time.time()
            cls._save_project(project_id, meta, scenes)
            return {"scene": scene, "total_real_duration": meta["total_real_duration"]}

        pdir = cls.get_project_dir(project_id)
        assets_dir = os.path.join(pdir, "assets")
        audio_filename = f"audio_s{scene_id}_{int(time.time())}.mp3"
        audio_path = os.path.join(assets_dir, audio_filename)

        res = await VoiceHub.synthesize(
            text=scene["narrative_text"],
            output_audio_path=audio_path,
            provider=meta.get("voice_provider", "edge-tts"),
            voice_id=meta.get("voice_id", "es-ES-AlvaroNeural")
        )

        scene["audio_path"] = audio_path
        scene["audio_url"] = f"/projects/{project_id}/assets/{audio_filename}"
        scene["audio_duration"] = res["duration"]
        scene["words"] = res["words"]
        scene["status"] = "audio_ready"

        # Recalcular duración total real acumulada
        total_duration = sum(s["audio_duration"] for s in scenes)
        meta["total_real_duration"] = round(total_duration, 2)
        meta["updated_at"] = time.time()

        cls._save_project(project_id, meta, scenes)

        return {"scene": scene, "total_real_duration": total_duration}

    @classmethod
    async def synthesize_all_project_audio(cls, project_id: str) -> Dict[str, Any]:
        """Sintetiza de forma secuencial y limpia el audio de todas las escenas pendientes."""
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        scenes = proj["scenes"]
        for s in scenes:
            if s.get("source_audio_enabled"):
                await cls.synthesize_scene_audio(project_id, s["id"])
                continue
            if s["status"] != "audio_ready" or not s["audio_path"] or not os.path.exists(s["audio_path"]):
                await cls.synthesize_scene_audio(project_id, s["id"])

        return cls.get_project(project_id)

    @classmethod
    async def regenerate_scene(cls, project_id: str, scene_id: int, mode: str = "all") -> Dict[str, Any]:
        """
        Regenera selectivamente una escena:
        - 'voice': Solo sintetiza nuevo audio.
        - 'visual': Solo actualiza el visual_description y sticker/imagen.
        - 'all': Actualiza texto de narración, visual y genera nuevo audio.
        """
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        scene = next((s for s in proj["scenes"] if s["id"] == scene_id), None)
        if not scene:
            raise ValueError(f"Escena {scene_id} no encontrada")

        if mode in ["all", "visual"]:
            stickers = ["question", "idea", "brain", "shock", "danger", "money", "arrow_up", "eye_patch"]
            # Alternar sticker y mejorar visual_description
            current_stk = scene.get("sticker", "question")
            next_stk = stickers[(stickers.index(current_stk) + 1) % len(stickers)] if current_stk in stickers else "idea"
            cls.update_scene(project_id, scene_id, {
                "sticker": next_stk,
                "visual_description": f"Nueva versión visual dinámica para {scene['title']} enfocada en {next_stk}"
            })

        if mode in ["all", "voice"]:
            await cls.synthesize_scene_audio(project_id, scene_id)

        return cls.get_project(project_id)
