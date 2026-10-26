#!/usr/bin/env python3
"""
Validador de estructura para video-studio/projects.

Garantiza que:
1. NINGÚN proyecto, archivo de video (.mp4, .mov, etc.) o enlace simbólico se guarde
   en la raíz de 'video-studio/projects/'.
2. Todo proyecto resida estrictamente dentro de su carpeta fechada de creación:
   'video-studio/projects/<DD de mes de YYYY>/<slug>/'
3. La raíz de projects/ solo contenga carpetas de fecha válidas y metadatos del sistema.
"""

import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECTS_DIR = HERE.parent / "projects"

# Excepciones administrativas permitidas en la raíz de projects/
PERMITTED_ROOT_FILES = {
    ".gitkeep",
    ".gitignore",
    "tsconfig.json",
    "render_jobs",
    ".DS_Store",
}

# Patrón para validar carpetas con formato: "25 de octubre de 2026"
FECHA_DIR_PATTERN = re.compile(
    r"^\d{1,2} de (?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre) de \d{4}$",
    re.IGNORECASE,
)

SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def validar_estructura(auto_reparar: bool = False) -> bool:
    if not PROJECTS_DIR.exists():
        print(f"[ERROR] El directorio {PROJECTS_DIR} no existe.", file=sys.stderr)
        return False

    errores = []
    elementos_raiz = list(PROJECTS_DIR.iterdir())

    for item in elementos_raiz:
        nombre = item.name

        # Permitir archivos y carpetas del sistema
        if nombre in PERMITTED_ROOT_FILES:
            continue

        # Prohibir cualquier enlace simbólico en la raíz de projects/
        if item.is_symlink():
            errores.append(
                f"Enlace simbólico no permitido en la raíz de projects: '{nombre}' -> '{os.readlink(item)}'. "
                f"Elimínelo. Los proyectos deben residir únicamente en su carpeta fechada."
            )
            if auto_reparar:
                item.unlink()
                print(f"[REPARADO] Enlace simbólico eliminado: {nombre}")
            continue

        # Prohibir archivos sueltos (videos, scripts, json, etc.) en la raíz
        if item.is_file():
            errores.append(
                f"Archivo no permitido en la raíz de projects: '{nombre}'. "
                f"Todo archivo debe pertenecer a una producción dentro de una carpeta de fecha."
            )
            continue

        # Es un directorio: DEBE ser una carpeta de fecha válida
        if not FECHA_DIR_PATTERN.match(nombre):
            errores.append(
                f"Directorio en la raíz no cumple el formato de fecha: '{nombre}'. "
                f"Formato requerido: '<DD de mes de YYYY>' (ej. '25 de octubre de 2026'). "
                f"Si es un proyecto, muévalo dentro de una carpeta de fecha."
            )
            continue

        # Validar los proyectos dentro de la carpeta fechada
        for subitem in item.iterdir():
            if subitem.name in PERMITTED_ROOT_FILES:
                continue

            if subitem.is_symlink():
                errores.append(
                    f"Enlace simbólico en '{nombre}/{subitem.name}'. Use carpetas reales."
                )
                continue

            if subitem.is_file():
                errores.append(
                    f"Archivo suelto en '{nombre}/{subitem.name}'. Solo se permiten carpetas de proyecto."
                )
                continue

            if not SLUG_PATTERN.match(subitem.name):
                errores.append(
                    f"Slug de proyecto inválido: '{nombre}/{subitem.name}'. Use minúsculas y guiones."
                )

    if errores:
        print("\n" + "=" * 70, file=sys.stderr)
        print("❌ FALLO DE VALIDACIÓN DE ESTRUCTURA EN video-studio/projects/", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        for err in errores:
            print(f"  • {err}", file=sys.stderr)
        print("=" * 70 + "\n", file=sys.stderr)
        return False

    print(
        f"[OK] Estructura válida en {PROJECTS_DIR.name}/: "
        f"Todos los proyectos están organizados cronológicamente por fecha de creación."
    )
    return True


if __name__ == "__main__":
    reparar = "--fix" in sys.argv
    exito = validar_estructura(auto_reparar=reparar)
    sys.exit(0 if exito else 1)
