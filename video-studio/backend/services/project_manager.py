import os
import json
import time
import shutil
import uuid
from typing import Dict, Any, List, Optional
from services.omniroute_client import OmniRouteClient
from services.voice_hub import VoiceHub

PROJECTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../projects"))
os.makedirs(PROJECTS_DIR, exist_ok=True)

class ProjectManager:
    """
    Gestor de persistencia, proyectos, escenas, sincronización y versionado recuperable.
    """

    @classmethod
    def get_project_dir(cls, project_id: str) -> str:
        return os.path.join(PROJECTS_DIR, project_id)

    @classmethod
    def create_project(
        cls,
        topic: str,
        target_duration: int = 60,
        style: str = "curiosity",
        voice_provider: str = "edge-tts",
        voice_id: str = "es-ES-AlvaroNeural"
    ) -> Dict[str, Any]:
        """Crea un proyecto persistido y genera su storyboard adaptativo."""
        project_id = f"proj_{int(time.time())}_{uuid.uuid4().hex[:6]}"
        pdir = cls.get_project_dir(project_id)
        assets_dir = os.path.join(pdir, "assets")
        os.makedirs(assets_dir, exist_ok=True)

        # Generar storyboard con el cliente OmniRoute
        sb = OmniRouteClient.generate_storyboard(topic, target_duration, style)

        # Inicializar escenas con versionado
        scenes = []
        for s in sb.get("scenes", []):
            scene_item = {
                "id": s["id"],
                "act": s.get("act", 1),
                "title": s["title"],
                "narrative_text": s["narrative_text"],
                "visual_description": s.get("visual_description", ""),
                "callout": s.get("callout", ""),
                "visual_type": s.get("visual_type", "image_ai"),
                "visual_asset_url": None,
                "sticker": s.get("sticker", "question"),
                "sfx": s.get("sfx", "pop"),
                "bg_color": s.get("bg_color", "#FEF3C7"),
                "audio_path": None,
                "audio_url": None,
                "audio_duration": 0.0,
                "words": [],
                "status": "pending_audio",
                "versions": []
            }
            scenes.append(scene_item)

        project_meta = {
            "id": project_id,
            "topic": topic,
            "target_duration_seconds": target_duration,
            "style": style,
            "voice_provider": voice_provider,
            "voice_id": voice_id,
            "visual_theme": sb.get("visual_theme", ""),
            "status": "created",
            "total_real_duration": 0.0,
            "scene_count": len(scenes),
            "created_at": time.time(),
            "updated_at": time.time(),
            "final_video_url": None
        }

        with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
            json.dump(project_meta, f, ensure_ascii=False, indent=2)

        with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
            json.dump(scenes, f, ensure_ascii=False, indent=2)

        return {"project": project_meta, "scenes": scenes}

    @classmethod
    def list_projects(cls) -> List[Dict[str, Any]]:
        projects = []
        if not os.path.exists(PROJECTS_DIR):
            return []
        for pid in sorted(os.listdir(PROJECTS_DIR), reverse=True):
            pfile = os.path.join(PROJECTS_DIR, pid, "project.json")
            if os.path.exists(pfile):
                try:
                    with open(pfile, "r", encoding="utf-8") as f:
                        projects.append(json.load(f))
                except Exception:
                    continue
        return projects

    @classmethod
    def get_project(cls, project_id: str) -> Optional[Dict[str, Any]]:
        pdir = cls.get_project_dir(project_id)
        pfile = os.path.join(pdir, "project.json")
        sfile = os.path.join(pdir, "scenes.json")
        if not os.path.exists(pfile) or not os.path.exists(sfile):
            return None

        with open(pfile, "r", encoding="utf-8") as f:
            meta = json.load(f)
        with open(sfile, "r", encoding="utf-8") as f:
            scenes = json.load(f)

        return {"project": meta, "scenes": scenes}

    @classmethod
    def update_scene(cls, project_id: str, scene_id: int, updates: Dict[str, Any]) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        scenes = proj["scenes"]
        target = next((s for s in scenes if s["id"] == scene_id), None)
        if not target:
            raise ValueError(f"Escena {scene_id} no encontrada en proyecto {project_id}")

        # Guardar snapshot de versión anterior si se cambia texto o visual
        if "narrative_text" in updates and updates["narrative_text"] != target["narrative_text"]:
            target["versions"].append({
                "timestamp": time.time(),
                "narrative_text": target["narrative_text"],
                "callout": target["callout"],
                "visual_description": target["visual_description"],
                "audio_path": target["audio_path"],
                "audio_duration": target["audio_duration"]
            })
            target["status"] = "outdated_audio"

        for k, v in updates.items():
            if k not in ["id", "versions"]:
                target[k] = v

        pdir = cls.get_project_dir(project_id)
        with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
            json.dump(scenes, f, ensure_ascii=False, indent=2)

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

        with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
            json.dump(scenes, f, ensure_ascii=False, indent=2)
        with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

        return {"scene": scene, "total_real_duration": total_duration}

    @classmethod
    async def synthesize_all_project_audio(cls, project_id: str) -> Dict[str, Any]:
        """Sintetiza de forma secuencial y limpia el audio de todas las escenas pendientes."""
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")

        scenes = proj["scenes"]
        for s in scenes:
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
