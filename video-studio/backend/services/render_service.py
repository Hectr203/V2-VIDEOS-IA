import os
import json
import base64
import subprocess
import time
from typing import Dict, Any, List

REMOTION_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../remotion"))
PUBLIC_DIR = os.path.join(REMOTION_DIR, "public")
OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../output"))
os.makedirs(OUTPUT_DIR, exist_ok=True)

def render_project(
    project_meta: Dict[str, Any],
    scenes: List[Dict[str, Any]],
    output_filename: str,
    fps: int = 30
) -> Dict[str, Any]:
    """
    Renderiza un proyecto completo (desde 1 minuto hasta 10 minutos) con Remotion.
    Cada escena aporta su audio real, palabras para subtítulos y elemento visual.
    """
    start_time = time.time()
    
    # 1. Preparar lista concatenada de palabras y audios por escena
    all_words = []
    scenes_props = []
    scenes_timing = []
    accumulated_seconds = 0.0

    for s in scenes:
        dur = max(s.get("audio_duration", 0.0), 2.0)
        start_frame = int(accumulated_seconds * fps)
        dur_frames = int(dur * fps)

        # Desplazar los tiempos de las palabras para el karaoke global
        for w in s.get("words", []):
            all_words.append({
                "word": w["word"],
                "start": round(accumulated_seconds + w["start"], 3),
                "end": round(accumulated_seconds + w["end"], 3)
            })

        # Codificar audio de la escena en data URI
        audio_path = s.get("audio_path")
        audio_data_uri = ""
        if audio_path and os.path.exists(audio_path):
            with open(audio_path, "rb") as af:
                b64 = base64.b64encode(af.read()).decode("utf-8")
                audio_data_uri = f"data:audio/mp3;base64,{b64}"

        scenes_props.append({
            "id": s["id"],
            "title": s["title"],
            "text": s["narrative_text"],
            "callout": s.get("callout", ""),
            "sticker": s.get("sticker", "question"),
            "sfx": s.get("sfx", "pop"),
            "bg_color": s.get("bg_color", "#FEF3C7"),
            "motion_type": s.get("motion_type", "sticker"),
            "manim_clip": s.get("manim_clip"),
            "audio_data_uri": audio_data_uri,
            "start_frame": start_frame,
            "duration_in_frames": dur_frames
        })

        accumulated_seconds += dur

    total_frames = int(accumulated_seconds * fps) + 15

    props = {
        "scenes": scenes_props,
        "words": all_words,
        "durationInFrames": total_frames
    }

    props_path = os.path.join(REMOTION_DIR, "project_props.json")
    with open(props_path, "w", encoding="utf-8") as f:
        json.dump(props, f, ensure_ascii=False, indent=2)

    final_mp4_path = os.path.join(OUTPUT_DIR, output_filename)

    cmd = [
        "npx", "remotion", "render",
        "src/index.ts",
        "DoodleReel",
        final_mp4_path,
        f"--props={props_path}",
        "--public-dir=public",
        "--concurrency=50%",
        "--gl=angle",
        "--quiet"
    ]

    print(f"[RenderService] Renderizando proyecto ({total_frames} frames / {round(accumulated_seconds, 1)}s)...")
    res = subprocess.run(cmd, cwd=REMOTION_DIR, capture_output=True, text=True)

    if res.returncode != 0:
        print("[RenderService Error]:", res.stderr)
        raise RuntimeError(f"Error renderizando proyecto con Remotion: {res.stderr or res.stdout}")

    elapsed = round(time.time() - start_time, 2)
    file_size_mb = round(os.path.getsize(final_mp4_path) / (1024 * 1024), 2)

    return {
        "video_path": final_mp4_path,
        "video_url": f"/output/{output_filename}",
        "filename": output_filename,
        "duration_seconds": round(accumulated_seconds, 2),
        "duration_frames": total_frames,
        "size_mb": file_size_mb,
        "render_time_seconds": elapsed
    }

def render_single_scene(
    scene: Dict[str, Any],
    output_filename: str,
    fps: int = 30
) -> Dict[str, Any]:
    """Renderiza ultrarrápido una sola escena para previsualización aislada."""
    return render_project(
        project_meta={"id": "preview_single"},
        scenes=[scene],
        output_filename=output_filename,
        fps=fps
    )

def render_video(
    storyboard: Dict[str, Any],
    audio_info: Dict[str, Any],
    output_filename: str,
    fps: int = 30
) -> Dict[str, Any]:
    """Renderiza a partir de storyboard y audio_info."""
    scenes = storyboard.get("scenes", [])
    total_audio_duration = audio_info.get("duration", 30.0)
    audio_path = audio_info.get("audio_path")
    words = audio_info.get("words", [])

    per_scene_dur = total_audio_duration / max(len(scenes), 1)

    scenes_props = []
    accumulated_seconds = 0.0
    for i, s in enumerate(scenes):
        dur = per_scene_dur
        start_frame = int(accumulated_seconds * fps)
        dur_frames = int(dur * fps)
        scenes_props.append({
            "id": s["id"],
            "title": s.get("title", f"Escena {i+1}"),
            "text": s.get("text", s.get("narrative_text", "")),
            "callout": s.get("callout", ""),
            "sticker": s.get("sticker", "question"),
            "sfx": s.get("sfx", "pop"),
            "bg_color": s.get("bg_color", "#FEF3C7"),
            "motion_type": s.get("motion_type", "sticker"),
            "manim_clip": s.get("manim_clip"),
            "audio_data_uri": "",
            "start_frame": start_frame,
            "duration_in_frames": dur_frames
        })
        accumulated_seconds += dur

    total_frames = int(accumulated_seconds * fps) + 15

    voice_audio_src = ""
    if audio_path and os.path.exists(audio_path):
        with open(audio_path, "rb") as af:
            b64 = base64.b64encode(af.read()).decode("utf-8")
            voice_audio_src = f"data:audio/mp3;base64,{b64}"

    props = {
        "scenes": scenes_props,
        "words": words,
        "voiceAudioSrc": voice_audio_src,
        "durationInFrames": total_frames
    }

    props_path = os.path.join(REMOTION_DIR, "project_props.json")
    with open(props_path, "w", encoding="utf-8") as f:
        json.dump(props, f, ensure_ascii=False, indent=2)

    final_mp4_path = os.path.join(OUTPUT_DIR, output_filename)

    cmd = [
        "npx", "remotion", "render",
        "src/index.ts",
        "DoodleReel",
        final_mp4_path,
        f"--props={props_path}",
        "--public-dir=public",
        "--concurrency=50%",
        "--gl=angle",
        "--quiet"
    ]

    start_time = time.time()
    res = subprocess.run(cmd, cwd=REMOTION_DIR, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"Error renderizando video con Remotion: {res.stderr or res.stdout}")

    elapsed = round(time.time() - start_time, 2)
    file_size_mb = round(os.path.getsize(final_mp4_path) / (1024 * 1024), 2)
    return {
        "video_path": final_mp4_path,
        "video_url": f"/output/{output_filename}",
        "filename": output_filename,
        "duration_seconds": round(accumulated_seconds, 2),
        "duration_frames": total_frames,
        "size_mb": file_size_mb,
        "render_time_seconds": elapsed
    }

