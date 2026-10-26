#!/usr/bin/env python3
"""
Herramienta de búsqueda e integración de audios para V2-VIDEOS-IA.
Permite a los agentes de IA y creadores consultar, filtrar y copiar pistas de música
y efectos de sonido (SFX) desde la biblioteca central de assets.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUDIO = HERE.parent
ASSETS = STUDIO / "assets"
CATALOGO_FILE = ASSETS / "catalogo_audios.json"


def cargar_catalogo():
    if not CATALOGO_FILE.exists():
        print(f"Error: No existe el catálogo en {CATALOGO_FILE}", file=sys.stderr)
        sys.exit(1)
    with open(CATALOGO_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def listar_categorias(catalogo):
    print("\n📂 CATEGORÍAS DISPONIBLES EN LA BIBLIOTECA:")
    print("=" * 65)
    categorias = catalogo.get("resumen_categorias", {})
    for cat, info in sorted(categorias.items()):
        tipo_badge = f"[{info['tipo'].upper()}]"
        print(f"{tipo_badge:<12} {cat:<35} -> {info['total_pistas']:>3} pistas ({info['duracion_total']:>7.1f}s)")
    print("=" * 65)
    print(f"Total audios catalogados: {catalogo.get('total_audios', 0)}")


def buscar(args):
    catalogo = cargar_catalogo()

    if args.listar_categorias:
        listar_categorias(catalogo)
        return

    items = catalogo.get("indice_completo", [])
    query = (args.buscar or "").lower()
    categoria = (args.categoria or "").lower()
    tipo = (args.tipo or "").lower()

    resultados = []
    for item in items:
        if tipo and item["tipo"] != tipo:
            continue
        if categoria and categoria not in item["categoria"].lower():
            continue
        if args.max_duracion and item["duracion_segundos"] > args.max_duracion:
            continue
        if args.min_duracion and item["duracion_segundos"] < args.min_duracion:
            continue

        if query:
            match = (
                query in item["nombre"].lower()
                or query in item["file"].lower()
                or query in item["descripcion"].lower()
                or any(query in tag.lower() for tag in item.get("tags", []))
            )
            if not match:
                continue

        resultados.append(item)

    if args.json:
        print(json.dumps(resultados, indent=2, ensure_ascii=False))
        return

    print(f"\n🔍 RESULTADOS ENCONTRADOS: {len(resultados)}")
    print("=" * 80)
    for r in resultados[: args.limite]:
        tipo_str = f"[{r['tipo'].upper()}]"
        dur_str = f"{r['duracion_segundos']:>5.1f}s"
        vol_str = f"vol: {r['volumen_sugerido']:.2f}"
        print(f"{tipo_str:<10} {dur_str} | {vol_str} | {r['nombre']}")
        print(f"  Ruta: {r['file']}")
        print(f"  Tags: {', '.join(r.get('tags', [])[:5])}")
        print("-" * 80)

    if len(resultados) > args.limite:
        print(f"... y {len(resultados) - args.limite} resultados más. Usa --limite para ver más.")

    # Opción de copiar archivo si se especificó destino
    if args.copiar_a and resultados:
        dest_dir = Path(args.copiar_a)
        dest_dir.mkdir(parents=True, exist_ok=True)
        primer_audio = resultados[0]
        src_path = ASSETS / primer_audio["file"]
        dest_name = args.nombre_destino or Path(primer_audio["file"]).name
        dest_file = dest_dir / dest_name
        shutil.copy2(src_path, dest_file)
        print(f"\n✅ Audio copiado a: {dest_file}")


def main():
    parser = argparse.ArgumentParser(description="Buscador de audios para V2-VIDEOS-IA")
    parser.add_argument("-b", "--buscar", help="Término de búsqueda (título, tag o descripción)")
    parser.add_argument("-c", "--categoria", help="Filtrar por categoría (ej. videojuegos, terror, sfx)")
    parser.add_argument("-t", "--tipo", choices=["musica", "sfx", "ambiente"], help="Filtrar por tipo")
    parser.add_argument("--max-duracion", type=float, help="Duración máxima en segundos")
    parser.add_argument("--min-duracion", type=float, help="Duración mínima en segundos")
    parser.add_argument("-l", "--listar-categorias", action="store_true", help="Listar todas las categorías")
    parser.add_argument("--limite", type=int, default=15, help="Límite de resultados a mostrar (default: 15)")
    parser.add_argument("--json", action="store_true", help="Salida en formato JSON")
    parser.add_argument("--copiar-a", help="Ruta de carpeta destino donde copiar el primer resultado")
    parser.add_argument("--nombre-destino", help="Nombre nuevo para el archivo copiado")

    args = parser.parse_args()
    buscar(args)


if __name__ == "__main__":
    main()
