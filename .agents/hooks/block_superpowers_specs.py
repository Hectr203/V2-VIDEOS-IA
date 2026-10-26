#!/usr/bin/env python3
"""
Hook para bloquear permanentemente la creación de carpetas o archivos de specs de superpowers.
Todo plan o documento estructurado debe ser generado como artefacto en el directorio brain.
"""

import json
import os
import shutil
import sys
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

FORBIDDEN_KEYWORDS = [
    "superpowers",
    "docs/specs",
    "docs/superpowers",
    "superpowers/specs",
    "superpowers/plans",
]


def check_forbidden_path(target_path_str: str) -> tuple[bool, str]:
    if not target_path_str:
        return True, ""
    try:
        p = Path(target_path_str)
        if not p.is_absolute():
            p = (WORKSPACE_ROOT / p).resolve()
        else:
            p = p.resolve()
        
        rel_str = str(p.relative_to(WORKSPACE_ROOT))
    except Exception:
        rel_str = str(target_path_str)

    rel_str_lower = rel_str.lower().replace("\\", "/")

    for kw in FORBIDDEN_KEYWORDS:
        if kw in rel_str_lower:
            return (
                False,
                f"Bloqueado por Hook: No está permitido crear archivos o carpetas de superpowers/specs ({kw}) en el workspace. "
                f"Los planes y especificaciones deben guardarse como artefactos en el directorio brain.",
            )

    return True, ""


def handle_pre_tool_use(payload: dict) -> dict:
    tool_call = payload.get("toolCall", {})
    args = tool_call.get("args", {})

    # Validar TargetFile
    target_file = args.get("TargetFile") or args.get("target_file")
    if target_file:
        valido, motivo = check_forbidden_path(str(target_file))
        if not valido:
            return {"decision": "deny", "reason": motivo}

    # Validar CommandLine
    cmd = args.get("CommandLine") or args.get("command") or ""
    if cmd:
        for kw in FORBIDDEN_KEYWORDS:
            if kw in cmd.lower():
                # Si el comando es para borrar o buscar no bloquearlo
                if any(allowed in cmd.lower() for allowed in ["rm ", "git rm", "ls ", "find ", "grep "]):
                    continue
                return {
                    "decision": "deny",
                    "reason": f"Bloqueado por Hook: No se permite crear carpetas o archivos de superpowers ({kw}).",
                }

    return {"decision": "allow"}


def handle_post_tool_use(payload: dict) -> dict:
    # Si de alguna forma se creó docs/superpowers, eliminarla de inmediato
    sp_dir = WORKSPACE_ROOT / "docs" / "superpowers"
    if sp_dir.exists():
        shutil.rmtree(sp_dir, ignore_errors=True)
        print("[AVISO HOOK] Se eliminó automáticamente la carpeta docs/superpowers.", file=sys.stderr)
    return {}


def main():
    raw_input = sys.stdin.read().strip()
    payload = {}
    if raw_input:
        try:
            payload = json.loads(raw_input)
        except Exception:
            pass

    if "toolCall" in payload:
        response = handle_pre_tool_use(payload)
    else:
        response = handle_post_tool_use(payload)

    print(json.dumps(response))


if __name__ == "__main__":
    main()
