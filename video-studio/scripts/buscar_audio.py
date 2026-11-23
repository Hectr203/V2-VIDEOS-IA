#!/usr/bin/env python3
"""
Buscador e curador inteligente de audio anti-repetición basado en historias para V2-VIDEOS-IA.

Características:
- Búsqueda clásica por palabra clave, categoría, tipo y duración.
- Curación narrativa por historia (--historia "<sinopsis/tono>") con anti-repetición automática
  respaldada por video-studio/assets/audio_usage_history.json.
- Generación de paquetes ricos y variados de SFX calibrados para entretener sin tapar la voz.
- Sincronización automática del historial real de pistas usadas en video-studio/projects/ (--sync-historial).
"""

import argparse
import datetime
import json
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUDIO = HERE.parent
ASSETS = STUDIO / "assets"
PROJECTS = STUDIO / "projects"
CATALOGO_FILE = ASSETS / "catalogo_audios.json"
HISTORIAL_FILE = ASSETS / "audio_usage_history.json"

PERFILES_HISTORIA = {
    "drama_crudo": {
        "keywords": ["drama", "crudo", "triste", "dolor", "lluvia", "soledad", "oscuro", "tragedia", "melancol", "libro", "abandono", "reflex", "emotiv", "nostalg"],
        "music_cats": ["dramatico_terror_tension", "dramatico_serio_tension", "naturaleza_lluvia_calma", "videojuegos_soundtracks"],
        "music_boost": ["piano", "forgotten", "drama", "river", "moon", "lluvia", "triste", "rain", "sad", "theme", "emotional", "hollow", "zelda", "ambient"],
        "sfx_cats": ["stingers_terror_suspense", "transiciones_camara_swish", "sound_effects_populares"],
        "sfx_boost": ["drama", "suspenso", "boom", "whoosh", "swish", "rain", "lluvia", "trueno", "heartbeat", "clock", "reverb", "reveal"],
    },
    "ciencia_curiosidad": {
        "keywords": ["ciencia", "física", "química", "espacio", "cerebro", "volcán", "espejo", "curiosidad", "datos", "experimento", "tecnología", "futuro", "planeta", "naturaleza", "biología", "cuerpo"],
        "music_cats": ["ciencia_tecnologia_curiosidad", "fondo_versatil", "corporativo_negocios_productividad", "viajes_vlog_verano", "videojuegos_soundtracks"],
        "music_boost": ["curios", "moderna", "educat", "fresh", "lights", "glitch", "galaxy", "wake", "energet", "chill", "lofi", "synth", "space", "world"],
        "sfx_cats": ["transiciones_camara_swish", "expresiones_celebraciones_asombro", "sound_effects_populares", "extras_cartoon_armas_dinero"],
        "sfx_boost": ["pop", "ding", "whoosh", "swish", "boing", "ricochet", "wow", "harp", "glitch", "click", "shutter", "bubble", "spark", "clock"],
    },
    "comedia_humor": {
        "keywords": ["humor", "comedia", "cómico", "gracioso", "meme", "parodia", "divertido", "absurdo", "loco", "granja", "fisiculturista", "animales", "gatos", "perros", "viral"],
        "music_cats": ["fondo_versatil", "viajes_vlog_verano", "videojuegos_soundtracks", "corporativo_negocios_productividad"],
        "music_boost": ["alegre", "happy", "vibes", "summer", "fresh", "mario", "overworld", "tropical", "funk", "groove", "adventure", "life", "day"],
        "sfx_cats": ["extras_cartoon_armas_dinero", "fails_errores_comicos", "sound_effects_populares", "expresiones_celebraciones_asombro", "transiciones_camara_swish"],
        "sfx_boost": ["boing", "ricochet", "pop", "cartoon", "bonk", "bamboo", "cork", "whistle", "duck", "bruh", "nope", "ding", "wow", "swipe", "deslizar"],
    },
    "aventura_historia": {
        "keywords": ["historia", "guerra", "imperio", "viaje", "épico", "aventura", "antiguo", "leyenda", "origen", "descubrimiento", "misterio", "secreto", "enigma", "crimen"],
        "music_cats": ["videojuegos_soundtracks", "dramatico_serio_tension", "ciencia_tecnologia_curiosidad", "viajes_vlog_verano", "dramatico_terror_tension"],
        "music_boost": ["aventura", "adventure", "cinematog", "moderna", "epico", "epic", "theme", "zelda", "skyrim", "witcher", "legend", "mystery", "forgotten"],
        "sfx_cats": ["transiciones_camara_swish", "stingers_terror_suspense", "golpes_caidas_impactos", "expresiones_celebraciones_asombro"],
        "sfx_boost": ["whoosh", "swish", "boom", "drama", "suspenso", "espada", "reveal", "ding", "harp", "flashback", "click"],
    },
    "negocios_tech": {
        "keywords": ["negocio", "empresa", "dinero", "finanzas", "ahorro", "app", "software", "ia", "inteligencia artificial", "productividad", "marketing", "startup", "marca"],
        "music_cats": ["corporativo_negocios_productividad", "fondo_versatil", "ciencia_tecnologia_curiosidad"],
        "music_boost": ["corporat", "motivad", "emprend", "moderna", "fresh", "lights", "chill", "lofi", "ambient", "tech"],
        "sfx_cats": ["transiciones_camara_swish", "sound_effects_populares", "extras_cartoon_armas_dinero", "expresiones_celebraciones_asombro"],
        "sfx_boost": ["click", "pop", "whoosh", "swish", "ding", "cash", "dinero", "teclado", "typing", "notification", "glitch"],
    },
}


def cargar_catalogo():
    if not CATALOGO_FILE.exists():
        print(f"Error: No existe el catálogo en {CATALOGO_FILE}", file=sys.stderr)
        sys.exit(1)
    with open(CATALOGO_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def cargar_historial() -> dict:
    if HISTORIAL_FILE.exists():
        try:
            return json.loads(HISTORIAL_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"updated_at": "", "usos_por_pista": {}, "recientes": []}


def guardar_historial(data: dict):
    data["updated_at"] = datetime.datetime.now().isoformat(timespec="seconds")
    HISTORIAL_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sincronizar_historial() -> dict:
    usos = Counter()
    recientes = []
    if PROJECTS.exists():
        scripts = sorted(PROJECTS.glob("*/*/prepare.py"), key=lambda p: p.stat().st_mtime, reverse=True)
        for p in scripts:
            proj_slug = p.parent.name
            txt = p.read_text(encoding="utf-8", errors="ignore")
            encontradas = re.findall(r"music/[^\'\"]+\.(?:mp3|wav)", txt)
            for track in dict.fromkeys(encontradas):
                usos[track] += 1
                recientes.append({"proyecto": proj_slug, "file": track})
    hist = {
        "updated_at": datetime.datetime.now().isoformat(timespec="seconds"),
        "usos_por_pista": dict(usos.most_common()),
        "recientes": recientes[:40],
    }
    guardar_historial(hist)
    return hist


def registrar_uso(file_rel: str, proyecto: str):
    hist = cargar_historial()
    usos = hist.get("usos_por_pista", {})
    usos[file_rel] = int(usos.get(file_rel, 0)) + 1
    hist["usos_por_pista"] = usos
    rec = [r for r in hist.get("recientes", []) if not (r.get("proyecto") == proyecto and r.get("file") == file_rel)]
    rec.insert(0, {"proyecto": proyecto, "file": file_rel, "fecha": datetime.date.today().isoformat()})
    hist["recientes"] = rec[:50]
    guardar_historial(hist)
    print(f"✅ Uso registrado: {file_rel} -> proyecto '{proyecto}' (total usos: {usos[file_rel]})")


def detectar_perfiles(texto_historia: str) -> list[str]:
    tl = texto_historia.lower()
    puntuados = []
    for nombre, cfg in PERFILES_HISTORIA.items():
        hits = sum(1 for kw in cfg["keywords"] if re.search(r"(?<![a-záéíóúñü])" + re.escape(kw), tl))
        if hits > 0:
            puntuados.append((hits, nombre))
    puntuados.sort(reverse=True)
    if not puntuados:
        return ["ciencia_curiosidad", "comedia_humor"]
    return [name for _, name in puntuados[:2]]


def curar_por_historia(args):
    catalogo = cargar_catalogo()
    hist = cargar_historial()
    if not hist.get("usos_por_pista"):
        hist = sincronizar_historial()

    usos = hist.get("usos_por_pista", {})
    recientes_top = {r["file"] for r in hist.get("recientes", [])[:12]}
    perfiles = detectar_perfiles(args.historia)
    tokens = [w for w in re.findall(r"[a-zA-Záéíóúñü]{3,}", args.historia.lower())]

    music_cats, music_boost, sfx_cats, sfx_boost = set(), set(), set(), set()
    for p in perfiles:
        cfg = PERFILES_HISTORIA[p]
        music_cats.update(cfg["music_cats"])
        music_boost.update(cfg["music_boost"])
        sfx_cats.update(cfg["sfx_cats"])
        sfx_boost.update(cfg["sfx_boost"])

    musicas, ambientes, sfxs = [], [], []
    for item in catalogo.get("indice_completo", []):
        f_rel = item["file"]
        haystack = (item["nombre"] + " " + f_rel + " " + item["descripcion"] + " " + " ".join(item.get("tags", []))).lower()
        n_usos = int(usos.get(f_rel, 0))
        es_reciente = f_rel in recientes_top

        if item["tipo"] == "musica":
            if item["duracion_segundos"] < 45:
                continue
            score = 0.0
            if item["categoria"] in music_cats:
                score += 24
            score += sum(8 for b in music_boost if b in haystack)
            score += sum(6 for t in tokens if t in haystack)
            # Fuerte penalización anti-repetición para rotar los 160+ temas de la biblioteca
            if n_usos == 0:
                score += 18  # Bono pista fresca nunca usada
            else:
                score -= n_usos * 16
            if es_reciente:
                score -= 22
            if args.evitar_recientes and (n_usos >= 2 or es_reciente):
                continue
            musicas.append((score, n_usos, item))
        elif item["tipo"] == "ambiente":
            score = sum(10 for t in tokens if t in haystack) + sum(6 for b in music_boost if b in haystack)
            if score > 0:
                ambientes.append((score, n_usos, item))
        elif item["tipo"] == "sfx":
            if item["duracion_segundos"] > 9.0:
                continue
            score = 0.0
            if item["categoria"] in sfx_cats:
                score += 14
            score += sum(9 for b in sfx_boost if b in haystack)
            score += sum(5 for t in tokens if t in haystack)
            if item["duracion_segundos"] <= 2.6:
                score += 6  # Preferir SFX ágiles y nítidos que no tapen la voz
            if score >= 14:
                sfxs.append((score, n_usos, item))

    musicas.sort(key=lambda x: (-x[0], x[1], x[2]["nombre"]))
    ambientes.sort(key=lambda x: (-x[0], x[2]["nombre"]))
    sfxs.sort(key=lambda x: (-x[0], x[2]["duracion_segundos"]))

    # Diversificar categorías de música y SFX para máxima riqueza
    mus_pick, seen_cat_m = [], Counter()
    for sc, n_u, it in musicas:
        if seen_cat_m[it["categoria"]] >= 3:
            continue
        seen_cat_m[it["categoria"]] += 1
        mus_pick.append({"score": round(sc, 1), "usos_previos": n_u, "file": it["file"], "nombre": it["nombre"], "categoria": it["categoria"], "duracion": it["duracion_segundos"]})
        if len(mus_pick) >= 8:
            break

    sfx_pick, seen_cat_s = [], Counter()
    for sc, n_u, it in sfxs:
        if seen_cat_s[it["categoria"]] >= 4:
            continue
        seen_cat_s[it["categoria"]] += 1
        sfx_pick.append({
            "score": round(sc, 1),
            "file": it["file"],
            "nombre": it["nombre"],
            "categoria": it["categoria"],
            "duracion": it["duracion_segundos"],
            "vol_remotion_sugerido": 0.18 if it["categoria"] == "transiciones_camara_swish" else 0.24,
        })
        if len(sfx_pick) >= 14:
            break

    payload = {
        "historia": args.historia,
        "perfiles_detectados": perfiles,
        "anti_repeticion_activo": True,
        "musica_recomendada_fresca": mus_pick,
        "ambientes_opcionales": [{"file": it["file"], "nombre": it["nombre"], "duracion": it["duracion_segundos"]} for _, _, it in ambientes[:4]],
        "pack_sfx_enriquecido": sfx_pick,
        "guia_mezcla": {
            "musica_normalizada_lufs": "-21 a -22 LUFS (auto-ducking 0.19-0.21 en voz, 0.34 en pausas/cierre)",
            "sfx_normalizados": "loudnorm=I=-22:TP=-6, alimiter=limit=0.45; volumen Remotion 0.16-0.30 (nunca tapa la voz)",
            "densidad_sfx_objetivo": "12 a 20 micro-SFX por minuto (transiciones, apariciones de texto/datos, gestos de personajes, giros y cierres)",
        },
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return

    print("\n" + "=" * 84)
    print(f"🎵 CURACIÓN ANTI-REPETICIÓN POR HISTORIA | Perfiles: {', '.join(perfiles)}")
    print("=" * 84)
    print("\n🎼 MÚSICA FRESCA RECOMENDADA (priorizando pistas NO repetidas):")
    for i, m in enumerate(mus_pick, 1):
        badge = "✨ NUEVA" if m["usos_previos"] == 0 else f"usada {m['usos_previos']}x"
        print(f"  {i}. [{badge}] ({m['duracion']:.0f}s · {m['categoria']}) {m['nombre']}")
        print(f"     Ruta: {m['file']}")
    if payload["ambientes_opcionales"]:
        print("\n🌧️ AMBIENTES OPCIONALES:")
        for a in payload["ambientes_opcionales"]:
            print(f"  • ({a['duracion']:.0f}s) {a['nombre']} -> {a['file']}")
    print("\n✨ PACK ENRIQUECIDO DE SFX (usar 12–20 golpes/min sin tapar la locución):")
    for s in sfx_pick:
        print(f"  • [{s['categoria']}] {s['duracion']:.2f}s | vol:{s['vol_remotion_sugerido']} | {s['nombre']}")
        print(f"    Ruta: {s['file']}")
    print("=" * 84 + "\n")


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
    if args.sync_historial:
        h = sincronizar_historial()
        print(f"✅ Historial sincronizado en {HISTORIAL_FILE}: {len(h['usos_por_pista'])} pistas registradas.")
        if not args.historia and not args.buscar and not args.listar_categorias:
            return

    if args.registrar_uso:
        registrar_uso(args.registrar_uso, args.proyecto or "produccion")
        return

    if args.historia:
        curar_por_historia(args)
        return

    catalogo = cargar_catalogo()
    if args.listar_categorias:
        listar_categorias(catalogo)
        return

    hist = cargar_historial()
    usos = hist.get("usos_por_pista", {})
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
        if args.evitar_recientes and int(usos.get(item["file"], 0)) >= 2:
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

    # Priorizar pistas menos usadas para combatir la repetición
    resultados.sort(key=lambda r: (int(usos.get(r["file"], 0)), r["nombre"]))

    if args.json:
        print(json.dumps(resultados, indent=2, ensure_ascii=False))
        return

    print(f"\n🔍 RESULTADOS ENCONTRADOS: {len(resultados)}")
    print("=" * 80)
    for r in resultados[: args.limite]:
        tipo_str = f"[{r['tipo'].upper()}]"
        dur_str = f"{r['duracion_segundos']:>5.1f}s"
        vol_str = f"vol: {r['volumen_sugerido']:.2f}"
        usos_n = int(usos.get(r["file"], 0))
        uso_str = "NUEVA" if usos_n == 0 else f"usada {usos_n}x"
        print(f"{tipo_str:<10} {dur_str} | {vol_str} | {uso_str:<8} | {r['nombre']}")
        print(f"  Ruta: {r['file']}")
        print(f"  Tags: {', '.join(r.get('tags', [])[:5])}")
        print("-" * 80)

    if len(resultados) > args.limite:
        print(f"... y {len(resultados) - args.limite} resultados más. Usa --limite para ver más.")

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
    parser = argparse.ArgumentParser(description="Buscador y curador anti-repetición de audios para V2-VIDEOS-IA")
    parser.add_argument("-b", "--buscar", help="Término de búsqueda (título, tag o descripción)")
    parser.add_argument("-H", "--historia", help="Describe la historia/tono del video para curar música fresca y pack SFX")
    parser.add_argument("-c", "--categoria", help="Filtrar por categoría (ej. videojuegos, terror, sfx)")
    parser.add_argument("-t", "--tipo", choices=["musica", "sfx", "ambiente"], help="Filtrar por tipo")
    parser.add_argument("--max-duracion", type=float, help="Duración máxima en segundos")
    parser.add_argument("--min-duracion", type=float, help="Duración mínima en segundos")
    parser.add_argument("--evitar-recientes", action="store_true", help="Omitir pistas usadas recientemente o >=2 veces")
    parser.add_argument("--sync-historial", action="store_true", help="Sincroniza el historial real desde video-studio/projects/")
    parser.add_argument("--registrar-uso", help="Registra ruta relativa de pista usada para no repetirla en futuros videos")
    parser.add_argument("--proyecto", help="Nombre del proyecto asociado a --registrar-uso")
    parser.add_argument("-l", "--listar-categorias", action="store_true", help="Listar todas las categorías")
    parser.add_argument("--limite", type=int, default=15, help="Límite de resultados a mostrar (default: 15)")
    parser.add_argument("--json", action="store_true", help="Salida en formato JSON")
    parser.add_argument("--copiar-a", help="Ruta de carpeta destino donde copiar el primer resultado")
    parser.add_argument("--nombre-destino", help="Nombre nuevo para el archivo copiado")

    args = parser.parse_args()
    buscar(args)


if __name__ == "__main__":
    main()
