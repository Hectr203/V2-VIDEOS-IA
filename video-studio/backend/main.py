import os
import glob
import time
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from services.voice_hub import VoiceHub
from services.project_manager import ProjectManager, PROJECTS_DIR
from services.render_service import render_project, render_single_scene
from services.script_generator import (
    AVAILABLE_STICKERS,
    AVAILABLE_SFX,
    BG_PALETTE
)

app = FastAPI(
    title="Video Studio IA Enterprise API",
    description="Orquestador audiovisual con IA, persistencia de proyectos y edición de storyboard",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../output"))
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(PROJECTS_DIR, exist_ok=True)

app.mount("/output", StaticFiles(directory=OUTPUT_DIR), name="output")
app.mount("/projects", StaticFiles(directory=PROJECTS_DIR), name="projects")

# Modelos Pydantic
class CreateProjectRequest(BaseModel):
    topic: str
    target_duration: Optional[int] = 60
    style: Optional[str] = "curiosity"
    voice_provider: Optional[str] = "edge-tts"
    voice_id: Optional[str] = "es-ES-AlvaroNeural"

class UpdateSceneRequest(BaseModel):
    narrative_text: Optional[str] = None
    callout: Optional[str] = None
    visual_description: Optional[str] = None
    sticker: Optional[str] = None
    sfx: Optional[str] = None
    bg_color: Optional[str] = None

class RegenerateSceneRequest(BaseModel):
    mode: Optional[str] = "all"  # "all", "voice", "visual"

@app.get("/api/health")
def health():
    return {"status": "ok", "version": "2.0.0", "timestamp": time.time()}

@app.get("/api/voice-catalog")
def get_voice_catalog():
    return {"providers": VoiceHub.get_catalog()}

@app.get("/api/assets")
def get_assets():
    return {
        "stickers": AVAILABLE_STICKERS,
        "sfx": AVAILABLE_SFX,
        "bg_palette": BG_PALETTE
    }

# ── Endpoints de Proyectos ─────────────────────────────

@app.post("/api/projects")
def create_project(req: CreateProjectRequest):
    try:
        data = ProjectManager.create_project(
            topic=req.topic,
            target_duration=req.target_duration or 60,
            style=req.style or "curiosity",
            voice_provider=req.voice_provider or "edge-tts",
            voice_id=req.voice_id or "es-ES-AlvaroNeural"
        )
        return {"success": True, "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/projects")
def list_projects():
    return {"projects": ProjectManager.list_projects()}

@app.get("/api/projects/{project_id}")
def get_project(project_id: str):
    p = ProjectManager.get_project(project_id)
    if not p:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    return {"success": True, "data": p}

@app.put("/api/projects/{project_id}/scenes/{scene_id}")
def update_scene(project_id: str, scene_id: int, req: UpdateSceneRequest):
    try:
        updates = {k: v for k, v in req.dict().items() if v is not None}
        res = ProjectManager.update_scene(project_id, scene_id, updates)
        return {"success": True, "data": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/scenes/{scene_id}/synthesize")
async def synthesize_scene(project_id: str, scene_id: int):
    try:
        res = await ProjectManager.synthesize_scene_audio(project_id, scene_id)
        return {"success": True, "data": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/scenes/{scene_id}/regenerate")
async def regenerate_scene(project_id: str, scene_id: int, req: RegenerateSceneRequest):
    try:
        res = await ProjectManager.regenerate_scene(project_id, scene_id, mode=req.mode or "all")
        return {"success": True, "data": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/synthesize-all")
async def synthesize_all_scenes(project_id: str):
    try:
        res = await ProjectManager.synthesize_all_project_audio(project_id)
        return {"success": True, "data": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/render")
async def render_full_project(project_id: str):
    try:
        # Asegurar que todas las escenas tengan audio
        proj = await ProjectManager.synthesize_all_project_audio(project_id)
        meta = proj["project"]
        scenes = proj["scenes"]

        filename = f"video_{project_id}_{int(time.time())}.mp4"
        res = render_project(meta, scenes, output_filename=filename)
        
        # Guardar URL del video final en el proyecto
        meta["final_video_url"] = res["video_url"]
        meta["status"] = "completed"
        pdir = ProjectManager.get_project_dir(project_id)
        with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
            import json
            json.dump(meta, f, ensure_ascii=False, indent=2)

        return {"success": True, "result": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/scenes/{scene_id}/preview")
async def preview_single_scene_render(project_id: str, scene_id: int):
    try:
        proj = ProjectManager.get_project(project_id)
        if not proj:
            raise HTTPException(status_code=404, detail="Proyecto no encontrado")
        scene = next((s for s in proj["scenes"] if s["id"] == scene_id), None)
        if not scene:
            raise HTTPException(status_code=404, detail="Escena no encontrada")

        if scene["status"] != "audio_ready" or not scene["audio_path"] or not os.path.exists(scene["audio_path"]):
            await ProjectManager.synthesize_scene_audio(project_id, scene_id)
            proj = ProjectManager.get_project(project_id)
            scene = next((s for s in proj["scenes"] if s["id"] == scene_id), None)

        filename = f"preview_{project_id}_s{scene_id}_{int(time.time())}.mp4"
        res = render_single_scene(scene, output_filename=filename)
        return {"success": True, "result": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/videos")
def list_videos():
    files = glob.glob(os.path.join(OUTPUT_DIR, "*.mp4"))
    files.sort(key=os.path.getmtime, reverse=True)
    videos = []
    for f in files:
        name = os.path.basename(f)
        size_mb = round(os.path.getsize(f) / (1024 * 1024), 2)
        created_at = os.path.getmtime(f)
        videos.append({
            "filename": name,
            "url": f"/output/{name}",
            "size_mb": size_mb,
            "created_at": created_at
        })
    return {"videos": videos}

# ── Integración con videoAssembler y Diagnóstico de Herramientas ───

from services.assembler_bridge import VideoAssemblerBridge

@app.get("/api/tools-status")
def get_tools_status():
    """Diagnóstico del estado de herramientas conectadas."""
    return {
        "remotion": {
            "name": "Remotion 4.x Engine",
            "status": "active",
            "type": "primary_renderer",
            "description": "Composiciones React 1080x1920 con física de resortes y subtítulos karaoke"
        },
        "video_assembler": {
            "name": "videoAssembler CLI / GUI",
            "status": "connected" if VideoAssemblerBridge.is_available() else "not_found",
            "path": "/mnt/nvme/V2-VIDEOS-IA/videoAssembler",
            "description": "Ensamblado con FFmpeg nativo acelerado mediante manifiesto.json"
        },
        "vibevoice": {
            "name": "Microsoft VibeVoice",
            "status": "detected" if os.path.exists("/mnt/nvme/V2-VIDEOS-IA/VibeVoice") else "not_found",
            "path": "/mnt/nvme/V2-VIDEOS-IA/VibeVoice",
            "description": "Modelo de voz y ASR local en CPU/PyTorch"
        },
        "omniroute": {
            "name": "OmniRoute AI Proxy (Azure)",
            "status": "connected",
            "url": "https://omniroute-api.azurewebsites.net",
            "description": "Proxy multi-proveedor con rotación de credenciales y combos"
        },
        "tella_style": {
            "name": "Tella Style Engine",
            "status": "integrated",
            "description": "Estructuración de guiones de caricatura y escenas ilustradas"
        },
        "shortgpt_style": {
            "name": "ShortGPT Retention Flow",
            "status": "integrated",
            "description": "Ritmo de corte rápido para YouTube Shorts, Reels y TikTok"
        }
    }

@app.post("/api/projects/{project_id}/export-assembler")
def export_assembler_manifest(project_id: str):
    """Exporta el proyecto actual como manifiesto.json para videoAssembler."""
    proj = ProjectManager.get_project(project_id)
    if not proj:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    
    output_manifest = os.path.join(PROJECTS_DIR, project_id, "video_assembler_manifest.json")
    VideoAssemblerBridge.export_manifest(proj["project"], proj["scenes"], output_manifest)
    return {
        "success": True,
        "manifest_path": output_manifest,
        "manifest_url": f"/projects/{project_id}/video_assembler_manifest.json"
    }
