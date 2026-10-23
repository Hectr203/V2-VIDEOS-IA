import os
import json
import subprocess
from typing import Dict, Any, Optional

ASSEMBLER_DIR = "/mnt/nvme/V2-VIDEOS-IA/videoAssembler"

class VideoAssemblerBridge:
    """
    Puente de interoperabilidad con videoAssembler (/mnt/nvme/V2-VIDEOS-IA/videoAssembler).
    Traduce el proyecto de storyboard al esquema de manifiesto JSON nativo de videoAssembler
    y permite ejecutar su CLI de render con FFmpeg acelerado.
    """

    @classmethod
    def is_available(cls) -> bool:
        return os.path.exists(ASSEMBLER_DIR) and os.path.exists(os.path.join(ASSEMBLER_DIR, "cli/render.ts"))

    @classmethod
    def export_manifest(cls, project_meta: Dict[str, Any], scenes: list, output_manifest_path: str | None = None) -> Dict[str, Any]:
        """Exporta solo clips fuente reales; Remotion/SVG sigue siendo el render maestro."""
        clips = []
        for s in scenes:
            clip_file = s.get("source_video_src")
            if not clip_file:
                continue
            dur = float(s.get("source_media_duration_seconds") or s.get("source_clip_duration_seconds") or s.get("audio_duration") or 0)
            if dur <= 0:
                continue
            start = float(s.get("source_start_seconds") or 0)
            clips.append({
                "file": clip_file,
                "trimIn": start,
                "trimOut": float(s.get("source_start_seconds") or 0) + float(s.get("source_clip_duration_seconds") or dur),
                "speed": 1.0,
                "keepAudio": bool(s.get("source_audio_enabled")),
                "audioVolume": 1.0
            })
        if not clips:
            raise ValueError("Asigna al menos un clip fuente a una escena antes de abrir el montaje avanzado")
        if project_meta.get("assembler_manifest"):
            manifest = project_meta["assembler_manifest"]
            if output_manifest_path:
                os.makedirs(os.path.dirname(output_manifest_path), exist_ok=True)
                with open(output_manifest_path, "w", encoding="utf-8") as stream:
                    json.dump(manifest, stream, ensure_ascii=False, indent=2)
            return manifest

        manifest = {
            "name": project_meta.get("id", "video-export"),
            "clips": clips,
            "voice": None,
            "music": None,
            "outputs": [project_meta.get("output_format", "vertical")],
            "projectId": project_meta.get("id"),
        }

        if output_manifest_path:
            os.makedirs(os.path.dirname(output_manifest_path), exist_ok=True)
            with open(output_manifest_path, "w", encoding="utf-8") as f:
                json.dump(manifest, f, ensure_ascii=False, indent=2)
        return manifest

    @classmethod
    def run_cli_render(cls, manifest_path: str, media_dir: str, output_path: Optional[str] = None) -> Dict[str, Any]:
        """Ejecuta el renderizador nativo de videoAssembler vía node cli/render.ts."""
        if not cls.is_available():
            raise RuntimeError(f"videoAssembler no está disponible en {ASSEMBLER_DIR}")

        cmd = ["npx", "tsx", "cli/render.ts", manifest_path, "--base", media_dir]
        if output_path:
            cmd.extend(["--out", output_path])

        res = subprocess.run(cmd, cwd=ASSEMBLER_DIR, capture_output=True, text=True)
        return {
            "success": res.returncode == 0,
            "stdout": res.stdout,
            "stderr": res.stderr
        }
