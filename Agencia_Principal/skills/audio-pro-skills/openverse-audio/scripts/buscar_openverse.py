#!/usr/bin/env python3
"""
Buscador y descargador oficial de audios con licencia abierta (Openverse · WordPress Foundation).

Consulta directamente la API pública oficial https://api.openverse.org/v1/audio/ sin proxys de terceros
ni claves obligatorias. Filtra licencias seguras para uso comercial (CC0 / PDM por defecto, o CC-BY con
registro automático de atribución), valida seguridad de rutas y mide duración/LUFS/True Peak con ffprobe/ffmpeg.

Ejemplos:
  python3 buscar_openverse.py --buscar "whoosh transition" --max-dur 3 --limite 5
  python3 buscar_openverse.py --buscar "soft ui click" --licencia cc0 --descargar 1,2 --salida ./sfx_openverse
  python3 buscar_openverse.py --buscar "cinematic riser" --licencia comercial --json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_URL = "https://api.openverse.org/v1/audio/"
USER_AGENT = "V2-VIDEOS-IA-Agencia-Principal/1.0 (https://api.openverse.org/)"

LICENCIAS_PERMITIDAS = {
    "cc0": "cc0,pdm",
    "pdm": "pdm",
    "by": "by",
    "comercial": "cc0,pdm,by",
}

LICENCIAS_SEGURAS_SET = {"cc0", "pdm", "by"}
EXTENSIONES_AUDIO = {".mp3", ".wav", ".ogg", ".flac", ".m4a", ".opus", ".webm"}


def slugify(texto: str, max_len: int = 48) -> str:
    limpio = re.sub(r"[^a-zA-Z0-9]+", "-", texto.lower()).strip("-")
    return (limpio or "audio")[:max_len].strip("-")


def consultar_openverse(
    query: str,
    licencia: str = "cc0",
    limite: int = 10,
    min_dur: float | None = None,
    max_dur: float | None = None,
    categoria: str | None = None,
) -> dict:
    lic_param = LICENCIAS_PERMITIDAS.get(licencia.lower())
    if not lic_param:
        raise ValueError(f"Licencia no permitida: {licencia}. Usa: {', '.join(LICENCIAS_PERMITIDAS)}")

    params: dict[str, str | int] = {
        "q": query,
        "license": lic_param,
        "page_size": max(1, min(50, limite * 2 if (min_dur is not None or max_dur is not None) else limite)),
    }
    if categoria:
        params["category"] = categoria

    url = f"{API_URL}?{urllib.parse.urlencode(params)}"
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    token = os.environ.get("OPENVERSE_ACCESS_TOKEN", "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        cuerpo = exc.read().decode("utf-8", errors="ignore")[:240]
        raise RuntimeError(f"Error HTTP {exc.code} desde api.openverse.org: {cuerpo}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"No se pudo conectar con api.openverse.org: {exc.reason}") from exc

    filtrados = []
    for item in data.get("results", []):
        lic_code = (item.get("license") or "").lower()
        if lic_code not in LICENCIAS_SEGURAS_SET:
            continue
        dur_ms = item.get("duration")
        dur_s = round(dur_ms / 1000.0, 2) if isinstance(dur_ms, (int, float)) else None
        if min_dur is not None and (dur_s is None or dur_s < min_dur):
            continue
        if max_dur is not None and (dur_s is None or dur_s > max_dur):
            continue
        audio_url = item.get("url") or ""
        if not audio_url.startswith("https://"):
            continue
        filtrados.append({
            "id": item.get("id", ""),
            "titulo": (item.get("title") or "Sin título").strip(),
            "creador": (item.get("creator") or "Desconocido").strip(),
            "creador_url": item.get("creator_url") or "",
            "licencia": lic_code.upper(),
            "licencia_version": item.get("license_version") or "",
            "licencia_url": item.get("license_url") or "",
            "fuente": item.get("source") or item.get("provider") or "openverse",
            "pagina_origen": item.get("foreign_landing_url") or "",
            "url": audio_url,
            "duracion_seg": dur_s,
            "formato": (item.get("filetype") or Path(urllib.parse.urlparse(audio_url).path).suffix.lstrip(".") or "mp3").lower(),
            "atribucion": item.get("attribution") or "",
        })
        if len(filtrados) >= limite:
            break

    return {
        "query": query,
        "licencia_filtro": lic_param,
        "total_api": data.get("result_count", 0),
        "resultados": filtrados,
    }


def medir_audio_local(ruta: Path) -> dict:
    info: dict[str, object] = {"archivo": ruta.name, "bytes": ruta.stat().st_size}
    if shutil.which("ffprobe"):
        res = subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-show_entries", "format=duration:stream=codec_name,sample_rate,channels",
                "-of", "json", str(ruta),
            ],
            capture_output=True, text=True, timeout=15,
        )
        if res.returncode == 0:
            try:
                parsed = json.loads(res.stdout)
                dur = parsed.get("format", {}).get("duration")
                if dur:
                    info["duracion_real_seg"] = round(float(dur), 3)
                streams = parsed.get("streams") or []
                if streams:
                    info["codec"] = streams[0].get("codec_name")
                    info["sample_rate"] = streams[0].get("sample_rate")
                    info["canales"] = streams[0].get("channels")
            except (ValueError, KeyError):
                pass

    if shutil.which("ffmpeg"):
        res = subprocess.run(
            ["ffmpeg", "-hide_banner", "-nostats", "-i", str(ruta), "-af", "ebur128=peak=true,volumedetect", "-f", "null", "-"],
            capture_output=True, text=True, timeout=20,
        )
        txt = res.stderr
        m_i = re.search(r"I:\s*(-?\d+(?:\.\d+)?)\s*LUFS", txt)
        m_tp = re.search(r"Peak:\s*(-?\d+(?:\.\d+)?)\s*dBFS", txt)
        m_mean = re.search(r"mean_volume:\s*(-?\d+(?:\.\d+)?)\s*dB", txt)
        m_max = re.search(r"max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB", txt)
        if m_i and float(m_i.group(1)) > -69.5:
            info["lufs"] = float(m_i.group(1))
        if m_tp:
            info["true_peak_dbfs"] = float(m_tp.group(1))
        if m_mean:
            info["mean_volume_db"] = float(m_mean.group(1))
        if m_max:
            info["max_volume_db"] = float(m_max.group(1))
    return info


def descargar_audio(item: dict, carpeta_salida: Path) -> dict:
    destino_dir = carpeta_salida.resolve()
    if carpeta_salida.is_symlink():
        raise ValueError("El directorio de salida no puede ser un enlace simbólico.")
    destino_dir.mkdir(parents=True, exist_ok=True)

    ext = "." + re.sub(r"[^a-z0-9]", "", item.get("formato", "mp3").lower())
    if ext not in EXTENSIONES_AUDIO:
        ext = ".mp3"

    short_id = re.sub(r"[^a-zA-Z0-9]", "", item.get("id", ""))[:8] or "item"
    nombre_archivo = f"openverse-{short_id}_{slugify(item['titulo'])}{ext}"
    ruta_final = (destino_dir / nombre_archivo).resolve()
    if destino_dir not in ruta_final.parents:
        raise ValueError("Ruta de descarga inválida fuera del directorio destino.")

    url = item["url"]
    if not url.startswith("https://"):
        raise ValueError(f"URL insegura rechazada: {url}")

    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        ctype = (resp.headers.get("Content-Type") or "").lower()
        if ctype and not any(k in ctype for k in ("audio/", "application/octet-stream", "binary/octet-stream")):
            raise ValueError(f"Tipo de contenido inesperado ({ctype}) para {url}")
        contenido = resp.read(50 * 1024 * 1024 + 1)
        if len(contenido) > 50 * 1024 * 1024:
            raise ValueError("Archivo supera el límite de seguridad de 50 MB.")

    ruta_final.write_bytes(contenido)
    medicion = medir_audio_local(ruta_final)

    registro = {
        "archivo": nombre_archivo,
        "ruta": str(ruta_final),
        "descargado_utc": datetime.now(timezone.utc).isoformat(),
        **item,
        "medicion": medicion,
    }

    # Actualizar manifiesto JSON y CREDITS.md en destino
    manifest_path = destino_dir / "openverse_manifest.json"
    entries = []
    if manifest_path.is_file():
        try:
            entries = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            entries = []
    entries = [e for e in entries if e.get("id") != item.get("id")]
    entries.append(registro)
    manifest_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    credits_path = destino_dir / "CREDITS.md"
    lineas = ["# Créditos y Licencias de Audio (Openverse)\n"]
    for e in entries:
        lic = f"{e['licencia']} {e.get('licencia_version', '')}".strip()
        req_attr = " (requiere atribución)" if e["licencia"] == "BY" else " (dominio público / sin atribución obligatoria)"
        lineas.append(
            f"- `{e['archivo']}` — \"{e['titulo']}\" por **{e['creador']}** · Licencia: **{lic}**{req_attr} · Fuente: {e.get('pagina_origen') or e['url']}"
        )
    credits_path.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return registro


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Busca y descarga audios CC0/PDM/CC-BY desde la API oficial de Openverse (WordPress Foundation)."
    )
    parser.add_argument("--buscar", "-q", required=True, help="Términos de búsqueda en inglés (ej. 'whoosh', 'ui click', 'rain ambience').")
    parser.add_argument(
        "--licencia",
        choices=sorted(LICENCIAS_PERMITIDAS.keys()),
        default="cc0",
        help="Filtro de licencia segura: cc0 (CC0+PDM, por defecto), pdm, by (CC-BY con atribución), comercial (CC0+PDM+BY).",
    )
    parser.add_argument("--limite", type=int, default=8, help="Número máximo de resultados a mostrar (1-25).")
    parser.add_argument("--min-dur", type=float, default=None, help="Duración mínima en segundos.")
    parser.add_argument("--max-dur", type=float, default=None, help="Duración máxima en segundos (ej. 3.0 para SFX cortos).")
    parser.add_argument("--categoria", choices=["music", "sound_effect", "podcast", "audiobook", "pronunciation"], default=None, help="Categoría de audio Openverse.")
    parser.add_argument("--descargar", default="", help="Índices 1-based separados por coma para descargar (ej. '1' o '1,3').")
    parser.add_argument("--salida", default="./openverse_sfx", help="Directorio destino para los archivos descargados y CREDITS.md.")
    parser.add_argument("--json", action="store_true", help="Imprimir salida en formato JSON.")
    args = parser.parse_args()

    try:
        datos = consultar_openverse(
            query=args.buscar,
            licencia=args.licencia,
            limite=max(1, min(25, args.limite)),
            min_dur=args.min_dur,
            max_dur=args.max_dur,
            categoria=args.categoria,
        )
    except Exception as exc:
        print(f"ERROR Openverse: {exc}", file=sys.stderr)
        return 1

    descargados = []
    if args.descargar.strip():
        indices = []
        for tok in args.descargar.split(","):
            tok = tok.strip()
            if tok.isdigit():
                indices.append(int(tok))
        carpeta = Path(args.salida)
        for idx in indices:
            if 1 <= idx <= len(datos["resultados"]):
                try:
                    descargados.append(descargar_audio(datos["resultados"][idx - 1], carpeta))
                except Exception as exc:
                    print(f"ERROR descargando #{idx}: {exc}", file=sys.stderr)
                    return 1
            else:
                print(f"AVISO: índice #{idx} fuera de rango (1..{len(datos['resultados'])}).", file=sys.stderr)

    salida_final = {**datos, "descargados": descargados}
    if args.json:
        print(json.dumps(salida_final, ensure_ascii=False, indent=2))
        return 0

    print(f"\nOpenverse · '{datos['query']}' (licencia={datos['licencia_filtro']}, total_api={datos['total_api']})")
    print("-" * 86)
    if not datos["resultados"]:
        print("  Sin resultados que cumplan los filtros. Prueba términos en inglés más simples o --licencia comercial.")
    for i, r in enumerate(datos["resultados"], 1):
        dur = f"{r['duracion_seg']}s" if r["duracion_seg"] is not None else "n/a"
        print(f"  [{i}] {r['titulo'][:48]:<48} | {r['licencia']:<3} | {dur:>6} | {r['formato']:<4} | {r['creador'][:20]}")
        print(f"      URL: {r['url']}")
    if descargados:
        print("\nDescargados y medidos:")
        for d in descargados:
            m = d["medicion"]
            lufs = f"{m['lufs']} LUFS" if "lufs" in m else "LUFS n/a"
            tp = f"{m['true_peak_dbfs']} dBFS" if "true_peak_dbfs" in m else ""
            print(f"  ✓ {d['ruta']} ({m.get('duracion_real_seg', '?')}s, {lufs}, {tp})")
        print(f"  ✓ Manifiesto y créditos actualizados en {Path(args.salida).resolve()}/CREDITS.md")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
