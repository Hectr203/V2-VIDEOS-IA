#!/usr/bin/env python3
"""
Hook de validación estricta de estructura y fechas para video-studio/projects.
Se ejecuta en los puntos de control del ciclo de vida del agente (PreToolUse y PostToolUse).
"""

import json
import os
import re
import sys
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
PROJECTS_DIR = WORKSPACE_ROOT / "video-studio" / "projects"

PERMITTED_ROOT_FILES = {
    ".gitkeep",
    ".gitignore",
    "tsconfig.json",
    "render_jobs",
    ".DS_Store",
}

FECHA_PATTERN = re.compile(
    r"^\d{1,2} de (?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre) de \d{4}$",
    re.IGNORECASE,
)


def inspeccionar_path(target_path_str: str) -> tuple[bool, str]:
    """Verifica si un path intenta escribir o crear algo ilegal en video-studio/projects/."""
    try:
        p = Path(target_path_str)
        # Normalizar si es relativo al workspace
        if not p.is_absolute():
            p = (WORKSPACE_ROOT / p).resolve()
        else:
            p = p.resolve()
    except Exception:
        return True, ""

    # Si no toca video-studio/projects, permitir
    try:
        rel = p.relative_to(PROJECTS_DIR)
    except ValueError:
        return True, ""

    parts = rel.parts
    if not parts:
        return True, ""

    primer_segmento = parts[0]

    # Archivos/carpetas permitidas en la raíz
    if primer_segmento in PERMITTED_ROOT_FILES:
        return True, ""

    # El primer segmento DEBE ser una fecha válida
    if not FECHA_PATTERN.match(primer_segmento):
        return (
            False,
            f"Intento de acceso o escritura en la raíz de projects no permitido: '{primer_segmento}'. "
            f"Todo proyecto debe guardarse forzosamente dentro de su carpeta de fecha "
            f"('video-studio/projects/<DD de mes de YYYY>/<slug>/').",
        )

    return True, ""


def handle_pre_tool_use(payload: dict) -> dict:
    tool_call = payload.get("toolCall", {})
    tool_name = tool_call.get("name", "")
    args = tool_call.get("args", {})

    # 1. Validar write_to_file / replace_file_content / multi_replace_file_content
    target_file = args.get("TargetFile") or args.get("target_file")
    if target_file:
        valido, motivo = inspeccionar_path(str(target_file))
        if not valido:
            return {"decision": "deny", "reason": motivo}

    # 2. Validar run_command
    command_line = args.get("CommandLine") or args.get("command") or ""
    if command_line and "video-studio/projects" in command_line:
        # Detectar comandos peligrosos que intenten crear enlaces o carpetas en la raíz
        # Ejemplos: ln -s ... video-studio/projects/<slug>
        #           mkdir video-studio/projects/<slug>
        for token in command_line.split():
            clean_token = token.strip("\"'")
            if "video-studio/projects/" in clean_token:
                valido, motivo = inspeccionar_path(clean_token)
                if not valido:
                    return {"decision": "deny", "reason": motivo}

    return {"decision": "allow"}


def handle_post_tool_use(payload: dict) -> dict:
    # Tras ejecutar una herramienta, verificar que no existan elementos ilegales en projects/
    if PROJECTS_DIR.exists():
        for item in PROJECTS_DIR.iterdir():
            nombre = item.name
            if nombre in PERMITTED_ROOT_FILES:
                continue
            if item.is_symlink() or item.is_file() or not FECHA_PATTERN.match(nombre):
                # Eliminar enlaces simbólicos rebeldes para mantener el workspace limpio
                if item.is_symlink():
                    item.unlink()
                print(
                    f"[AVISO HOOK] Se detectó y corrigió un elemento no permitido en projects/: {nombre}",
                    file=sys.stderr,
                )
    return {}


def main():
    raw_input = sys.stdin.read().strip()
    payload = {}
    if raw_input:
        try:
            payload = json.loads(raw_input)
        except Exception:
            pass

    # Si tiene toolCall, es PreToolUse
    if "toolCall" in payload:
        response = handle_pre_tool_use(payload)
    else:
        # Es PostToolUse u otro evento
        response = handle_post_tool_use(payload)

    print(json.dumps(response))


if __name__ == "__main__":
    main()
