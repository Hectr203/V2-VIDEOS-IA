import os
import json
import subprocess
from typing import Dict, Any

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
    def export_manifest(cls, project_meta: Dict[str, Any], scenes: list, output_manifest_path: str) -> str:
        """Genera un manifiesto.json 100% compatible con la especificación de videoAssembler."""
        clips = []
        for s in scenes:
            clip_file = s.get("visual_asset_url") or s.get("video_file") or "scene_placeholder.mp4"
            dur = max(s.get("audio_duration", 5.0), 3.0)
            clips.append({
                "file": clip_file,
                "trimIn": 0.0,
                "trimOut": dur,
                "speed": 1.0,
                "keepAudio": False,
                "audioVolume": 1.0
            })

        voice_file = scenes[0].get("audio_path") if scenes and scenes[0].get("audio_path") else "voice.mp3"

        manifest = {
            "name": project_meta.get("id", "video-export"),
            "clips": clips if clips else [{"file": "sample.mp4", "trimIn": 0, "trimOut": 10}],
            "voice": {
                "file": voice_file,
                "trimIn": 0,
                "trimOut": None,
                "volume": 1.0
            },
            "music": {
                "file": "ambient_curiosity.mp3",
                "trimIn": 0,
                "trimOut": None,
                "volume": 0.15
            },
            "outputs": ["vertical"]
        }

        os.makedirs(os.path.dirname(output_manifest_path), exist_ok=True)
        with open(output_manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)

        return output_manifest_path

    @classmethod
    def run_cli_render(cls, manifest_path: str, media_dir: str, output_path: str = None) -> Dict[str, Any]:
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
