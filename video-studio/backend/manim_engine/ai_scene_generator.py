import os
import re
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional

BASE_DIR = Path(__file__).resolve().parent.parent.parent
PROJECTS_DIR = BASE_DIR / "projects"
DOCKER_IMAGE = "manimcommunity/manim:latest"

MANIM_AI_SYSTEM_PROMPT = """Eres un experto desarrollador de animaciones en Manim Community v0.22.0 especializado en videos verticales de alta retención (9:16, 1080x1920).
Tu objetivo es generar una clase de Scene en Python válida para Manim.

REGLAS CRÍTICAS:
1. El video es VERTICAL (relación 9:16). El centro es (0,0). Los límites visibles son:
   - X: de -4.5 a 4.5
   - Y: de -8.0 a 8.0
2. El fondo SIEMPRE debe ser transparente (no dibujes fondos negros ni uses self.camera.background_color).
3. Usa tipografía grande y clara (Text con font_size entre 48 y 72) y colores vivos (YELLOW, GREEN, BLUE_C, RED, PURPLE_B).
4. Emplea animaciones dinámicas: Create, DrawBorderThenFill, Transform, Wiggle, SpinInFromNothing.
5. Puedes usar SVGMobject para cargar vectores de 'assets/stickers/<categoria>/<archivo>.svg'.
6. La clase principal DEBE llamarse 'UniqueScene' y heredar de Scene:
   class UniqueScene(Scene):
       def construct(self):
           ...
7. Responde ÚNICAMENTE con código Python ejecutable dentro de un bloque ```python ... ```, sin explicaciones adicionales.
"""

def generate_manim_code_heuristic(prompt: str, sticker_hint: Optional[str] = None) -> str:
    """
    Generador heurístico de respaldo (sin necesidad de LLM o API Key externa)
    para diagramas de conexión, ideas y flechas explicativas.
    """
    svg_line = ""
    if sticker_hint and re.fullmatch(r"assets/stickers/[A-Za-z0-9_-]+\.svg", sticker_hint):
        svg_line = f'svg = SVGMobject({json.dumps(sticker_hint)}).scale(2.2).move_to(UP * 2)'
    else:
        svg_line = 'svg = Circle(radius=1.8, color=YELLOW, fill_opacity=0.3).move_to(UP * 2)'

    code = f'''from manim import *

class UniqueScene(Scene):
    def construct(self):
        # Elemento central
        {svg_line}
        
        # Título conceptual
        title = Text({json.dumps(prompt[:30].upper(), ensure_ascii=False)}, font_size=56, weight=BOLD, color=WHITE)
        title.next_to(svg, DOWN, buff=0.8)
        
        # Flecha indicadora
        arrow = CurvedArrow(DOWN * 3 + LEFT * 2, DOWN * 1.2 + RIGHT * 0.5, color=YELLOW, stroke_width=8)
        
        # Animaciones de entrada
        self.play(DrawBorderThenFill(svg, run_time=1.0))
        self.play(Write(title, run_time=0.8), Create(arrow, run_time=0.8))
        self.play(Wiggle(svg, run_time=0.5))
        self.wait(1.0)
'''
    return code

def render_custom_scene(python_code: str, output_path: Path, scene_name: str = "UniqueScene") -> Dict[str, Any]:
    """
    Escribe el script generado en disco, lo ejecuta dentro del contenedor de Manim y exporta a WebM transparente.
    """
    project_motion_dir = output_path.parent.resolve()
    projects_root = PROJECTS_DIR.resolve()
    if project_motion_dir.name != "motion" or project_motion_dir.parent.parent != projects_root:
        raise ValueError("La salida de Manim debe estar dentro de motion/ de un proyecto local")
    if not re.fullmatch(r"scene_[1-9]\d*", output_path.stem) or scene_name != "UniqueScene":
        raise ValueError("Nombre de escena Manim inválido")
    project_motion_dir.mkdir(parents=True, exist_ok=True)
    stickers_dir = BASE_DIR / "video-studio" / "remotion" / "public" / "stickers"
    mov_name = f"{output_path.stem}.mov"

    # El contenedor sólo puede escribir en un workspace efímero del proyecto;
    # se le niegan red, capabilities y recursos sin límite.
    with tempfile.TemporaryDirectory(prefix="manim_", dir=project_motion_dir) as workspace:
        temp_script = Path(workspace) / "scene_script.py"
        temp_script.write_text(python_code, encoding="utf-8")
        cmd = [
            "docker", "run", "--rm", "--network=none", "--read-only",
            "--memory=3g", "--cpus=2", "--pids-limit=256",
            "--security-opt=no-new-privileges", "--cap-drop=ALL",
            "--tmpfs", "/tmp:rw,nosuid,nodev,size=1g",
            "-e", "HOME=/tmp", "-e", "XDG_CACHE_HOME=/tmp/.cache",
            "-u", f"{os.getuid()}:{os.getgid()}",
            "-v", f"{workspace}:/workspace:rw",
            "-v", f"{stickers_dir}:/workspace/assets/stickers:ro",
            "-w", "/workspace", DOCKER_IMAGE,
            "manim", "-qm", "-r", "1080,1920", "--fps", "30", "-t",
            "--format", "mov", "-o", mov_name, "scene_script.py", scene_name,
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=900, check=False)
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "La generación Manim superó el límite de 15 minutos"}
        if res.returncode != 0:
            return {"success": False, "error": f"Error compilando escena Manim: {(res.stderr or res.stdout)[-4000:]}"}

        source_mov = Path(workspace) / "media" / "videos" / "scene_script" / "1920p30" / mov_name
        if not source_mov.exists():
            return {"success": False, "error": f"No se encontró el MOV renderizado: {mov_name}"}

        webm_path = output_path.with_suffix(".webm")
        conv_cmd = [
            "ffmpeg", "-y", "-i", str(source_mov), "-c:v", "libvpx-vp9",
            "-pix_fmt", "yuva420p", "-auto-alt-ref", "0", str(webm_path),
        ]
        try:
            converted = subprocess.run(conv_cmd, capture_output=True, text=True, timeout=900, check=False)
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "La conversión WebM superó el límite de 15 minutos"}
        if converted.returncode != 0 or not webm_path.is_file():
            return {"success": False, "error": f"FFmpeg no pudo crear WebM: {(converted.stderr or converted.stdout)[-4000:]}"}
    
    return {
        "success": True,
        "video_path": str(webm_path),
        "relative_url": f"/projects/{output_path.parent.parent.name}/motion/{webm_path.name}"
    }
