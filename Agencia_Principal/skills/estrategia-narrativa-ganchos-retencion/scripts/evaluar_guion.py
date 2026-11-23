#!/usr/bin/env python3
"""
Evaluador predictivo de guiones, ganchos (0-3s), ritmo y atractivo temático
para videos de entretenimiento educativo y storytelling (Un Dato Más / Agencia Principal).

Uso:
  python3 evaluar_guion.py --storyboard path/to/storyboard.json
  python3 evaluar_guion.py --tema "Cómo funcionan los volcanes" --gancho "Este volcán cambió el clima del planeta entero."
"""

import argparse
import json
import re
import sys
from pathlib import Path

CLICHES_PROHIBIDOS = [
    r"\bhola\s+(a\s+todos|amigos|chicos|gente)\b",
    r"\bbienvenidos\s+(a|de\s+nuevo)\b",
    r"\bhoy\s+(vamos\s+a\s+hablar|te\s+voy\s+a\s+explicar|veremos)\b",
    r"\ben\s+este\s+video\s+(vamos|veremos|hablaremos)\b",
    r"\bantes\s+de\s+empezar\b",
]

GATILLOS_CURIOSIDAD = [
    "secreto", "oculto", "verdad", "engaño", "truco", "mito", "nadie", "jamás",
    "nunca", "imposible", "por qué", "cómo", "qué pasa", "sabías", "realidad",
    "sorprend", "oscur", "crudo", "borró", "cambió", "esconde", "prohibid",
    "misterio", "paradoja", "extremo", "realmente", "loca", "increíble",
]

CONECTORES_REHOOK = [
    "pero", "sin embargo", "aquí va", "el verdadero", "el mayor", "primer",
    "segundo", "otro truco", "lo peor", "lo más", "hasta que", "ahora",
    "aun así", "hay un detalle", "y aquí", "en realidad", "entonces",
]

PALABRAS_EMOCION_HUMOR = [
    "risa", "broma", "llorar", "dolor", "miedo", "hambre", "loca", "caótic",
    "fiesta", "desgarrador", "hiela", "soledad", "calor", "magia", "asombro",
    "shock", "peligro", "superviv", "amor", "triste", "feliz", "genial", "brutal",
]


def evaluar_gancho(texto: str) -> tuple[int, list[str], list[str]]:
    t = texto.strip()
    tl = t.lower()
    palabras = re.findall(r"[a-zA-ZáéíóúñüÁÉÍÓÚÑÜ0-9]+", t)
    score = 45
    fortalezas, mejoras = [], []

    # 1. Penalización fuerte por clichés de inicio lento
    cliche_hit = any(re.search(pat, tl) for pat in CLICHES_PROHIBIDOS)
    if cliche_hit:
        score -= 28
        mejoras.append("Eliminar saludo/preámbulo lento ('Hola amigos', 'Hoy vamos a hablar...'). Abrir directo en la tensión.")
    else:
        score += 15
        fortalezas.append("Inicio directo sin preámbulos clichés (scroll-stop limpio).")

    # 2. Pregunta abierta o contraste / exclamación
    if "?" in t or "¿" in t or "¡" in t:
        score += 12
        fortalezas.append("Usa pregunta o tensión directa que abre brecha de curiosidad.")

    # 3. Gatillos de curiosidad / Information Gap
    hits_cur = [w for w in GATILLOS_CURIOSIDAD if w in tl]
    if hits_cur:
        score += min(18, 8 + len(hits_cur) * 4)
        fortalezas.append(f"Activa brecha de curiosidad ({', '.join(hits_cur[:4])}).")
    else:
        mejoras.append("Añadir un gatillo claro de curiosidad (secreto, mito roto, paradoja o dato contraintuitivo).")

    # 4. Ritmo de primera frase (<= 22 palabras antes del primer punto)
    primera_frase = re.split(r"[.!?]", t)[0]
    n_primera = len(re.findall(r"[a-zA-ZáéíóúñüÁÉÍÓÚÑÜ0-9]+", primera_frase))
    if 6 <= n_primera <= 22:
        score += 10
        fortalezas.append(f"Primera frase ágil y comprensible al instante ({n_primera} palabras).")
    elif n_primera > 24:
        score -= 8
        mejoras.append(f"Acortar la primera frase ({n_primera} palabras); ideal 10–18 palabras para golpear en < 3 segundos.")

    # 5. Datos / contraste numérico o temporal
    if re.search(r"\b(\d+|cien|mil|millones|décadas|siglo|segundos|años)\b", tl):
        score += 6
        fortalezas.append("Incluye ancla temporal o cuantitativa que da peso al gancho.")

    return max(0, min(100, score)), fortalezas, mejoras


def evaluar_storyboard(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    scenes = data.get("scenes", [])
    if not scenes:
        raise ValueError("El storyboard no contiene escenas.")

    hook_text = scenes[0].get("text", "")
    hook_score, hook_ok, hook_fix = evaluar_gancho(hook_text)

    # Ritmo y anti-aburrimiento
    num_scenes = len(scenes)
    word_counts = [len(re.findall(r"[a-zA-ZáéíóúñüÁÉÍÓÚÑÜ0-9]+", sc.get("text", ""))) for sc in scenes]
    total_words = sum(word_counts)
    est_seconds = total_words / 2.75  # ~165 WPM hablado natural
    avg_sec_per_scene = est_seconds / max(1, num_scenes)

    ritmo_score = 60
    ritmo_ok, ritmo_fix = [], []

    if 5.5 <= avg_sec_per_scene <= 11.5:
        ritmo_score += 22
        ritmo_ok.append(f"Ritmo ágil ({num_scenes} escenas, ~{avg_sec_per_scene:.1f}s promedio/escena — cero efecto diapositiva).")
    elif avg_sec_per_scene > 13.0:
        ritmo_score -= 20
        ritmo_fix.append(f"Escenas demasiado largas (~{avg_sec_per_scene:.1f}s c/u). Dividir en más escenas ágiles de 6–10s.")
    else:
        ritmo_score += 12
        ritmo_ok.append(f"Escenas rápidas ({num_scenes} escenas, ~{avg_sec_per_scene:.1f}s c/u).")

    # Re-hooks en cuerpo intermedio
    body_scenes = scenes[1:-1] if len(scenes) > 2 else scenes[1:]
    rehook_hits = sum(
        1 for sc in body_scenes
        if any(c in sc.get("text", "").lower() for c in CONECTORES_REHOOK)
    )
    rehook_ratio = rehook_hits / max(1, len(body_scenes))
    if rehook_ratio >= 0.45:
        ritmo_score += 18
        ritmo_ok.append(f"Excelentes re-ganchos en el desarrollo ({rehook_hits}/{len(body_scenes)} escenas mantienen open loops).")
    else:
        ritmo_fix.append("Agregar más giros / re-ganchos ('Pero...', 'En realidad...', 'El mayor mito...') cada 2 escenas.")

    ritmo_score = max(0, min(100, ritmo_score))

    # Entretenimiento, emoción y atractivo general (Broad Appeal)
    full_text = " ".join(sc.get("text", "") for sc in scenes).lower()
    emo_hits = [w for w in PALABRAS_EMOCION_HUMOR if w in full_text]
    cur_hits = [w for w in GATILLOS_CURIOSIDAD if w in full_text]
    palettes = {sc.get("palette", "default") for sc in scenes}

    ent_score = 52
    ent_ok, ent_fix = [], []
    if len(emo_hits) >= 4:
        ent_score += 22
        ent_ok.append(f"Alta carga emocional/entretenimiento ({len(emo_hits)} anclas: {', '.join(emo_hits[:5])}).")
    elif len(emo_hits) >= 2:
        ent_score += 12
        ent_fix.append("Sumar 1–2 analogías cotidianas, toques de humor o contrastes emocionales más vívidos.")
    else:
        ent_fix.append("El texto suena demasiado plano/enciclopédico; inyectar humor, drama o analogías humanas.")

    if len(cur_hits) >= 4:
        ent_score += 14
        ent_ok.append("Múltiples revelaciones sostienen el interés del espectador.")

    if len(palettes) >= 3:
        ent_score += 8
        ent_ok.append(f"Variedad atmosférica visual ({len(palettes)} paletas escénicas).")

    # Cierre participativo (pregunta en última escena)
    last_text = scenes[-1].get("text", "")
    if "?" in last_text or "¿" in last_text or "comenta" in last_text.lower() or "cuéntanos" in last_text.lower():
        ent_score += 6
        ent_ok.append("Cierre conversacional que incentiva comentarios y retención.")
    else:
        ent_fix.append("Añadir una pregunta breve al cierre para disparar comentarios orgánicos.")

    ent_score = max(0, min(100, ent_score))

    global_score = round(hook_score * 0.40 + ritmo_score * 0.30 + ent_score * 0.30)
    if global_score >= 80:
        veredicto = "VERDE · ALTO POTENCIAL DE RETENCIÓN Y ÉXITO (LISTO PARA PRODUCIR)"
    elif global_score >= 65:
        veredicto = "AMARILLO · VIABLE PERO MEJORABLE (AFILAR ANTES DE SINTETIZAR VOZ)"
    else:
        veredicto = "ROJO · ALTO RIESGO DE ABANDONO (REPLANTEAR GANCHO O ÁNGULO)"

    return {
        "titulo": data.get("title", path.stem),
        "escenas": num_scenes,
        "palabras_totales": total_words,
        "duracion_estimada_seg": round(est_seconds, 1),
        "puntajes": {
            "gancho_0_3s": hook_score,
            "ritmo_retencion": ritmo_score,
            "entretenimiento_atractivo": ent_score,
            "global": global_score,
        },
        "veredicto": veredicto,
        "fortalezas": hook_ok + ritmo_ok + ent_ok,
        "mejoras_recomendadas": hook_fix + ritmo_fix + ent_fix,
    }


def main():
    parser = argparse.ArgumentParser(description="Evaluador predictivo de guiones y ganchos virales")
    parser.add_argument("--storyboard", help="Ruta a storyboard.json del proyecto")
    parser.add_argument("--tema", help="Tema o premisa a evaluar de forma preliminar")
    parser.add_argument("--gancho", help="Frase de gancho propuesta (0-3s)")
    parser.add_argument("--json", action="store_true", help="Salida JSON estructurada")
    args = parser.parse_args()

    if args.storyboard:
        report = evaluar_storyboard(Path(args.storyboard))
    elif args.gancho or args.tema:
        texto = args.gancho or args.tema
        h_score, ok, fix = evaluar_gancho(texto)
        veredicto = "VERDE · GANCHO POTENTE" if h_score >= 80 else "AMARILLO · AFILAR GANCHO" if h_score >= 65 else "ROJO · REESCRIBIR GANCHO"
        report = {
            "tema": args.tema or "",
            "gancho": texto,
            "puntajes": {"gancho_0_3s": h_score, "global": h_score},
            "veredicto": veredicto,
            "fortalezas": ok,
            "mejoras_recomendadas": fix,
        }
    else:
        parser.print_help()
        sys.exit(1)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return

    print("\n" + "=" * 78)
    print(f"🎬 AUDITORÍA NARRATIVA Y PREDICTIVA DE ÉXITO: {report.get('titulo') or report.get('tema')}")
    print("=" * 78)
    p = report["puntajes"]
    print(f"  • Gancho (0–3s):              {p['gancho_0_3s']}/100")
    if "ritmo_retencion" in p:
        print(f"  • Ritmo y Retención:          {p['ritmo_retencion']}/100 ({report['escenas']} escenas · ~{report['duracion_estimada_seg']}s)")
        print(f"  • Entretenimiento / Atractivo:{p['entretenimiento_atractivo']}/100")
    print(f"  ▶ PUNTAJE GLOBAL:             {p['global']}/100")
    print(f"  ▶ VEREDICTO:                  {report['veredicto']}")
    if report["fortalezas"]:
        print("\n✅ Fortalezas detectadas:")
        for f in report["fortalezas"]:
            print(f"   - {f}")
    if report["mejoras_recomendadas"]:
        print("\n⚠️ Mejoras sugeridas antes de producir:")
        for m in report["mejoras_recomendadas"]:
            print(f"   - {m}")
    print("=" * 78 + "\n")


if __name__ == "__main__":
    main()
