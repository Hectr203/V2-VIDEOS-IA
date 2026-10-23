import os
import json
import base64
import subprocess
import time
import re
import tempfile
import threading
import queue
import signal
import shutil
import math
import hashlib
from typing import Dict, Any, List, Optional

REMOTION_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../remotion"))
PUBLIC_DIR = os.path.join(REMOTION_DIR, "public")
OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../output"))
PROJECTS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../projects"))
CHECKPOINTS_DIR = os.path.abspath(os.path.join(os.path.dirname(OUTPUT_DIR), "render_checkpoints"))
RENDER_CHECKPOINT_CHUNK_SECONDS = 60
os.makedirs(OUTPUT_DIR, exist_ok=True)


def _render_concurrency() -> str:
    value = os.getenv("VIDEO_STUDIO_RENDER_CONCURRENCY", "25%").strip()
    if not re.fullmatch(r"[1-9]\d*(?:%)?", value):
        raise ValueError("VIDEO_STUDIO_RENDER_CONCURRENCY debe ser entero positivo o porcentaje")
    number = int(value.rstrip("%"))
    if value.endswith("%") and number > 100:
        raise ValueError("El porcentaje de concurrencia de Remotion no puede superar 100%")
    return value


def _validate_fps(fps: int) -> int:
    if isinstance(fps, bool) or not isinstance(fps, int) or fps <= 0 or fps > 120:
        raise ValueError("FPS debe ser un entero entre 1 y 120")
    return fps


def _output_path(output_filename: str) -> str:
    if not output_filename or os.path.basename(output_filename) != output_filename or not output_filename.lower().endswith(".mp4"):
        raise ValueError("Nombre de salida MP4 inválido")
    path = os.path.join(OUTPUT_DIR, output_filename)
    if os.path.exists(path):
        raise FileExistsError(f"El archivo de salida ya existe: {output_filename}")
    return path


def _validate_rendered_video(path: str, expected_duration_seconds: float, fps: int) -> Dict[str, Any]:
    """Reject missing, corrupt, or materially truncated MP4 output before publishing it."""
    _validate_fps(fps)
    if not math.isfinite(expected_duration_seconds) or expected_duration_seconds < 0:
        raise ValueError("Duración esperada y FPS deben ser valores válidos")
    if not os.path.isfile(path) or os.path.getsize(path) <= 0:
        raise RuntimeError("Remotion terminó sin crear un archivo de video válido")
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type", "-of", "json", path],
        capture_output=True, text=True, timeout=60, check=False,
    )
    if probe.returncode != 0:
        raise RuntimeError("FFprobe no pudo validar el MP4 renderizado: " + (probe.stderr or "formato inválido")[-1000:])
    try:
        metadata = json.loads(probe.stdout)
        duration = float(metadata["format"]["duration"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise RuntimeError("FFprobe devolvió metadatos incompletos para el MP4 renderizado") from error
    streams = metadata.get("streams", [])
    if not any(stream.get("codec_type") == "video" for stream in streams):
        raise RuntimeError("El resultado no contiene una pista de video")
    if not math.isfinite(duration) or duration <= 0:
        raise RuntimeError("El resultado tiene una duración inválida")
    # Scale tolerance for long multi-segment renders: each segment concatenation
    # can introduce up to 1-2 audio sample frames (~0.02s) due to AAC priming/padding.
    # For short clips (<=60s), keep strict max(0.25, 2 / fps). For longer renders, allow 0.05s per 60s segment.
    tolerance = max(0.25, 2 / fps, 0.05 * (expected_duration_seconds / 60.0))
    if abs(duration - expected_duration_seconds) > tolerance:
        raise RuntimeError(
            f"Duración del MP4 ({duration:.2f}s) no coincide con la esperada "
            f"({expected_duration_seconds:.2f}s; tolerancia {tolerance:.2f}s)"
        )
    return {"duration_seconds": round(duration, 3), "streams": streams}


def _publish_validated_output(render_path: str, final_path: str, expected_duration_seconds: float, fps: int) -> Dict[str, Any]:
    metadata = _validate_rendered_video(render_path, expected_duration_seconds, fps)
    # Same-directory hard-link publication is atomic and fails if another writer
    # created the destination after _output_path checked it; never clobber output.
    os.link(render_path, final_path)
    try:
        os.unlink(render_path)
    except OSError:
        # A complete, validated final file is already published; the caller's
        # failure cleanup will make a best-effort removal of this partial alias.
        pass
    return metadata


def _render_fingerprint(props: Dict[str, Any], asset_paths: List[str]) -> str:
    digest = hashlib.sha256(json.dumps(props, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
    paths = []
    for base in (os.path.join(REMOTION_DIR, "src"), PUBLIC_DIR):
        if not os.path.isdir(base):
            continue
        for root, directories, filenames in os.walk(base):
            directories.sort()
            for filename in sorted(filenames):
                paths.append(os.path.join(root, filename))
    for filename in ("package.json", "package-lock.json", "remotion.config.ts"):
        candidate = os.path.join(REMOTION_DIR, filename)
        if os.path.isfile(candidate):
            paths.append(candidate)
    paths.extend(asset_paths)
    # ponytail: size/mtime fingerprints avoid hashing multi-GiB source media on every retry;
    # hash bytes only if the app begins rewriting the same media path while preserving both.
    for path in sorted(set(os.path.realpath(item) for item in paths)):
        try:
            stat = os.stat(path)
        except OSError:
            digest.update(f"missing:{path}".encode("utf-8"))
            continue
        relative = os.path.relpath(path, REMOTION_DIR) if path.startswith(REMOTION_DIR + os.sep) else path
        digest.update(f"{relative}:{stat.st_size}:{stat.st_mtime_ns}".encode("utf-8"))
    return digest.hexdigest()


def _clear_render_checkpoints(directory: str, remove_directory: bool = True) -> None:
    for filename in os.listdir(directory):
        if filename == "state.json" or filename == "concat.txt" or re.fullmatch(r"state_[A-Za-z0-9_-]+", filename) or re.fullmatch(r"segment-\d{4}\.mp4", filename):
            path = os.path.join(directory, filename)
            if os.path.isfile(path) or os.path.islink(path):
                os.remove(path)
    if remove_directory:
        try:
            os.rmdir(directory)
        except OSError:
            pass


def _run_render_command(command: List[str], cancel_check=None, progress_callback=None, cwd: Optional[str] = None) -> None:
    process = subprocess.Popen(
        command, cwd=cwd or REMOTION_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1, start_new_session=True,
    )
    output_lines = queue.Queue()

    def read_output():
        if process and process.stdout:
            for output_line in process.stdout:
                output_lines.put(output_line)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    recent_output = []
    try:
        if cancel_check and cancel_check():
            _stop_render_process(process)
            raise RuntimeError("Render cancelado por el usuario")
        while process.poll() is None:
            if cancel_check and cancel_check():
                _stop_render_process(process)
                raise RuntimeError("Render cancelado por el usuario")
            try:
                line = output_lines.get(timeout=0.1)
            except queue.Empty:
                continue
            recent_output.append(line.rstrip())
            recent_output = recent_output[-30:]
            match = re.search(r"(?:rendering|rendered|progress|frame)\D{0,20}(\d{1,3})%", line, re.I)
            if match and progress_callback:
                progress_callback(min(99, int(match.group(1))))
            else:
                frame_match = re.search(r"Rendered\s+(\d+)\s*(?:of|/)\s*(\d+)", line, re.I)
                if frame_match and progress_callback and int(frame_match.group(2)):
                    progress_callback(min(99, int(int(frame_match.group(1)) * 100 / int(frame_match.group(2)))))
        reader.join(timeout=2)
        while not output_lines.empty():
            recent_output.append(output_lines.get().rstrip())
        if process.returncode != 0:
            raise RuntimeError("Error en subproceso de render: " + "\n".join(recent_output[-20:]))
    except Exception:
        _stop_render_process(process)
        raise


def _stop_render_process(process) -> None:
    """Terminate the Remotion process group and reap its parent, if still alive."""
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


def render_project(
    project_meta: Dict[str, Any],
    scenes: List[Dict[str, Any]],
    output_filename: str,
    fps: int = 30,
    progress_callback=None,
    cancel_check=None,
    checkpoint_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Renderiza localmente un proyecto Remotion; el máximo práctico depende del hardware.
    Cada escena aporta su audio real, palabras para subtítulos y elemento visual.
    """
    start_time = time.time()
    fps = _validate_fps(fps)

    final_mp4_path = _output_path(output_filename)
    render_mp4_path = os.path.join(OUTPUT_DIR, f".{os.path.basename(final_mp4_path)}.{os.urandom(8).hex()}.partial.mp4")

    for scene in scenes:
        if not scene.get("source_video_src"):
            continue
        source_ref = scene["source_video_src"]
        if not isinstance(source_ref, str) or not source_ref.startswith("/projects/"):
            raise ValueError("Referencia de video fuente inválida")
        source_path = os.path.realpath(os.path.join(PROJECTS_DIR, source_ref.removeprefix("/projects/")))
        projects_root = os.path.realpath(PROJECTS_DIR)
        if os.path.commonpath([projects_root, source_path]) != projects_root or not os.path.isfile(source_path):
            raise ValueError("Ruta del video fuente fuera del almacenamiento local del proyecto")
        start_seconds = float(scene.get("source_start_seconds", 0) or 0)
        if not (start_seconds >= 0 and start_seconds < float("inf")):
            raise ValueError("El inicio del clip debe ser un número finito no negativo")
    
    # 1. Preparar lista concatenada de palabras y audios por escena
    all_words = []
    scenes_props = []
    scenes_timing = []
    accumulated_seconds = 0.0
    accumulated_frames = 0
    media_public_dir = None
    copied_sources = {}

    def stage_local_asset(source_path: str) -> str:
        nonlocal media_public_dir
        real_path = os.path.realpath(source_path)
        projects_root = os.path.realpath(PROJECTS_DIR)
        if os.path.commonpath([projects_root, real_path]) != projects_root or not os.path.isfile(real_path):
            raise ValueError("Ruta de medio fuera del almacenamiento local del proyecto")
        if real_path not in copied_sources:
            if media_public_dir is None:
                media_public_dir = os.path.join(OUTPUT_DIR, ".media", f"{os.getpid()}_{time.time_ns()}")
                temp_public_dir = os.path.join(media_public_dir, "public")
                media_root = os.path.join(temp_public_dir, ".media")
                os.makedirs(media_root, exist_ok=True)
                try:
                    for entry in os.scandir(PUBLIC_DIR):
                        os.symlink(entry.path, os.path.join(temp_public_dir, entry.name), target_is_directory=entry.is_dir(follow_symlinks=True))
                except Exception:
                    shutil.rmtree(media_public_dir, ignore_errors=True)
                    media_public_dir = None
                    raise
            media_root = os.path.join(media_public_dir, "public", ".media")
            copied_path = os.path.join(media_root, f"asset_{len(copied_sources)}{os.path.splitext(real_path)[1]}")
            try:
                os.link(real_path, copied_path)
            except OSError:
                try:
                    shutil.copy2(real_path, copied_path)
                except OSError:
                    shutil.rmtree(media_public_dir, ignore_errors=True)
                    media_public_dir = None
                    raise
            copied_sources[real_path] = copied_path
        return f".media/{os.path.basename(copied_sources[real_path])}"
    props_path = None

    for s in scenes:
        dur = max(s.get("audio_duration", 0.0), 2.0)
        start_frame = accumulated_frames
        dur_frames = max(1, int(round(dur * fps)))

        # Desplazar los tiempos de las palabras para el karaoke global
        for w in s.get("words", []):
            all_words.append({
                "word": w["word"],
                "start": round(accumulated_seconds + w["start"], 3),
                "end": round(accumulated_seconds + w["end"], 3)
            })

        # Codificar audio de la escena en data URI
        audio_path = s.get("audio_path")
        audio_src = stage_local_asset(audio_path) if audio_path and os.path.exists(audio_path) else ""

        source_video_src = s.get("source_video_src")
        if source_video_src:
            source_relative = source_video_src.removeprefix("/projects/")
            source_path = os.path.realpath(os.path.join(PROJECTS_DIR, source_relative))
            projects_root = os.path.realpath(PROJECTS_DIR)
            source_video_src = stage_local_asset(source_path)

        manim_clip = s.get("manim_clip")
        if isinstance(manim_clip, str) and manim_clip.startswith("/projects/"):
            manim_path = os.path.realpath(os.path.join(PROJECTS_DIR, manim_clip.removeprefix("/projects/")))
            manim_clip = stage_local_asset(manim_path)

        scenes_props.append({
            "id": s["id"],
            "title": s["title"],
            "text": s["narrative_text"],
            "callout": s.get("callout", ""),
            "sticker": s.get("sticker", "question"),
            "sfx": s.get("sfx", "pop"),
            "bg_color": s.get("bg_color", "#FEF3C7"),
            "motion_type": s.get("motion_type", "sticker"),
            "manim_clip": manim_clip,
            "svg_markup": s.get("svg_markup", ""),
            "source_video_src": source_video_src,
            "source_start_seconds": max(0, float(s.get("source_start_seconds", 0) or 0)),
            "source_media_duration_seconds": s.get("source_media_duration_seconds"),
            "source_clip_duration_seconds": s.get("source_clip_duration_seconds"),
            "audio_src": audio_src,
            "audio_data_uri": "",
            "source_audio_enabled": bool(s.get("source_audio_enabled", False)),
            "start_frame": start_frame,
            "duration_in_frames": dur_frames
        })

        accumulated_seconds += dur
        accumulated_frames += dur_frames

    total_frames = max(1, accumulated_frames)

    props = {
        "scenes": scenes_props,
        "words": all_words,
        "durationInFrames": total_frames,
        "width": 1920 if project_meta.get("output_format") == "horizontal" else 1080,
        "height": 1080 if project_meta.get("output_format") == "horizontal" else 1920,
    }

    os.makedirs(os.path.join(OUTPUT_DIR, ".props"), exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", prefix="render_", dir=os.path.join(OUTPUT_DIR, ".props"), delete=False) as f:
        json.dump(props, f, ensure_ascii=False, indent=2)
        props_path = f.name

    public_dir = PUBLIC_DIR
    if media_public_dir:
        public_dir = os.path.join(media_public_dir, "public")

    cmd = [
        "npx", "remotion", "render",
        "src/index.ts",
        "DoodleReel",
        render_mp4_path,
        f"--props={props_path}",
        f"--public-dir={public_dir}",
        f"--concurrency={_render_concurrency()}",
        f"--fps={fps}",
        "--gl=angle",
    ]

    print(f"[RenderService] Renderizando proyecto ({total_frames} frames / {round(accumulated_seconds, 1)}s)...")
    checkpoint_dir = None
    checkpoint_fingerprint = None
    use_checkpoints = checkpoint_id is not None and total_frames > fps * RENDER_CHECKPOINT_CHUNK_SECONDS
    try:
        if not use_checkpoints:
            _run_render_command(cmd, cancel_check, progress_callback)
            if not os.path.isfile(render_mp4_path):
                raise RuntimeError("Remotion terminó sin crear el archivo de video esperado")
            _publish_validated_output(render_mp4_path, final_mp4_path, total_frames / fps, fps)
        else:
            if not re.fullmatch(r"render_[A-Za-z0-9_-]{1,100}", checkpoint_id):
                raise ValueError("ID de checkpoint inválido")
            if os.path.islink(CHECKPOINTS_DIR):
                raise ValueError("Directorio de checkpoints inválido")
            os.makedirs(CHECKPOINTS_DIR, mode=0o700, exist_ok=True)
            checkpoint_dir = os.path.join(CHECKPOINTS_DIR, checkpoint_id)
            if os.path.islink(checkpoint_dir):
                raise ValueError("Directorio de checkpoint inválido")
            os.makedirs(checkpoint_dir, mode=0o700, exist_ok=True)
            os.chmod(checkpoint_dir, 0o700)
            checkpoint_fingerprint = _render_fingerprint(props, list(copied_sources))
            state_path = os.path.join(checkpoint_dir, "state.json")
            try:
                with open(state_path, encoding="utf-8") as state_file:
                    previous_state = json.load(state_file)
            except (OSError, ValueError):
                previous_state = None
            chunk_frames = fps * RENDER_CHECKPOINT_CHUNK_SECONDS
            if (not isinstance(previous_state, dict) or previous_state.get("fingerprint") != checkpoint_fingerprint
                    or previous_state.get("total_frames") != total_frames or previous_state.get("fps") != fps
                    or previous_state.get("chunk_frames") != chunk_frames):
                _clear_render_checkpoints(checkpoint_dir, remove_directory=False)
                with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=checkpoint_dir, prefix="state_", delete=False) as state_file:
                    json.dump({"fingerprint": checkpoint_fingerprint, "total_frames": total_frames, "fps": fps,
                               "chunk_frames": chunk_frames}, state_file)
                    state_temp_path = state_file.name
                os.replace(state_temp_path, state_path)

            segment_paths = []
            for chunk_index, start_frame in enumerate(range(0, total_frames, chunk_frames)):
                end_frame = min(total_frames - 1, start_frame + chunk_frames - 1)
                frame_count = end_frame - start_frame + 1
                segment_path = os.path.join(checkpoint_dir, f"segment-{chunk_index:04d}.mp4")
                valid_segment = False
                if os.path.isfile(segment_path):
                    try:
                        _validate_rendered_video(segment_path, frame_count / fps, fps)
                        valid_segment = True
                    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError):
                        os.remove(segment_path)
                if not valid_segment:
                    segment_command = list(cmd)
                    segment_command[5] = segment_path
                    segment_command.append(f"--frames={start_frame}-{end_frame}")
                    if progress_callback:
                        chunk_progress = lambda pct, start=start_frame, count=frame_count: progress_callback(
                            min(99, int((start + count * pct / 100) * 100 / total_frames))
                        )
                    else:
                        chunk_progress = None
                    _run_render_command(segment_command, cancel_check, chunk_progress)
                    _validate_rendered_video(segment_path, frame_count / fps, fps)
                segment_paths.append(segment_path)
                if progress_callback:
                    progress_callback(min(99, int((end_frame + 1) * 100 / total_frames)))

            concat_path = os.path.join(checkpoint_dir, "concat.txt")
            with open(concat_path, "w", encoding="utf-8") as concat_file:
                for segment_path in segment_paths:
                    concat_file.write(f"file '{os.path.basename(segment_path)}'\n")
            concat_command = [
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "concat", "-safe", "1",
                "-i", concat_path, "-c", "copy", "-movflags", "+faststart", render_mp4_path,
            ]
            _run_render_command(concat_command, cancel_check, None, cwd=checkpoint_dir)
            if not os.path.isfile(render_mp4_path):
                raise RuntimeError("FFmpeg terminó sin crear el MP4 ensamblado")
            _publish_validated_output(render_mp4_path, final_mp4_path, total_frames / fps, fps)
            _clear_render_checkpoints(checkpoint_dir)
    except Exception:
        try:
            os.remove(render_mp4_path)
        except OSError:
            pass
        raise
    finally:
        try:
            os.remove(props_path)
        except OSError:
            pass
        if media_public_dir:
            shutil.rmtree(media_public_dir, ignore_errors=True)

    elapsed = round(time.time() - start_time, 2)
    file_size_mb = round(os.path.getsize(final_mp4_path) / (1024 * 1024), 2)

    return {
        "video_path": final_mp4_path,
        "video_url": f"/output/{output_filename}",
        "filename": output_filename,
        "duration_seconds": round(total_frames / fps, 2),
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
    fps = _validate_fps(fps)
    final_mp4_path = _output_path(output_filename)
    render_mp4_path = os.path.join(OUTPUT_DIR, f".{os.path.basename(final_mp4_path)}.{os.urandom(8).hex()}.partial.mp4")
    scenes = storyboard.get("scenes", [])
    total_audio_duration = audio_info.get("duration", 30.0)
    audio_path = audio_info.get("audio_path")
    words = audio_info.get("words", [])

    per_scene_dur = total_audio_duration / max(len(scenes), 1)

    scenes_props = []
    accumulated_seconds = 0.0
    accumulated_frames = 0
    for i, s in enumerate(scenes):
        dur = per_scene_dur
        start_frame = accumulated_frames
        dur_frames = max(1, int(round(dur * fps)))
        scenes_props.append({
            "id": s["id"],
            "title": s.get("title", f"Escena {i+1}"),
            "text": s.get("text", s.get("narrative_text", "")),
            "callout": s.get("callout", ""),
            "sticker": s.get("sticker", "question"),
            "sfx": s.get("sfx", "pop"),
            "bg_color": s.get("bg_color", "#FEF3C7"),
            "motion_type": s.get("motion_type", "sticker"),
            "rig_component": s.get("rig_component"),
            "svg_markup": s.get("svg_markup"),
            "manim_clip": s.get("manim_clip"),
            "audio_data_uri": "",
            "start_frame": start_frame,
            "duration_in_frames": dur_frames
        })
        accumulated_seconds += dur
        accumulated_frames += dur_frames

    total_frames = max(1, accumulated_frames)

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

    # Reuse the same isolated-props and cancellable subprocess path as the web
    # workflow. The renderer accepts this legacy continuous-audio prop shape.
    os.makedirs(os.path.join(OUTPUT_DIR, ".props"), exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".json", prefix="render_",
        dir=os.path.join(OUTPUT_DIR, ".props"), delete=False,
    ) as stream:
        json.dump(props, stream, ensure_ascii=False, indent=2)
        props_path = stream.name

    cmd = [
        "npx", "remotion", "render", "src/index.ts", "DoodleReel", render_mp4_path,
        f"--props={props_path}", "--public-dir=public", f"--concurrency={_render_concurrency()}",
        f"--fps={fps}", "--gl=angle",
    ]
    start_time = time.time()
    process = None
    try:
        process = subprocess.Popen(
            cmd, cwd=REMOTION_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1, start_new_session=True,
        )
        output_lines = queue.Queue()

        def read_output():
            if process and process.stdout:
                for output_line in process.stdout:
                    output_lines.put(output_line)

        reader = threading.Thread(target=read_output, daemon=True)
        reader.start()
        recent_output = []
        while process.poll() is None:
            try:
                line = output_lines.get(timeout=0.1)
            except queue.Empty:
                continue
            recent_output.append(line.rstrip())
            recent_output = recent_output[-30:]
        reader.join(timeout=2)
        while not output_lines.empty():
            recent_output.append(output_lines.get().rstrip())
        if process.returncode != 0:
            raise RuntimeError("Error renderizando video con Remotion: " + "\n".join(recent_output[-20:]))
        if not os.path.isfile(render_mp4_path):
            raise RuntimeError("Remotion terminó sin crear el archivo de video esperado")
        _publish_validated_output(render_mp4_path, final_mp4_path, total_frames / fps, fps)
    except Exception:
        _stop_render_process(process)
        try:
            os.remove(render_mp4_path)
        except OSError:
            pass
        raise
    finally:
        try:
            os.remove(props_path)
        except OSError:
            pass

    elapsed = round(time.time() - start_time, 2)
    file_size_mb = round(os.path.getsize(final_mp4_path) / (1024 * 1024), 2)
    return {
        "video_path": final_mp4_path,
        "video_url": f"/output/{output_filename}",
        "filename": output_filename,
        "duration_seconds": round(total_frames / fps, 2),
        "duration_frames": total_frames,
        "size_mb": file_size_mb,
        "render_time_seconds": elapsed
    }

