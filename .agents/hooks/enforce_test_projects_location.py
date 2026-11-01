#!/usr/bin/env python3
"""
Hook para garantizar que todos los proyectos de prueba, tests de personajes,
experimentos de skills y prototipos se ubiquen obligatoriamente dentro de:
video-studio/proyectos-test/<slug>/
y NUNCA dispersos en la raíz de video-studio/ ni dentro de video-studio/projects/.
"""

import json
import os
import re
import sys
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
PROYECTOS_TEST_DIR = WORKSPACE_ROOT / "video-studio" / "proyectos-test"
PROJECTS_DIR = WORKSPACE_ROOT / "video-studio" / "projects"

# Patrones que denotan proyectos de prueba o experimentales
TEST_PATTERNS = [
    r"proyectos?[_-]test",
    r"test[_-]proyecto",
    r"prueba[_-]",
    r"[_-]test$",
    r"[_-]prueba$",
]

def validar_ruta_test(target_path_str: str) -> tuple[bool, str]:
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

    rel_norm = rel_str.lower().replace("\\", "/")

    # Si está dentro de video-studio/proyectos-test, es válido y permitido
    if "video-studio/proyectos-test" in rel_norm:
        return True, ""

    # Si se intenta crear un archivo o carpeta de test directamente en video-studio/projects/ o video-studio/
    # (por ejemplo video-studio/test-*, video-studio/projects/test-*, etc.)
    for pattern in TEST_PATTERNS:
        if re.search(pattern, rel_norm):
            return (
                False,
                f"Bloqueado por Hook: Los proyectos de prueba, experimentos y personajes de test "
                f"deben crearse obligatoriamente dentro de 'video-studio/proyectos-test/<nombre-test>/' "
                f"y nunca en '{rel_norm}'.",
            )

    return True, ""


def handle_pre_tool_use(payload: dict) -> dict:
    tool_call = payload.get("toolCall", {})
    args = tool_call.get("args", {})

    target_file = args.get("TargetFile") or args.get("target_file")
    if target_file:
        valido, motivo = validar_ruta_test(str(target_file))
        if not valido:
            return {"decision": "deny", "reason": motivo}

    cmd = args.get("CommandLine") or args.get("command") or ""
    if cmd:
        # Si el comando crea directorios o archivos de test fuera de proyectos-test
        if "mkdir " in cmd or "touch " in cmd or "cp " in cmd:
            for token in cmd.split():
                clean_tok = token.strip("\"'")
                if any(k in clean_tok.lower() for k in ["test", "prueba"]):
                    valido, motivo = validar_ruta_test(clean_tok)
                    if not valido:
                        return {"decision": "deny", "reason": motivo}

    return {"decision": "allow"}


def handle_post_tool_use(payload: dict) -> dict:
    # Asegurar que video-studio/proyectos-test siempre exista
    if not PROYECTOS_TEST_DIR.exists():
        PROYECTOS_TEST_DIR.mkdir(parents=True, exist_ok=True)
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
