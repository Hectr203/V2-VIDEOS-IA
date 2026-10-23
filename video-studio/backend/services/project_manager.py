import os
import json
import time
import shutil
import uuid
import re
import xml.etree.ElementTree as ET
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
        # Project IDs are path components, never arbitrary filesystem paths.
        if not re.fullmatch(r"proj_[A-Za-z0-9_-]+", project_id):
            raise ValueError("ID de proyecto inválido")
        return os.path.join(PROJECTS_DIR, project_id)

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

        with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
            json.dump(project_meta, f, ensure_ascii=False, indent=2)

        with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
            json.dump(scenes, f, ensure_ascii=False, indent=2)

        return {"project": project_meta, "scenes": scenes}

    @classmethod
    def approve_script(cls, project_id: str) -> Dict[str, Any]:
        proj = cls.get_project(project_id)
        if not proj:
            raise FileNotFoundError(f"Proyecto {project_id} no encontrado")
        meta = proj["project"]
        if meta.get("status") != "script_pending_approval":
            raise ValueError("El guion no está pendiente de aprobación")
        storyboard = OmniRouteClient.generate_storyboard_from_script(meta["script"], meta["style"])
        scenes = [{
            "id": s["id"], "act": s.get("act", 1), "title": s["title"],
            "narrative_text": s["narrative_text"], "visual_description": s.get("visual_description", ""),
            "svg_prompt": s.get("svg_prompt", s.get("visual_description", "")), "svg_markup": "",
            "callout": s.get("callout", ""), "visual_type": "svg", "visual_asset_url": None,
            "sticker": "", "sfx": s.get("sfx", "pop"), "bg_color": s.get("bg_color", "#FEF3C7"),
            "audio_path": None, "audio_url": None, "audio_duration": 0.0, "words": [],
            "status": "pending_visual", "versions": []
        } for s in storyboard["scenes"]]
        meta.update({"script_approved": True, "visual_theme": storyboard.get("visual_theme", ""),
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
        if not narration.strip() or len(narration) > 100_000:
            raise ValueError("El guion no puede estar vacío ni superar 100 000 caracteres")
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
        pdir = cls.get_project_dir(project_id)
        for filename, content in (("project.json", meta), ("scenes.json", scenes)):
            with open(os.path.join(pdir, filename), "w", encoding="utf-8") as f:
                json.dump(content, f, ensure_ascii=False, indent=2)

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

        visual_changed = any(
            key in updates and updates[key] != target.get(key)
            for key in ("narrative_text", "visual_description", "svg_prompt", "callout", "bg_color")
        )
        if visual_changed:
            target["versions"].append({
                "timestamp": time.time(),
                "narrative_text": target.get("narrative_text", ""),
                "callout": target.get("callout", ""),
                "visual_description": target.get("visual_description", ""),
                "svg_prompt": target.get("svg_prompt", ""),
                "svg_markup": target.get("svg_markup", ""),
                "audio_path": target.get("audio_path"),
                "audio_duration": target.get("audio_duration", 0),
            })
            target["audio_path"] = None
            target["audio_url"] = None
            target["audio_duration"] = 0.0
            target["words"] = []
            target["svg_markup"] = ""
            target["status"] = "pending_visual"
            proj["project"]["storyboard_approved"] = False
            proj["project"]["script_approved"] = True
            proj["project"]["status"] = "storyboard_pending_approval"
            proj["project"]["updated_at"] = time.time()
            asset_path = os.path.join(cls.get_project_dir(project_id), "assets", f"scene_{scene_id}.svg")
            if os.path.isfile(asset_path):
                os.remove(asset_path)

        pdir = cls.get_project_dir(project_id)
        with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
            json.dump(scenes, f, ensure_ascii=False, indent=2)
        with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
            json.dump(proj["project"], f, ensure_ascii=False, indent=2)

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
