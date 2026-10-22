import os
import json
import random
from typing import Dict, Any, List

AVAILABLE_STICKERS = ["idea", "question", "brain", "money", "danger", "shock", "arrow_up", "eye_patch", "ice_cream", "milk", "freeze", "fire", "microscope"]
AVAILABLE_SFX = ["pop", "whoosh", "ding", "click"]
BG_PALETTE = ["#F8FAFC", "#FEF3C7", "#EDE9FE", "#E0F2FE", "#FCE7F3", "#DCFCE7"]

def generate_storyboard(topic: str, style: str = "curiosity", target_duration: int = 30) -> Dict[str, Any]:
    """
    Genera un storyboard estructurado con gancho de alta retención (0-3s),
    desarrollo en escenas y llamado a la acción, optimizado para el estilo Resultaaquee.
    """
    topic_clean = topic.strip()
    
    # Comprobar si hay API Key para generación con LLM externo
    openai_key = os.getenv("OPENAI_API_KEY")
    if openai_key:
        try:
            return generate_storyboard_llm(topic_clean, style, openai_key)
        except Exception as e:
            print(f"[Aviso] Falló generación con OpenAI ({e}), usando motor heurístico local.")

    # Generación nativa estructurada basada en fórmulas de alta retención (Reels Scripting)
    return generate_storyboard_heuristic(topic_clean, style)

def generate_storyboard_heuristic(topic: str, style: str) -> Dict[str, Any]:
    """
    Generador heurístico de alta retención: Hook -> Giro inesperado -> Explicación visual -> Remate.
    """
    # Limpiar signos
    clean_title = topic.replace("¿", "").replace("?", "").replace("¡", "").replace("!", "")
    
    hook_phrase = f"¡Resulta que lo que te contaron sobre {clean_title} es completamente falso!"
    scene2_phrase = f"Durante años creímos una explicación simple, pero la realidad oculta algo fascinante."
    scene3_phrase = f"Cuando los expertos lo descubrieron, cambiaron por completo las reglas del juego."
    cta_phrase = f"¿Tú ya conocías este secreto? Sígueme para más historias que nadie te cuenta."
    
    # Detección de stickers contextualmente
    s1_sticker = "shock" if "error" in topic.lower() or "secreto" in topic.lower() else "question"
    s2_sticker = "brain" if "mente" in topic.lower() or "cerebro" in topic.lower() else "idea"
    s3_sticker = "money" if "dinero" in topic.lower() or "negocio" in topic.lower() else "arrow_up"
    s4_sticker = "eye_patch" if "pirata" in topic.lower() or "ojo" in topic.lower() else "idea"

    scenes = [
        {
            "id": 1,
            "title": "El Gancho (0-3s)",
            "text": hook_phrase,
            "callout": "¡NO ES LO QUE CREES!",
            "sticker": s1_sticker,
            "sfx": "whoosh",
            "bg_color": "#FEF3C7"
        },
        {
            "id": 2,
            "title": "El Giro Inesperado",
            "text": scene2_phrase,
            "callout": "EL SECRETO",
            "sticker": s2_sticker,
            "sfx": "pop",
            "bg_color": "#EDE9FE"
        },
        {
            "id": 3,
            "title": "La Revelación",
            "text": scene3_phrase,
            "callout": "¡CAMBIO TOTAL!",
            "sticker": s3_sticker,
            "sfx": "ding",
            "bg_color": "#E0F2FE"
        },
        {
            "id": 4,
            "title": "Remate y Llamado a la Acción",
            "text": cta_phrase,
            "callout": "¿TÚ QUÉ OPINAS?",
            "sticker": s4_sticker,
            "sfx": "click",
            "bg_color": "#FCE7F3"
        }
    ]

    full_script = " ".join([s["text"] for s in scenes])

    return {
        "topic": topic,
        "style": style,
        "hook": hook_phrase,
        "full_script": full_script,
        "scenes": scenes,
        "metadata": {
            "sfx_available": AVAILABLE_SFX,
            "stickers_available": AVAILABLE_STICKERS,
            "bg_palette": BG_PALETTE
        }
    }

def generate_storyboard_llm(topic: str, style: str, api_key: str) -> Dict[str, Any]:
    """Generación opcional mediante OpenAI API si el usuario proporciona su clave."""
    import urllib.request
    
    prompt = f"""Eres el guionista principal del canal @resultaaquee. Escribe un guion viral en español de 30 segundos sobre: "{topic}".
Estructura obligatoria en 4 escenas con alta retención:
1. Gancho provocador (comienza con "¡Resulta que...!")
2. Giro o dato curioso sorprendente.
3. Detalle impactante o explicación visual.
4. Remate cómico o pregunta de interacción.

Responde ÚNICAMENTE en JSON válido con esta estructura:
{{
  "topic": "{topic}",
  "style": "{style}",
  "hook": "...",
  "full_script": "...",
  "scenes": [
    {{
      "id": 1,
      "title": "...",
      "text": "...",
      "callout": "PALABRA CLAVE",
      "sticker": "uno de {AVAILABLE_STICKERS}",
      "sfx": "uno de {AVAILABLE_SFX}",
      "bg_color": "uno de {BG_PALETTE}"
    }}
  ]
}}"""
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps({
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": prompt}],
            "response_format": {"type": "json_object"}
        }).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        res_json = json.loads(data["choices"][0]["message"]["content"])
        res_json["metadata"] = {
            "sfx_available": AVAILABLE_SFX,
            "stickers_available": AVAILABLE_STICKERS,
            "bg_palette": BG_PALETTE
        }
        return res_json
