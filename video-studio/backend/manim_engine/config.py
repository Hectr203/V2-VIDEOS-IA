"""
Configuración del motor Manim Community para Video Studio.
Define dimensiones verticales (1080x1920), 30 fps, canal alfa transparente y comando de ejecución.
"""

import os
import subprocess
from pathlib import Path

# Rutas base
BASE_DIR = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = BASE_DIR / "assets"
STICKERS_DIR = ASSETS_DIR / "stickers"
MOTION_DIR = ASSETS_DIR / "motion"

# Dimensiones verticales estándar (TikTok / Reels / Shorts)
WIDTH = 1080
HEIGHT = 1920
FPS = 30

DOCKER_IMAGE = "manimcommunity/manim:latest"

def run_manim(script_path: str, scene_name: str, output_name: str, quality: str = "m", transparent: bool = True):
    """
    Ejecuta el renderizado de Manim dentro del contenedor Docker aislado con exportación transparente.
    quality: 'l' (480p), 'm' (720p), 'h' (1080p)
    """
    script_abs = os.path.abspath(script_path)
    rel_script = os.path.relpath(script_abs, BASE_DIR)
    
    cmd = [
        "docker", "run", "--rm",
        "-u", f"{os.getuid()}:{os.getgid()}",
        "-v", f"{BASE_DIR}:/workspace",
        "-w", "/workspace",
        DOCKER_IMAGE,
        "manim",
        f"-q{quality}",
        "-r", f"{WIDTH},{HEIGHT}",
        "--fps", str(FPS),
        "--format", "webm",
    ]
    
    if transparent:
        cmd.append("-t")
        
    cmd.extend([
        "-o", output_name,
        rel_script,
        scene_name
    ])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Error renderizando escena {scene_name} con Manim:\n{result.stderr}\n{result.stdout}")
        
    return result.stdout
