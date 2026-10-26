import os
import glob
import time
import threading
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional
from typing import Literal
from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from services.render_jobs import RenderJobStore

from services.voice_hub import VoiceHub
from services.project_manager import ProjectManager, PROJECTS_DIR
from services.omniroute_client import OMNIROUTE_API_KEY, OMNIROUTE_BASE_URL
from services.render_service import render_project, render_single_scene
from services.script_generator import (
    AVAILABLE_STICKERS,
    AVAILABLE_SFX,
    BG_PALETTE
)
from services.motion_service import MotionService
from manim_engine.ai_scene_generator import generate_manim_code_heuristic, render_custom_scene

app = FastAPI(
    title="Video Studio IA Enterprise API",
    description="Orquestador audiovisual con IA, persistencia de proyectos y edición de storyboard",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv(
        "VIDEO_STUDIO_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173"
    ).split(",") if origin.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../output"))
ASSETS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../assets"))
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(PROJECTS_DIR, exist_ok=True)
render_jobs = RenderJobStore(os.path.join(PROJECTS_DIR, "render_jobs"), db=ProjectManager.db)
_render_execution_lock = threading.Lock()

app.mount("/output", StaticFiles(directory=OUTPUT_DIR), name="output")
app.mount("/projects", StaticFiles(directory=PROJECTS_DIR), name="projects")
app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")

# Modelos Pydantic
class CustomSceneRequest(BaseModel):
    project_id: str = Field(min_length=6, max_length=100)
    scene_id: int = Field(gt=0, le=300)
    prompt: str = Field(min_length=1, max_length=2000)
    sticker_hint: Optional[str] = None
class CreateProjectRequest(BaseModel):
    topic: str = Field(min_length=3, max_length=500)
    target_duration: Optional[int] = Field(default=60, ge=30, le=3600)
    style: Optional[str] = "curiosity"
    voice_provider: Optional[str] = "edge-tts"
    voice_id: Optional[str] = "es-ES-AlvaroNeural"
    output_format: Literal["vertical", "horizontal"] = "vertical"

class UpdateScriptRequest(BaseModel):
    narration: str

class UpdateSceneRequest(BaseModel):
    narrative_text: Optional[str] = None
    callout: Optional[str] = None
    visual_description: Optional[str] = None
    svg_prompt: Optional[str] = None
    sticker: Optional[str] = None
    sfx: Optional[str] = None
    bg_color: Optional[str] = None
    source_media_id: Optional[str] = None
    source_start_seconds: Optional[float] = Field(default=None, ge=0)
    source_audio_enabled: Optional[bool] = None
    source_clip_duration_seconds: Optional[float] = Field(default=None, gt=0, le=3600)

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

# ── Endpoints de Movimiento y Manim ───────────────────

@app.get("/api/motion/library")
def get_motion_library():
    """Retorna los recursos vectoriales SVG y animaciones Manim clasificados por categorías."""
    return MotionService.get_library()

@app.post("/api/motion/render-custom")
def render_custom_manim_scene(req: CustomSceneRequest):
    """Genera y renderiza una escena Manim exclusiva para un proyecto."""
    try:
        project = ProjectManager.get_project(req.project_id)
        project_dir = Path(ProjectManager.get_project_dir(req.project_id))
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    if not project:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    if not any(scene.get("id") == req.scene_id for scene in project["scenes"]):
        raise HTTPException(status_code=404, detail="Escena no encontrada")
    code = generate_manim_code_heuristic(req.prompt, req.sticker_hint)
    out_file = project_dir / "motion" / f"scene_{req.scene_id}.webm"

    try:
        result = render_custom_scene(code, out_file)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("error", "Fallo al renderizar escena Manim"))
        
    # Actualizar la escena del proyecto si existe
    ProjectManager.update_scene(req.project_id, req.scene_id, {
        "motion_type": "manim",
        "manim_clip": result["relative_url"]
    })
    
    return result

# ── Endpoints de Proyectos ─────────────────────────────

@app.post("/api/projects")
def create_project(req: CreateProjectRequest):
    try:
        data = ProjectManager.create_project(
            topic=req.topic,
            target_duration=req.target_duration or 60,
            style=req.style or "curiosity",
            voice_provider=req.voice_provider or "edge-tts",
            voice_id=req.voice_id or "es-ES-AlvaroNeural",
            output_format=req.output_format,
        )
        return {"success": True, "data": data}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

@app.get("/api/projects")
def list_projects():
    return {"projects": ProjectManager.list_projects()}

@app.get("/api/projects/{project_id}")
def get_project(project_id: str):
    p = ProjectManager.get_project(project_id)
    if not p:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    return {"success": True, "data": p}

# ── Endpoints de Proyectos 2D Auto-Contenidos (Dashboard V2) ──

class Create2DProjectRequest(BaseModel):
    id: str = Field(min_length=3, max_length=60)
    title: str = Field(min_length=3, max_length=150)
    theme: Optional[str] = ""

class Render2DProjectRequest(BaseModel):
    stills: bool = False
    draft: bool = False
    aspect: str = "vertical"  # "vertical", "horizontal", "both"

@app.get("/api/v2/projects")
def list_2d_projects():
    """Escanea el directorio projects/ y lista todos los proyectos auto-contenidos."""
    import json
    results = []
    projects_dir = Path(PROJECTS_DIR)
    if not projects_dir.exists():
        return {"projects": []}

    for p in sorted(projects_dir.iterdir()):
        if not p.is_dir() or p.name.startswith(('.', '_')) or p.name == "node_modules":
            continue

        meta_path = p / "project.json"
        storyboard_path = p / "storyboard.json"
        timeline_path = p / "timeline.json"
        renders_dir = p / "renders"

        if not (meta_path.exists() or storyboard_path.exists()):
            continue

        meta = {}
        if meta_path.exists():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                pass

        storyboard = {}
        if storyboard_path.exists():
            try:
                storyboard = json.loads(storyboard_path.read_text(encoding="utf-8"))
            except Exception:
                pass

        duration_sec = 0.0
        fps = 30
        if timeline_path.exists():
            try:
                tl = json.loads(timeline_path.read_text(encoding="utf-8"))
                fps = tl.get("fps", 30)
                duration_sec = round(tl.get("durationInFrames", 0) / fps, 2)
            except Exception:
                pass

        scenes = storyboard.get("scenes", [])
        chapters = [sc.get("chapter") for sc in scenes if sc.get("chapter")]

        contact_sheet = renders_dir / "contact-sheet.jpg"
        master_mp4 = renders_dir / "master-1080p.mp4"
        master_16x9_mp4 = renders_dir / "master-16x9-1080p.mp4"
        preview_mp4 = renders_dir / "preview-720p.mp4"
        preview_16x9_mp4 = renders_dir / "preview-16x9-720p.mp4"
        stills_dir = renders_dir / "stills"

        master_size_mb = round(master_mp4.stat().st_size / (1024 * 1024), 1) if master_mp4.exists() else None
        master_16x9_size_mb = round(master_16x9_mp4.stat().st_size / (1024 * 1024), 1) if master_16x9_mp4.exists() else None
        preview_size_mb = round(preview_mp4.stat().st_size / (1024 * 1024), 1) if preview_mp4.exists() else None
        preview_16x9_size_mb = round(preview_16x9_mp4.stat().st_size / (1024 * 1024), 1) if preview_16x9_mp4.exists() else None

        vertical_url = f"/projects/{p.name}/renders/master-1080p.mp4" if master_mp4.exists() else (f"/projects/{p.name}/renders/preview-720p.mp4" if preview_mp4.exists() else None)
        horizontal_url = f"/projects/{p.name}/renders/master-16x9-1080p.mp4" if master_16x9_mp4.exists() else (f"/projects/{p.name}/renders/preview-16x9-720p.mp4" if preview_16x9_mp4.exists() else None)

        results.append({
            "id": p.name,
            "title": meta.get("title") or storyboard.get("title") or p.name.replace("-", " ").title(),
            "description": meta.get("description") or storyboard.get("editorialNotes") or "",
            "created_at": meta.get("created_at") or time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(p.stat().st_ctime)),
            "version": meta.get("version", "1.0.0"),
            "fps": fps,
            "scene_count": len(scenes),
            "duration_seconds": duration_sec,
            "chapters": chapters[:5],
            "voice": storyboard.get("voice", "es-MX-JorgeNeural"),
            "has_contact_sheet": contact_sheet.exists(),
            "contact_sheet_url": f"/projects/{p.name}/renders/contact-sheet.jpg" if contact_sheet.exists() else None,
            "has_master": master_mp4.exists(),
            "master_url": f"/projects/{p.name}/renders/master-1080p.mp4" if master_mp4.exists() else None,
            "master_size_mb": master_size_mb,
            "has_preview": preview_mp4.exists(),
            "preview_url": f"/projects/{p.name}/renders/preview-720p.mp4" if preview_mp4.exists() else None,
            "preview_size_mb": preview_size_mb,
            "has_master_16x9": master_16x9_mp4.exists(),
            "master_16x9_url": f"/projects/{p.name}/renders/master-16x9-1080p.mp4" if master_16x9_mp4.exists() else None,
            "master_16x9_size_mb": master_16x9_size_mb,
            "has_preview_16x9": preview_16x9_mp4.exists(),
            "preview_16x9_url": f"/projects/{p.name}/renders/preview-16x9-720p.mp4" if preview_16x9_mp4.exists() else None,
            "preview_16x9_size_mb": preview_16x9_size_mb,
            "has_vertical": bool(vertical_url),
            "vertical_video_url": vertical_url,
            "has_horizontal": bool(horizontal_url),
            "horizontal_video_url": horizontal_url,
            "stills_count": len(list(stills_dir.glob("*.png"))) if stills_dir.exists() else 0,
        })

    return {"projects": results}

@app.post("/api/v2/projects")
def create_2d_project(req: Create2DProjectRequest):
    import subprocess
    script = os.path.abspath(os.path.join(os.path.dirname(__file__), "../scripts/crear_produccion_2d.py"))
    cmd = ["python3", script, "--id", req.id, "--titulo", req.title]
    if req.theme:
        cmd.extend(["--tema", req.theme])
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {"success": True, "project_id": req.id, "output": proc.stdout}
    except subprocess.CalledProcessError as err:
        raise HTTPException(status_code=400, detail=err.stderr or err.stdout or "Error al crear proyecto")

@app.post("/api/v2/projects/{project_id}/render")
async def trigger_2d_render(project_id: str, req: Render2DProjectRequest, background_tasks: BackgroundTasks):
    import subprocess
    proj_dir = Path(PROJECTS_DIR) / project_id
    render_script = proj_dir / "render.mjs"
    if not render_script.exists():
        raise HTTPException(status_code=404, detail=f"Script de render no encontrado para {project_id}")

    cmd = ["node", str(render_script)]
    if req.stills:
        cmd.append("--stills")
    if req.draft:
        cmd.append("--draft")
    if req.aspect == "horizontal":
        cmd.append("--aspect=horizontal")
    elif req.aspect == "both":
        cmd.append("--aspect=both")

    def run_render():
        subprocess.run(cmd, cwd=str(proj_dir), check=False)

    background_tasks.add_task(run_render)
    return {
        "success": True,
        "message": f"Renderizado iniciado para {project_id}",
        "command": " ".join(cmd)
    }

@app.get("/api/projects/{project_id}/source-media")
def list_project_source_media(project_id: str):
    try:
        return {"media": ProjectManager.list_source_media(project_id)}
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error))

@app.put("/api/projects/{project_id}/source-media")
async def upload_project_source_media(project_id: str, request: Request, filename: str):
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            if int(content_length) > ProjectManager.MAX_SOURCE_MEDIA_BYTES:
                raise HTTPException(status_code=413, detail="El video supera el límite local de 2 GiB")
        except ValueError as error:
            if isinstance(error, HTTPException):
                raise
            raise HTTPException(status_code=400, detail="Content-Length inválido")
    try:
        media = await ProjectManager.add_source_media_stream(project_id, filename, request.stream())
        return {"success": True, "media": media}
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error))
    except ValueError as error:
        status = 413 if "2 GiB" in str(error) else 400
        raise HTTPException(status_code=status, detail=str(error))

@app.put("/api/projects/{project_id}/scenes/{scene_id}")
def update_scene(project_id: str, scene_id: int, req: UpdateSceneRequest):
    try:
        updates = {k: v for k, v in req.model_dump().items() if v is not None}
        res = ProjectManager.update_scene(project_id, scene_id, updates)
        return {"success": True, "data": res}
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error))
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/scenes/{scene_id}/synthesize")
async def synthesize_scene(project_id: str, scene_id: int):
    try:
        res = await ProjectManager.synthesize_scene_audio(project_id, scene_id)
        return {"success": True, "data": res}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/projects/{project_id}/approve-script")
def approve_script(project_id: str):
    try:
        return {"success": True, "data": ProjectManager.approve_script(project_id)}
    except (FileNotFoundError, ValueError) as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

@app.post("/api/projects/{project_id}/generate-storyboard")
def generate_storyboard(project_id: str):
    try:
        return {"success": True, "data": ProjectManager.generate_storyboard(project_id)}
    except (FileNotFoundError, ValueError) as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

@app.put("/api/projects/{project_id}/script")
def update_script(project_id: str, req: UpdateScriptRequest):
    try:
        return {"success": True, "data": ProjectManager.update_script(project_id, req.narration)}
    except (FileNotFoundError, ValueError) as e:
        raise HTTPException(status_code=409, detail=str(e))

@app.post("/api/projects/{project_id}/approve-storyboard")
def approve_storyboard(project_id: str):
    try:
        return {"success": True, "data": ProjectManager.approve_storyboard(project_id)}
    except (FileNotFoundError, ValueError) as e:
        raise HTTPException(status_code=409, detail=str(e))

@app.post("/api/projects/{project_id}/scenes/{scene_id}/generate-svg")
def generate_scene_svg(project_id: str, scene_id: int):
    try:
        return {"success": True, "data": ProjectManager.generate_scene_svg(project_id, scene_id)}
    except (FileNotFoundError, ValueError) as e:
        raise HTTPException(status_code=409, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

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

def _run_render_job(job_id: str, project_id: str) -> None:
    _render_execution_lock.acquire()
    try:
        current_job = render_jobs.get(job_id)
        if not current_job or current_job.get("status") == "cancelled" or current_job.get("cancel_requested"):
            if current_job and current_job.get("status") != "cancelled":
                render_jobs.update(job_id, status="cancelled", message="Cancelado")
            return
        project = ProjectManager.get_project(project_id)
        if not project:
            raise FileNotFoundError("Proyecto no encontrado")
        job = render_jobs.get(job_id) or {}
        if job.get("cancel_requested"):
            render_jobs.update(job_id, status="cancelled", message="Cancelado")
            return
        render_jobs.update(job_id, status="preparing", progress=2, message="Preparando audios")
        proj = asyncio.run(ProjectManager.synthesize_all_project_audio(project_id))
        meta = proj["project"]
        scenes = proj["scenes"]
        job = render_jobs.get(job_id) or {}
        if job.get("cancel_requested"):
            render_jobs.update(job_id, status="cancelled", message="Cancelado")
            return
        render_jobs.update(job_id, status="rendering", progress=10, message="Render local con Remotion")
        filename = f"video_{project_id}_{job_id}.mp4"
        res = render_project(
            meta, scenes, output_filename=filename,
            checkpoint_id=job_id,
            progress_callback=lambda pct: render_jobs.update(
                job_id, progress=10 + int(pct * 0.88), message=f"Renderizando: {pct}%"
            ),
            cancel_check=lambda: bool((render_jobs.get(job_id) or {}).get("cancel_requested")),
        )
        meta["final_video_url"] = res["video_url"]
        meta["status"] = "completed"
        ProjectManager._save_project(project_id, meta, scenes)
        render_jobs.update(job_id, status="completed", progress=100, message="Render completado", result=res)
    except Exception as e:
        status = "cancelled" if (render_jobs.get(job_id) or {}).get("cancel_requested") else "failed"
        render_jobs.update(job_id, status=status, message="Cancelado" if status == "cancelled" else str(e))
    finally:
        _render_execution_lock.release()

@app.post("/api/projects/{project_id}/render")
def render_full_project(project_id: str):
    project = ProjectManager.get_project(project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    if not project["project"].get("storyboard_approved"):
        raise HTTPException(status_code=409, detail="Aprueba el storyboard antes del render")
    if not project["scenes"] or any(not scene.get("svg_markup") and not scene.get("source_media_id") for scene in project["scenes"]):
        raise HTTPException(status_code=409, detail="Cada escena debe tener un SVG original o un clip fuente asignado antes del render")
    job, should_start = render_jobs.create_or_get(project_id)
    if should_start:
        worker = threading.Thread(target=_run_render_job, args=(job["id"], project_id), daemon=True)
        worker.start()
    return {"success": True, "job": job, "created": should_start and not job.get("resumed"),
            "resumed": should_start and bool(job.get("resumed"))}

@app.get("/api/projects/{project_id}/render-job")
def get_latest_project_render_job(project_id: str):
    if not ProjectManager.get_project(project_id):
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    jobs = ProjectManager.db.list_jobs(project_id)
    # Active jobs take precedence over a newer terminal job so the UI can always
    # reconnect to work that is still progressing after a page reload.
    job = next((item for item in jobs if item.get("status") in {"queued", "preparing", "rendering"}), None)
    return {"success": True, "job": job or (jobs[0] if jobs else None)}

@app.get("/api/render-jobs/{job_id}")
def get_render_job(job_id: str):
    job = render_jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Trabajo de render no encontrado")
    return {"success": True, "job": job}

@app.post("/api/render-jobs/{job_id}/cancel")
def cancel_render_job(job_id: str):
    job = render_jobs.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Trabajo de render no encontrado")
    if job["status"] == "completed":
        raise HTTPException(status_code=409, detail="El render ya terminó")
    return {"success": True, "job": render_jobs.request_cancel(job_id)}

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
            if not proj:
                raise HTTPException(status_code=404, detail="Proyecto no encontrado")
            scene = next((s for s in proj["scenes"] if s["id"] == scene_id), None)
            if not scene:
                raise HTTPException(status_code=404, detail="Escena no encontrada")

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
    repository_root = Path(__file__).resolve().parents[2]
    remotion_package = repository_root / "video-studio" / "remotion" / "node_modules" / "remotion" / "package.json"
    applio_dir = repository_root / "Applio"
    return {
        "remotion": {
            "name": "Remotion 4.x Engine",
            "status": "available" if remotion_package.is_file() else "not_found",
            "type": "primary_renderer",
            "description": "Motor de render local; disponibilidad basada en la instalación del paquete Remotion"
        },
        "video_assembler": {
            "name": "videoAssembler CLI / GUI",
            "status": "connected" if VideoAssemblerBridge.is_available() else "not_found",
            "path": str(repository_root / "videoAssembler"),
            "description": "Ensamblado con FFmpeg nativo acelerado mediante manifiesto.json"
        },
        "applio": {
            "name": "Applio (RVC v2)",
            "status": "connected" if applio_dir.is_dir() else "not_found",
            "path": str(applio_dir),
            "url": "http://127.0.0.1:6969",
            "description": "Motor local de clonación y conversión de voz RVC v2 con interfaz web activa en puerto 6969"
        },
        "omniroute": {
            "name": "OmniRoute AI Proxy (Azure)",
            "status": "configured" if OMNIROUTE_API_KEY else "not_configured",
            "url": OMNIROUTE_BASE_URL,
            "description": "La etiqueta indica únicamente si hay una clave configurada; la conectividad se comprueba al generar contenido"
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

@app.get("/api/projects/{project_id}/export-assembler")
def export_assembler_manifest(project_id: str):
    """Devuelve el montaje persistido o un manifiesto inicial, sin alterar el proyecto."""
    proj = ProjectManager.get_project(project_id)
    if not proj:
        raise HTTPException(status_code=404, detail="Proyecto no encontrado")
    
    try:
        project_manifest = proj["project"].get("assembler_manifest")
        manifest = project_manifest or VideoAssemblerBridge.export_manifest(proj["project"], proj["scenes"])
        manifest["projectId"] = project_id
        if not project_manifest:
            for clip in manifest["clips"]:
                clip["file"] = clip["file"].replace(f"/projects/{project_id}/", "", 1)
        return {"success": True, "manifest": manifest, "projectManifest": project_manifest}
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error

@app.put("/api/projects/{project_id}/assembler-manifest")
def save_assembler_manifest(project_id: str, payload: Dict[str, Any]):
    try:
        manifest = ProjectManager.save_assembler_manifest(project_id, payload)
        return {"success": True, "manifest": manifest}
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
