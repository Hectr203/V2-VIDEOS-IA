#!/usr/bin/env python3
"""
Generador automático del Catálogo Semántico y Guía de Audios para V2-VIDEOS-IA.
Analiza y escanea automáticamente la biblioteca de audio (music/ y sfx/) y produce:
1. video-studio/assets/inventario_audios.json (Metadatos técnicos y rutas relativas)
2. video-studio/assets/catalogo_audios.json (JSON estructurado para IA y scripts)
3. video-studio/assets/GUIA_CATALOGO_AUDIOS.md (Guía Markdown completa y legible)
"""

import concurrent.futures
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUDIO = HERE.parent
ASSETS = STUDIO / "assets"
INVENTORY_FILE = ASSETS / "inventario_audios.json"
CATALOGO_JSON = ASSETS / "catalogo_audios.json"
GUIA_MD = ASSETS / "GUIA_CATALOGO_AUDIOS.md"


def probe_audio_file(file_path: Path) -> dict | None:
    """Extrae metadatos precisos de un archivo de audio con ffprobe."""
    rel_path = file_path.relative_to(ASSETS).as_posix()
    size_bytes = file_path.stat().st_size
    try:
        out = subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "a:0",
                "-show_entries",
                "stream=codec_name,sample_rate,channels,duration",
                "-show_entries",
                "format=duration,size",
                "-of",
                "json",
                str(file_path),
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        data = json.loads(out)
        streams = data.get("streams", [])
        fmt = data.get("format", {})

        duration = 0.0
        sample_rate = 44100
        channels = 2
        codec = file_path.suffix.lstrip(".").lower()

        if streams:
            s = streams[0]
            codec = s.get("codec_name") or codec
            sample_rate = int(s.get("sample_rate") or 44100)
            channels = int(s.get("channels") or 2)
            duration = float(s.get("duration") or 0.0)

        if duration <= 0.0 and "duration" in fmt:
            duration = float(fmt.get("duration") or 0.0)

        return {
            "file": rel_path,
            "duration": round(duration, 2),
            "sample_rate": sample_rate,
            "channels": channels,
            "codec": codec,
            "size_bytes": size_bytes,
        }
    except Exception as e:
        print(f"Error al analizar {file_path}: {e}", file=sys.stderr)
        return None


def construir_inventario() -> list[dict]:
    """Escanea y construye el inventario completo de archivos de audio."""
    print("Escaneando archivos de audio en video-studio/assets/ (music/ y sfx/)...")
    audio_files = []
    for ext in ("*.mp3", "*.wav", "*.m4a", "*.ogg"):
        audio_files.extend((ASSETS / "music").rglob(ext))
        audio_files.extend((ASSETS / "sfx").rglob(ext))

    # Eliminar duplicados si los hubiera
    audio_files = sorted(list(set(audio_files)), key=lambda p: p.as_posix())

    inventory = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(probe_audio_file, audio_files))
        for res in results:
            if res:
                inventory.append(res)

    # Ordenar por ruta relativa
    inventory.sort(key=lambda x: x["file"])

    with open(INVENTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(inventory, f, indent=2, ensure_ascii=False)

    print(f"Inventario generado: {len(inventory)} audios en {INVENTORY_FILE}")
    return inventory


def clean_title(filename: str) -> str:
    name = filename.rsplit(".", 1)[0]
    name = re.sub(r"\(MP3_\d+K\)|\(M4A_\d+K\)", "", name)
    name = re.sub(
        r"\[MÚSICA SIN COPYRIGHT\]|\[COPYRIGHT FREE.*?\]|\[NOT MONETIZABLE\]|\[NO COPYRIGHT.*?\]|\[HQ.*?\]",
        "",
        name,
        flags=re.IGNORECASE,
    )
    name = re.sub(r"^\d+\s*-\s*", "", name)
    name = re.sub(r"\(HD\)|\(download\)|\(Original\)", "", name, flags=re.IGNORECASE)
    name = re.sub(r"[_\s]+", " ", name).strip()
    return name


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text).strip("-")
    return text[:60]


def categorize_track(item: dict) -> dict:
    fpath = item["file"]
    parts = fpath.split("/")
    folder = parts[0]
    subfolder = parts[1] if len(parts) > 2 else ""
    filename = parts[-1]
    duration = item["duration"]
    cleaned_name = clean_title(filename)

    track_id = slugify(f"{parts[1] if len(parts) > 2 else parts[0]}-{cleaned_name}")
    tags = [w.lower() for w in re.findall(r"\w+", cleaned_name) if len(w) > 2]

    # Determinación de tipo y categoría según ubicación física
    if "sound effects/" in fpath:
        tipo = "sfx"
        categoria = "sound_effects_populares"
        vol = 0.22
        desc = "Efecto de sonido popular, viral de internet, meme o caricatura"
        tags.extend(["sfx", "popular", "viral", "meme", "cartoon", "efecto"])
    elif "Trancisiones" in fpath:
        tipo = "sfx"
        categoria = "transiciones_camara_swish"
        vol = 0.20
        desc = "Transición rápida de escena, swish de cámara o barrido dinámico"
        tags.extend(["transicion", "swish", "whoosh", "corte", "camara", "cambio"])
    elif "Expresiones" in fpath:
        tipo = "sfx"
        categoria = "expresiones_celebraciones_asombro"
        vol = 0.22
        desc = "Celebración, asombro, triunfo, coro celestial o acierto"
        tags.extend(["celebracion", "acierto", "asombro", "aleluya", "triunfo", "exito"])
    elif "Golpes" in fpath:
        tipo = "sfx"
        categoria = "golpes_caidas_impactos"
        vol = 0.22
        desc = "Impacto físico, caída al piso, bofetada o remate seco"
        tags.extend(["golpe", "caida", "impacto", "slap", "punch", "drop", "crash"])
    elif "Gritoss" in fpath:
        tipo = "sfx"
        categoria = "gritos_sustos_reacciones"
        vol = 0.16
        desc = "Grito cómico, susto, queja histérica o reacción extrema"
        tags.extend(["grito", "susto", "reaccion", "scream", "panico", "alarma"])
    elif "Fails" in fpath:
        tipo = "sfx"
        categoria = "fails_errores_comicos"
        vol = 0.20
        desc = "Error cómico, fallo, desilusión, cuak o disco rayado"
        tags.extend(["fail", "error", "fallo", "desilusion", "cuak", "decepcion"])
    elif "Risas" in fpath:
        tipo = "sfx"
        categoria = "risas_carcajadas"
        vol = 0.20
        desc = "Risa contagiosa, carcajada meme o humor absurdo"
        tags.extend(["risa", "carcajada", "humor", "comedia", "chiste", "laugh"])
    elif "Extras" in fpath:
        tipo = "sfx"
        categoria = "extras_cartoon_armas_dinero"
        vol = 0.20
        desc = "Efecto de caricatura (boing, ricochet), disparo o sonido de dinero"
        tags.extend(["cartoon", "boing", "dinero", "cash", "bomba", "ricochet"])
    elif folder == "sfx" and len(parts) == 2:
        tipo = "sfx"
        categoria = "ui_interfaz_micro_sfx"
        vol = 0.22
        desc = "Efecto de interfaz de usuario y motion graphics normalizado a -3.0 dBFS"
        tags.extend(["ui", "interfaz", "motion", "micro-sfx"])
    elif "Sonidos memes" in fpath:
        tipo = "sfx"
        categoria = "memes_virales_internet"
        vol = 0.20
        desc = "Efecto meme clásico de YouTube, TikTok y cultura de internet"
        tags.extend(["meme", "viral", "tiktok", "youtube", "shitpost", "humor"])
    elif "Terror y Drama" in fpath:
        if duration > 40:
            tipo = "musica"
            categoria = "dramatico_terror_tension"
            vol = 0.04
            desc = "Pista musical oscura, suspenso opresivo o atmósfera de terror"
            tags.extend(["musica", "terror", "drama", "suspenso", "oscuridad", "misterio"])
        else:
            tipo = "sfx"
            categoria = "stingers_terror_suspense"
            vol = 0.20
            desc = "Stinger de tensión dramática, BWONG, dun dun dun o alarma"
            tags.extend(["stinger", "tension", "drama", "sustos", "bwong", "impacto"])
    elif "SOUNDTRACKS" in fpath:
        tipo = "musica"
        categoria = "videojuegos_soundtracks"
        vol = 0.04
        desc = "Banda sonora legendaria de videojuegos (aventura, batalla, nostalgia o chill)"
        tags.extend(["videojuegos", "soundtrack", "ost", "gaming", "retro", "nostalgia", "bgm"])
    elif "VIAJE" in fpath:
        tipo = "musica"
        categoria = "viajes_vlog_verano"
        vol = 0.04
        desc = "Música fresca de verano, tropical house, adrenalina, viajes y vlogs"
        tags.extend(["viaje", "vlog", "verano", "tropical", "house", "chill", "aventura", "bgm"])
    elif "Lluvia Y Brillos" in fpath:
        tipo = "ambiente"
        categoria = "naturaleza_lluvia_calma"
        vol = 0.06
        desc = "Atmósfera relajante de lluvia continua, truenos, meditación y calma"
        tags.extend(["lluvia", "relajacion", "calma", "naturaleza", "truenos", "meditacion", "ambiente"])
    elif "Música De Fondo Para Videos" in fpath:
        if "Dramática" in filename or "Inspiradora y Dramática" in filename:
            tipo = "musica"
            categoria = "dramatico_serio_tension"
            vol = 0.04
            desc = "Música orquestal dramática en crescendo para temas graves o crisis"
            tags.extend(["drama", "orquestal", "crescendo", "emocional", "serio", "bgm"])
        elif "Cinematográfica Moderna" in filename:
            tipo = "musica"
            categoria = "ciencia_tecnologia_curiosidad"
            vol = 0.04
            desc = "Sintetizadores cinematográficos modernos para tecnología profunda e IA"
            tags.extend(["tecnologia", "ia", "futuro", "sintetizadores", "moderno", "bgm"])
        elif "Corporativo" in filename or "Emprendimiento" in filename or "Presentaciones" in filename or "Publicidad" in filename:
            tipo = "musica"
            categoria = "corporativo_negocios_productividad"
            vol = 0.04
            desc = "Fondo corporativo elegante, minimalista y dinámico para empresas y startups"
            tags.extend(["corporativo", "negocios", "empresa", "startups", "productividad", "bgm"])
        elif "Educativos" in filename:
            tipo = "musica"
            categoria = "educativo_pedagogico"
            vol = 0.04
            desc = "Música didáctica, cálida y optimista para guías y explicaciones"
            tags.extend(["educativo", "pedagogico", "aprendizaje", "amigable", "didactico", "bgm"])
        else:
            tipo = "musica"
            categoria = "fondo_versatil"
            vol = 0.04
            desc = "Música instrumental versátil de fondo para presentaciones"
            tags.extend(["versatil", "fondo", "instrumental", "presentacion", "bgm"])
    elif filename == "ambient_curiosity.mp3":
        tipo = "musica"
        categoria = "ciencia_tecnologia_curiosidad"
        vol = 0.04
        desc = "Pizzicato y marimba de curiosidad intelectual para ciencia, química y física"
        tags.extend(["ciencia", "curiosidad", "quimica", "marimba", "pizzicato", "bgm"])
    else:
        tipo = "sfx" if folder == "sfx" else "musica"
        categoria = "general_sfx" if folder == "sfx" else "general"
        vol = 0.20 if folder == "sfx" else 0.04
        desc = "Audio complementario de estudio"
        tags.extend(["general", "estudio"])

    return {
        "id": track_id,
        "file": fpath,
        "nombre": cleaned_name,
        "tipo": tipo,
        "categoria": categoria,
        "duracion_segundos": item["duration"],
        "volumen_sugerido": vol,
        "sample_rate": item["sample_rate"],
        "canales": item["channels"],
        "codec": item["codec"],
        "descripcion": desc,
        "tags": sorted(list(set(tags))),
    }


def main():
    # 1. Construir o refrescar inventario escaneando disco
    inventory = construir_inventario()

    # 2. Categorizar cada pista
    catalog_items = [categorize_track(item) for item in inventory]

    # 3. Agrupar por categorías
    categories_dict = {}
    for item in catalog_items:
        cat = item["categoria"]
        if cat not in categories_dict:
            categories_dict[cat] = {
                "tipo": item["tipo"],
                "total_pistas": 0,
                "duracion_total_segundos": 0.0,
                "pistas": [],
            }
        categories_dict[cat]["total_pistas"] += 1
        categories_dict[cat]["duracion_total_segundos"] = round(
            categories_dict[cat]["duracion_total_segundos"] + item["duracion_segundos"], 2
        )
        categories_dict[cat]["pistas"].append({
            "id": item["id"],
            "nombre": item["nombre"],
            "file": item["file"],
            "duracion": item["duracion_segundos"],
            "volumen_sugerido": item["volumen_sugerido"],
            "descripcion": item["descripcion"],
            "tags": item["tags"][:6],
        })

    # 4. Guardar JSON completo del catálogo
    full_catalog = {
        "version": "2.1.0",
        "total_audios": len(catalog_items),
        "reglas_mezcla": {
            "auto_ducking_musica": {
                "descripcion": "Atenuación dinámica obligatoria en Film.tsx mientras el narrador habla",
                "volumen_con_voz": 0.35,  # -9 dB
                "volumen_sin_voz": 1.0,
                "fade_frames": 8,
            },
            "sfx_pico_max_dbfs": -3.0,
            "master_true_peak_max_dbfs": -1.0,
        },
        "resumen_categorias": {
            k: {
                "tipo": v["tipo"],
                "total_pistas": v["total_pistas"],
                "duracion_total": v["duracion_total_segundos"],
            }
            for k, v in categories_dict.items()
        },
        "categorias": categories_dict,
        "indice_completo": catalog_items,
    }

    with open(CATALOGO_JSON, "w", encoding="utf-8") as f:
        json.dump(full_catalog, f, indent=2, ensure_ascii=False)
    print(f"Catálogo JSON generado en: {CATALOGO_JSON} ({len(catalog_items)} audios)")

    # 5. Generar Guía Markdown estructurada y legible
    generar_guia_markdown(categories_dict, len(catalog_items))


def generar_guia_markdown(categories_dict: dict, total_audios: int):
    md = []
    md.append(f"# Catálogo Maestro y Guía de Audios ({total_audios} Archivos Analizados)")
    md.append("")
    md.append("Esta guía clasifica la biblioteca integral de audio de `video-studio/assets` para que los agentes de IA y creadores seleccionen de inmediato la música de fondo (BGM), efectos sonoros (SFX) y reacciones ideales para cualquier temática audiovisual.")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 1. Reglas Fundamentales de Audio y Anti-Saturación")
    md.append("")
    md.append("1. **Voz Siempre Dominante:** La narración de voz debe entenderse de manera limpia e indiscutible sobre cualquier elemento sonoro.")
    md.append("2. **Auto-Ducking Obligatorio en `Film.tsx`:** La música de fondo debe atenuarse automáticamente al **35% (-9 dB)** durante cada palabra o segmento donde el narrador hable.")
    md.append("3. **Pico Máximo Master < -1.0 dBFS:** La mezcla final nunca debe alcanzar 0 dBFS. El headroom mínimo de seguridad es de 1 dB para evitar saturación digital en reproductores y redes sociales.")
    md.append("4. **SFX Normalizados a -3.0 dBFS:** Los efectos de sonido deben situarse con volúmenes en Remotion entre `0.16` y `0.24` según su impacto.")
    md.append("5. **Búsqueda Instantánea con CLI:** Usa `python3 video-studio/scripts/buscar_audio.py --buscar <termino>` o `--categoria <nombre>` para obtener la ruta y volumen exactos al instante.")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 2. Mapa Rápido de Música de Fondo por Temática (BGM)")
    md.append("")
    md.append("| Temática / Emoción | Categoría Recomendada | Pista Destacada | Duración | Volumen en Remotion |")
    md.append("|---|---|---|---|---|")
    md.append("| **Drama / Peligro / Crisis** (Adicciones, alertas, tensión) | `dramatico_serio_tension` | `music/Mix - Música De Fondo Para Videos y Presentaciones/12 - Música De Fondo Inspiradora y Dramática Para Videos.mp3` | 2:09 min | `0.04` (duck a `0.014`) |")
    md.append("| **Terror Psicológico / Tensión Oscura** | `dramatico_terror_tension` | `music/Terror y Drama/REPULSIVE - Forgotten [COPYRIGHT FREE DARK MUSIC].mp3` | 3:22 min | `0.04` (duck a `0.014`) |")
    md.append("| **Ciencia / Tecnología / Divulgación** (Química, medicina, física) | `ciencia_tecnologia_curiosidad` | `music/ambient_curiosity.mp3` | 2:00 min | `0.04` (duck a `0.014`) |")
    md.append("| **Inteligencia Artificial / Futuro / Algoritmos** | `ciencia_tecnologia_curiosidad` | `music/Mix - Música De Fondo Para Videos y Presentaciones/11 - Música Cinematográfica Moderna Música Instrumental para Videos.mp3` | 3:00 min | `0.04` (duck a `0.014`) |")
    md.append("| **Corporativo / Startups / Negocios** (SaaS, productividad) | `corporativo_negocios_productividad` | `music/Mix - Música De Fondo Para Videos y Presentaciones/04 - Música De Fondo Para Presentaciones y Videos Corporativos.mp3` | 2:30 min | `0.04` (duck a `0.014`) |")
    md.append("| **Épico / Videojuegos / Batallas** (Megalovania, Boss fights) | `videojuegos_soundtracks` | `music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/01 - 100. MEGALOVANIA (UNDERTALE Soundtrack) - Toby Fox.mp3` | 2:40 min | `0.04` (duck a `0.014`) |")
    md.append("| **Calma Nostálgica / Reflexión** (Minecraft, Zelda) | `videojuegos_soundtracks` | `music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/55 - C418 - Sweden - Minecraft Volume Alpha.mp3` | 3:35 min | `0.05` (duck a `0.018`) |")
    md.append("| **Viajes / Vlogs / Optimismo / Verano** (Tropical house) | `viajes_vlog_verano` | `music/MUSICA para VIDEOS de VIAJE 2020 🏖/02 - Tobu - Roots House NCS - Copyright Free Music.mp3` | 3:10 min | `0.04` (duck a `0.014`) |")
    md.append("| **Lofi Chill / Estudio / Trabajo Relajado** | `viajes_vlog_verano` | `music/MUSICA para VIDEOS de VIAJE 2020 🏖/34 - MUSICA LoFi CHILL para VIDEOS GRATIS 2022 🌿[NOT MONETIZABLE] ✅ FREE Download 🎸.mp3` | 3:05 min | `0.04` (duck a `0.014`) |")
    md.append("| **Naturaleza / Lluvia / Meditación** | `naturaleza_lluvia_calma` | `music/Mix - Lluvia Y Brillos/12 - Ambiente De Lluvia.mp3` | 3:00 min | `0.06` |")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 3. Biblioteca Legendaria de Videojuegos (98 Soundtracks)")
    md.append("")
    md.append("Ubicados en `video-studio/assets/music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/`:")
    md.append("")
    md.append("* **Épicos y Combate:** Undertale (*Megalovania*, *Hopes and Dreams*), Ultrakill (*Tenebre Rosso Sangue*), Persona 5 (*Life Will Change*), Dark Souls (*Gwyn Lord of Cinder*), Super Smash Bros Ultimate (*Lifelight*), Danganronpa.")
    md.append("* **Calma y Nostalgia:** Minecraft (*C418 - Sweden*), Zelda (*Song of Healing*, *Midna's Lament*, *Lon Lon Ranch*), Super Mario 64 (*Dire Dire Docks*), Super Mario Galaxy (*Rosalina's Storybook*), Chrono Trigger (*Corridors of Time*), The Sims (*Buy Mode 1*), To The Moon (*For River*).")
    md.append("* **Aventura y Acción:** GTA San Andreas (*Theme Full*), GTA 4 (*Theme Song*), Portal 2 (*Want You Gone*), The Last of Us (*Theme*), Sonic 2 (*Aquatic Ruin*), DuckTales (*The Moon Theme*), Crash Bandicoot 3, Super Mario RPG (*Forest Maze*).")
    md.append("* **Misterio y Tensión:** Silent Hill 2 (*Promise Reprise*), Papers Please (*Theme Song*), Phoenix Wright (*Pressing Pursuit ~ Cornered*).")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 4. Biblioteca de Viajes, Verano y Vlogs (34 Pistas)")
    md.append("")
    md.append("Ubicados en `video-studio/assets/music/MUSICA para VIDEOS de VIAJE 2020 🏖/`:")
    md.append("")
    md.append("* **Tropical House & EDM Sin Copyright:** Tobu (*Roots*), JJD (*Adventure Glitch Hop*), Diamond Eyes (*Everything Dubstep*), Alex Menco (*Summer Chill*), Fredji (*Happy Life*), Mike Perry (*Stay Young*).")
    md.append("* **Lofi & Chillout:** Lofi Chill 2022, Hip Hop Chill para videos, Chill Out para trabajar relajado.")
    md.append("* **Aventura & Adrenalina:** Videos Adrenalina Gratis, Música de Aventura, Música Imponente de Viajes.")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 5. Efectos de Sonido (SFX) para Animación 2D y Edición")
    md.append("")
    md.append("### A. Transiciones y Movimientos de Cámara (`sfx/Trancisiones Necesarias/`)")
    md.append("* **`sfx/Trancisiones Necesarias/Fast Whoosh Sound Effect.mp3`** (`vol: 0.20`): Whoosh dinámico ultrarrápido.")
    md.append("* **`sfx/Trancisiones Necesarias/01 - Abduction swish.wav`** (`vol: 0.18`): Swish limpio y moderno.")
    md.append("* **`sfx/Trancisiones Necesarias/EFECTO DE SONIDO.-TRANSICIÓN_GIRO LENTO_ZOOM _ENTRADA EXPLOSIVA.mp3`** (`vol: 0.20`): Zoom explosivo con giro.")
    md.append("* **`sfx/Trancisiones Necesarias/Deslizar - efecto de sonido gracioso.mp3`** (`vol: 0.22`): Deslizamiento cómico o caricaturesco.")
    md.append("* **`sfx/Trancisiones Necesarias/Whoosh Sound Effect HD _ No Copyright.mp3`** (`vol: 0.20`): Barrido de cámara limpio.")
    md.append("* **`sfx/Trancisiones Necesarias/Sonido del Click del Mouse __ Mouse Click - Sound Effect.mp3`** (`vol: 0.22`): Click de ratón / interacción.")
    md.append("")
    md.append("### C. Sound Effects Populares y Virales (`sfx/sound effects/`)")
    md.append("* **`sfx/sound effects/YEET - Sound Effect HD.mp3`** (`vol: 0.22`): Lanzamiento con fuerza / YEET.")
    md.append("* **`sfx/sound effects/Bruh Sound Effect.mp3`** (`vol: 0.22`): Reacción clásica Bruh.")
    md.append("* **`sfx/sound effects/taco bell.m4a`** (`vol: 0.22`): Campana icónica de Taco Bell / golpe sónico.")
    md.append("* **`sfx/sound effects/Among us sound effect.mp3`** (`vol: 0.22`): Tensión / asesinato Among Us.")
    md.append("* **`sfx/sound effects/Doraemon Notification Sound.mp3`** (`vol: 0.22`): Notificación tierna y mágica.")
    md.append("* **`sfx/sound effects/Illuminati Confirmed.mp3`** (`vol: 0.20`): Teoría conspirativa / misterio meme.")
    md.append("* **`sfx/sound effects/Glitch.wav`** (`vol: 0.20`): Error visual, fallo técnico o interferencia.")
    md.append("* **`sfx/sound effects/Bamboo Hit.mp3`** (`vol: 0.22`): Golpe caricaturesco de bambú estilo anime.")
    md.append("* **`sfx/sound effects/Reveal Sound Effect.mp3`** (`vol: 0.22`): Revelación de dato o aparición.")
    md.append("* **`sfx/sound effects/Twitch Alert Sound Effect.m4a`** (`vol: 0.22`): Alerta digital o evento en directo.")
    md.append("* **`sfx/sound effects/Spider-Man 3 Meme Sound.mp3`** (`vol: 0.22`): Canción triste o momento dramático meme.")
    md.append("")
    md.append("### D. Expresiones y Celebraciones (`sfx/Expresiones (Celebraciones y Asombros)/`)")
    md.append("* `sfx/Expresiones (Celebraciones y Asombros)/ALELUYA _ Efecto de sonido.mp3` (`vol: 0.20`): Solución milagrosa o descubrimiento triunfal.")
    md.append("* `sfx/Expresiones (Celebraciones y Asombros)/Coro Celestial (Efecto de Sonido) Heavenly Choir.mp3` (`vol: 0.20`): Revelación divina o epifanía cómica.")
    md.append("* `sfx/Expresiones (Celebraciones y Asombros)/Descargar Efecto de Sonido Acierto _ Correcto en HD.mp3` (`vol: 0.22`): Respuesta correcta o validación positiva.")
    md.append("* `sfx/Expresiones (Celebraciones y Asombros)/Children Celebrating Sound Effect _ Niños Celebrando.mp3` (`vol: 0.22`): Festejo y vítores en multitud.")
    md.append("* `sfx/Expresiones (Celebraciones y Asombros)/Asombro efecto de sonido para tus vídeos.mp3` (`vol: 0.20`): Reacción de '¡Woooow!'.")
    md.append("")
    md.append("### E. Golpes, Caídas e Impactos (`sfx/Golpes y Caidas/`)")
    md.append("* `sfx/Golpes y Caidas/Efecto de sonido caer al piso.mp3` (`vol: 0.22`): Caída de personaje u objeto pesado.")
    md.append("* `sfx/Golpes y Caidas/Among Us (Kill) - Sound Effect (HD).mp3` (`vol: 0.22`): Impacto seco o eliminación.")
    md.append("* `sfx/Golpes y Caidas/And His Name is JOHN CENA - Sound Effect (HD).mp3` (`vol: 0.22`): Entrada triunfal sorpresiva con fanfarria.")
    md.append("* `sfx/Golpes y Caidas/Bruh Sound Effect _2.mp3` (`vol: 0.22`): Decepción resignada o momento incómodo.")
    md.append("* `sfx/Golpes y Caidas/Efecto de Sonido - Chan - Lluvia de Chanes.mp3` (`vol: 0.20`): Golpe de suspenso latino clásico.")
    md.append("")
    md.append("### F. Gritos y Sustos (`sfx/Gritoss/`)")
    md.append("* `sfx/Gritoss/Grito de Hombre - efecto de sonido.mp3` (`vol: 0.16`): Grito cómico masculino.")
    md.append("* `sfx/Gritoss/Efecto de sonido - NOOO__ (grito).mp3` (`vol: 0.16`): Grito desesperado de negación.")
    md.append("* `sfx/Gritoss/El Tano Pasman - Nooo Noooo.mp3` (`vol: 0.16`): Clásica frustración futbolística.")
    md.append("* `sfx/Gritoss/Goat Scream - Origine Meme (HD).mp3` (`vol: 0.16`): Grito de cabra humana viral.")
    md.append("* `sfx/Gritoss/Keemstar Screaming (Gritó_) Efecto Sonido 2021_.mp3` (`vol: 0.16`): Grito meme hiperbólico.")
    md.append("")
    md.append("### G. Fails y Errores (`sfx/Fails/`)")
    md.append("* `sfx/Fails/Descargar Efecto de Sonido Falla _ Error en HD (Sin Copyright).mp3` (`vol: 0.20`): Sonido oficial de fallo de sistema.")
    md.append("* `sfx/Fails/Disco rayado ORIGINAL Y SIN REPETICIONES.mp3` (`vol: 0.20`): Detención abrupta de la música o situación incómoda.")
    md.append("* `sfx/Fails/Cuak Efecto de Sonido Para Vídeos - Efecto de Sonido Cuak.mp3` (`vol: 0.20`): Remate cómico de desilusión.")
    md.append("* `sfx/Fails/Efecto de sonido abucheo.mp3` (`vol: 0.20`): Rechazo del público ante una mala idea.")
    md.append("")
    md.append("### H. Risas y Humor (`sfx/Risas/`)")
    md.append("* `sfx/Risas/Risitas_ meme Original.mp3` (`vol: 0.20`): Carcajada asmática viral de Risitas.")
    md.append("* `sfx/Risas/La risa de Don Ramón - Memes _shorts.mp3` (`vol: 0.20`): Risa burlona nostálgica.")
    md.append("* `sfx/Risas/Estatua de tigre riendo.mp3` (`vol: 0.20`): Risa aguda descontrolada.")
    md.append("")
    md.append("### I. Extras de Caricatura y Finanzas (`sfx/Extras/`)")
    md.append("* `sfx/Extras/Cash SFX _13 _ Dinero Efecto de Sonido.mp3` (`vol: 0.22`): Sonido de caja registradora / dinero.")
    md.append("* `sfx/Extras/Cartoon Boing (Spring Sound) - Sound Effects for Editing.mp3` (`vol: 0.22`): Rebote de resorte elástico.")
    md.append("* `sfx/Extras/Cartoon Ricochet Sound Effect.mp3` (`vol: 0.20`): Rebote metálico de bala caricaturesca.")
    md.append("* `sfx/Extras/Efecto de una bomba.mp3` (`vol: 0.20`): Explosión de dibujo animado.")
    md.append("")
    md.append("### J. Stingers de Terror y Suspenso (`music/Terror y Drama/`)")
    md.append("* `music/Terror y Drama/Inception BWONG Sound.mp3` (`vol: 0.20`): Golpe sónico monumental de intriga.")
    md.append("* `music/Terror y Drama/Cinema Sins (Dun) - Sound Effect (HD).mp3` (`vol: 0.20`): Golpe de pecado o error detectado.")
    md.append("* `music/Terror y Drama/Dross - Perturbador [HQ Piano Cover].mp3` (`vol: 0.20`): Acorde disonante perturbador.")
    md.append("* `music/Terror y Drama/Among Us (Role Reveal) - Sound Effect (HD).mp3` (`vol: 0.20`): Revelación de sospechoso o impostor.")
    md.append("* `music/Terror y Drama/Biohazard Alarm[WARNING_ The sound is very LOUD].mp3` (`vol: 0.16`): Alarma industrial de peligro.")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 6. Cómo Usar Audios en Remotion con `staticFile()`")
    md.append("")
    md.append("```tsx")
    md.append("import { Audio, staticFile } from 'remotion';")
    md.append("")
    md.append("// 1. Música de fondo con auto-ducking:")
    md.append("<Audio")
    md.append("  src={staticFile('music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/55 - C418 - Sweden - Minecraft Volume Alpha.mp3')}")
    md.append("  volume={(frame) => {")
    md.append("    const isSpeaking = voiceRanges.some(([s, e]) => frame >= s && frame <= e);")
    md.append("    return isSpeaking ? 0.018 : 0.05;")
    md.append("  }}")
    md.append("/>")
    md.append("")
    md.append("// 2. Efecto de sonido puntual (SFX):")
    md.append("<Sequence from={90} durationInFrames={30}>")
    md.append("  <Audio")
    md.append("    src={staticFile('sfx/sound effects/YEET - Sound Effect HD.mp3')}")
    md.append("    volume={0.22}")
    md.append("  />")
    md.append("</Sequence>")
    md.append("```")
    md.append("")

    with open(GUIA_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")
    print(f"Guía Markdown generada en: {GUIA_MD}")


if __name__ == "__main__":
    main()
