import os
import sys
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = BASE_DIR / "assets"
STICKERS_DIR = ASSETS_DIR / "stickers"
MOTION_DIR = ASSETS_DIR / "motion"
TEMPLATES_DIR = BASE_DIR / "backend" / "manim_engine" / "templates"

DOCKER_IMAGE = "manimcommunity/manim:latest"

def render_scene(script_rel: str, scene_name: str, out_filename: str, extra_env: dict = None):
    """
    Invoca Manim en el contenedor Docker para renderizar con transparencia (formato MOV argb y conversión rápida a WebM).
    """
    os.makedirs(MOTION_DIR, exist_ok=True)
    
    # Extra env vars para el contenedor
    env_args = []
    if extra_env:
        for k, v in extra_env.items():
            env_args.extend(["-e", f"{k}={v}"])
            
    mov_out_name = out_filename if out_filename.endswith(".mov") else out_filename + ".mov"
    
    cmd = [
        "docker", "run", "--rm",
        "-u", f"{os.getuid()}:{os.getgid()}",
        "-v", f"{BASE_DIR}:/workspace",
        "-w", "/workspace",
        *env_args,
        DOCKER_IMAGE,
        "manim",
        "-qm",
        "-r", "1080,1920",
        "--fps", "30",
        "-t",
        "--format", "mov",
        "-o", mov_out_name,
        script_rel,
        scene_name
    ]
    
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"❌ Error en Manim ({scene_name}):", res.stderr)
        return False
        
    return True

def convert_to_transparent_webm(mov_path: Path, webm_path: Path):
    """
    Convierte el archivo MOV (qtrle/argb) a WebM transparente optimizado para navegadores y Remotion.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", str(mov_path),
        "-c:v", "libvpx-vp9",
        "-pix_fmt", "yuva420p",
        "-auto-alt-ref", "0",
        str(webm_path)
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def process_kinetic_elements():
    """
    Renderiza los elementos cinéticos reutilizables.
    """
    print("\n⚡ Procesando elementos cinéticos reutilizables...")
    kinetic_scenes = [
        ("CurvedArrowScene", "cineticos/curved_arrow"),
        ("HighlightCircleScene", "cineticos/highlight_circle"),
        ("CheckMarkScene", "cineticos/check_mark"),
        ("CrossMarkScene", "cineticos/cross_mark"),
        ("VSBadgeScene", "cineticos/vs_badge"),
        ("ProgressBarScene", "cineticos/progress_bar"),
    ]
    
    script_rel = "backend/manim_engine/templates/kinetic_elements.py"
    
    for scene_name, rel_out in kinetic_scenes:
        target_dir = MOTION_DIR / os.path.dirname(rel_out)
        target_dir.mkdir(parents=True, exist_ok=True)
        out_name = os.path.basename(rel_out)
        webm_target = target_dir / f"{out_name}.webm"
        
        if webm_target.exists():
            print(f"⏩ [Caché] {rel_out}.webm ya existe.")
            continue
            
        print(f"🎬 Renderizando {scene_name} -> {rel_out}...")
        success = render_scene(script_rel, scene_name, f"{out_name}.mov")
        if success:
            # Manim guarda en media/videos/kinetic_elements/1920p30/<out_name>.mov
            source_mov = BASE_DIR / "media" / "videos" / "kinetic_elements" / "1920p30" / f"{out_name}.mov"
            if source_mov.exists():
                convert_to_transparent_webm(source_mov, webm_target)
                print(f"✅ Generado: {webm_target}")

def process_all_stickers():
    """
    Escanea assets/stickers por categorías y genera la animación de trazado para cada SVG.
    """
    print("\n📦 Escaneando biblioteca de stickers SVG...")
    script_rel = "backend/manim_engine/templates/svg_drawer.py"
    
    for category in os.listdir(STICKERS_DIR):
        cat_dir = STICKERS_DIR / category
        if not cat_dir.is_dir():
            continue
            
        for file in os.listdir(cat_dir):
            if not file.endswith(".svg"):
                continue
                
            stem = Path(file).stem
            rel_svg_path = f"assets/stickers/{category}/{file}"
            target_cat_dir = MOTION_DIR / category
            target_cat_dir.mkdir(parents=True, exist_ok=True)
            webm_target = target_cat_dir / f"{stem}.webm"
            
            if webm_target.exists():
                print(f"⏩ [Caché] {category}/{stem}.webm ya existe.")
                continue
                
            print(f"🎨 Animando SVG [{category}/{file}]...")
            env = {
                "MANIM_SVG_PATH": rel_svg_path,
                "MANIM_SCALE": "3.2",
                "MANIM_RUN_TIME": "1.2"
            }
            success = render_scene(script_rel, "GenericSVGDrawScene", f"{stem}.mov", extra_env=env)
            if success:
                source_mov = BASE_DIR / "media" / "videos" / "svg_drawer" / "1920p30" / f"{stem}.mov"
                if source_mov.exists():
                    convert_to_transparent_webm(source_mov, webm_target)
                    print(f"✅ Generado: {webm_target}")

if __name__ == "__main__":
    process_kinetic_elements()
    process_all_stickers()
    print("\n🎉 Catálogo de recursos reutilizables completado con éxito.")
