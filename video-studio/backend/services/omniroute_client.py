import os
import json
import urllib.request
import urllib.error
import time
from typing import Dict, Any, List, Optional

_env_file = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.env"))
if os.path.exists(_env_file):
    with open(_env_file, "r", encoding="utf-8") as _file:
        for _line in _file:
            _line = _line.strip()
            if _line and not _line.startswith("#") and "=" in _line:
                _key, _value = _line.split("=", 1)
                os.environ.setdefault(_key.strip(), _value.strip())

OMNIROUTE_BASE_URL = os.getenv("OMNIROUTE_BASE_URL", "https://omniroute-api.azurewebsites.net").rstrip("/")
OMNIROUTE_API_KEY = os.getenv("OMNIROUTE_API_KEY", "")
OMNIROUTE_MODEL = os.getenv("OMNIROUTE_MODEL", "auto/best-fast")

class OmniRouteClient:
    """
    Cliente seguro para interactuar con OmniRoute en Azure.
    Maneja generación de guiones largos, división en actos, coherencia visual
    y fallback robusto si el proxy se demora o está en arranque en frío.
    """

    @classmethod
    def calculate_scene_count(cls, target_seconds: int) -> int:
        """Planifica unas escenas cada 12 s, manteniendo manejable un storyboard de una hora."""
        if target_seconds <= 0:
            raise ValueError("La duración objetivo debe ser positiva")
        return min(300, max(4, (target_seconds + 11) // 12))

    @classmethod
    def _chat(cls, prompt: str, *, json_output: bool = False, max_tokens: int = 6000) -> str:
        """Llama al modelo configurado en OmniRoute; no oculta fallos con contenido ficticio."""
        if not OMNIROUTE_API_KEY:
            raise RuntimeError("OMNIROUTE_API_KEY no está configurada")
        payload: Dict[str, Any] = {
            "model": OMNIROUTE_MODEL,
            "messages": [
                {"role": "system", "content": "Eres un asistente de producción audiovisual. Sigue el formato solicitado exactamente."},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.7,
            "max_tokens": max_tokens,
        }
        if json_output:
            payload["response_format"] = {"type": "json_object"}
        req = urllib.request.Request(
            f"{OMNIROUTE_BASE_URL}/v1/chat/completions",
            data=json.dumps(payload).encode("utf-8"),
            headers={"Authorization": f"Bearer {OMNIROUTE_API_KEY}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=90) as response:
            data = json.loads(response.read().decode("utf-8"))
        return data["choices"][0]["message"]["content"].strip()

    @classmethod
    def generate_script(cls, topic: str, duration_seconds: int, style: str) -> Dict[str, Any]:
        words = round(duration_seconds * 2.2)
        prompt = f"""Escribe un guion audiovisual en español sobre: {topic!r}.
Duración objetivo: {duration_seconds} segundos. Extensión orientativa: {words} palabras (130 palabras por minuto).
Estilo: {style}. Estructura con gancho, desarrollo progresivo, transiciones y cierre. Usa afirmaciones verificables, evita inventar datos y marca [VERIFICAR] donde falte fuente.
Devuelve JSON con campos title, topic, duration_seconds, narration (guion completo) y acts (lista de objetos con title y summary). No crees storyboard ni recursos visuales todavía."""
        # Más de cinco minutos: un solo JSON tiende a exceder los límites de salida
        # habituales. Generamos por actos en fragmentos acotados y los unimos.
        if duration_seconds > 300:
            return cls._generate_long_script(topic, duration_seconds, style)
        result = json.loads(cls._chat(prompt, json_output=True, max_tokens=max(3000, min(12000, words * 3))))
        narration = result.get("narration")
        if not isinstance(narration, str) or not narration.strip():
            raise ValueError("OmniRoute devolvió un guion vacío o inválido")
        return result

    @classmethod
    def _generate_long_script(cls, topic: str, duration_seconds: int, style: str) -> Dict[str, Any]:
        act_seconds = 300
        act_count = (duration_seconds + act_seconds - 1) // act_seconds
        acts = []
        narration_parts = []
        remaining_words = round(duration_seconds * 130 / 60)
        for index in range(act_count):
            seconds = min(act_seconds, duration_seconds - index * act_seconds)
            target_words = round(remaining_words * seconds / (duration_seconds - index * act_seconds))
            remaining_words -= target_words
            prompt = f"""Escribe el acto {index + 1} de {act_count} de un guion audiovisual en español sobre {topic!r}.
Duración de este acto: {seconds} segundos; aproximadamente {target_words} palabras.
Estilo: {style}. Mantén continuidad narrativa, no repitas introducción/cierre salvo en primer/último acto. Divide en bloques breves con transiciones naturales. Usa afirmaciones verificables y marca [VERIFICAR] cuando aplique.
Devuelve JSON con title, summary y narration (texto completo del acto)."""
            part = json.loads(cls._chat(prompt, json_output=True, max_tokens=6000))
            narration = part.get("narration")
            if not isinstance(narration, str) or not narration.strip():
                raise ValueError(f"OmniRoute devolvió vacío el acto {index + 1} del guion")
            acts.append({"title": str(part.get("title") or f"Acto {index + 1}"), "summary": str(part.get("summary") or "")})
            narration_parts.append(narration.strip())
        return {"title": topic, "topic": topic, "duration_seconds": duration_seconds,
                "narration": "\n\n".join(narration_parts), "acts": acts}

    @classmethod
    def generate_storyboard_from_script(cls, script: Dict[str, Any], style: str) -> Dict[str, Any]:
        scene_count = cls.calculate_scene_count(int(script.get("duration_seconds", 60)))
        narration = script.get("narration", "")
        if not isinstance(narration, str) or not narration.strip():
            raise ValueError("El guion aprobado no contiene narración")
        # Storyboards grandes se generan en lotes de 20 escenas para evitar truncado JSON.
        acts = script.get("acts") or []
        scenes = []
        visual_theme = ""
        batch_size = 20
        narration_words = narration.split()
        for batch_start in range(0, scene_count, batch_size):
            batch_count = min(batch_size, scene_count - batch_start)
            word_start = len(narration_words) * batch_start // scene_count
            word_end = len(narration_words) * (batch_start + batch_count) // scene_count
            text = " ".join(narration_words[word_start:word_end])
            continuity = json.dumps(scenes[-5:], ensure_ascii=False) if scenes else "ninguna; este es el primer lote"
            prompt = f"""Crea el lote de escenas {batch_start + 1} a {batch_start + batch_count} de un storyboard completo de {scene_count} escenas para animación 2D SVG en Remotion.
Estilo: {style}. Tema: {script.get('topic', script.get('title', ''))}. Actos: {json.dumps(acts, ensure_ascii=False)}.
Fragmento consecutivo asignado exclusivamente a este lote (divide este fragmento de forma consecutiva y fiel; no inventes ni omitas contenido): {text}
Mantén continuidad con las cinco escenas anteriores, sin repetirlas: {continuity}
Devuelve exactamente {batch_count} escenas con id global consecutivo desde {batch_start + 1}, act, title, narrative_text (fragmento literal consecutivo), visual_description, svg_prompt (ilustración vectorial original, formas sólidas y composición clara), callout y bg_color.
Cada escena representa unos 12 segundos. No uses stickers existentes ni referencias a SVG predeterminados. Responde JSON con visual_theme y scenes."""
            result = json.loads(cls._chat(prompt, json_output=True, max_tokens=12000))
            batch = result.get("scenes")
            if not isinstance(batch, list) or len(batch) != batch_count:
                raise ValueError(f"Storyboard inválido en lote {batch_start // batch_size + 1}: se esperaban {batch_count} escenas")
            if not visual_theme:
                visual_theme = str(result.get("visual_theme") or "")
            scenes.extend(batch)
        for index, scene in enumerate(scenes, 1):
            if not isinstance(scene, dict) or not all(isinstance(scene.get(key), str) and scene[key].strip() for key in ("title", "narrative_text", "visual_description")):
                raise ValueError(f"Escena {index} incompleta en el storyboard")
            scene["id"] = index
        return {"visual_theme": visual_theme, "scenes": scenes}

    @classmethod
    def generate_scene_svg(cls, description: str, theme: str) -> str:
        raw = cls._chat(
            f"Genera SOLO un elemento SVG completo (sin Markdown ni explicación), viewBox='0 0 1080 900', para esta escena: {description}\nEstilo común: {theme}. Ilustración vectorial original con varios elementos diferenciados y colores expresivos. Organiza la ilustración en 4 a 8 grupos <g> directos dentro de <svg>, separando fondo, sujeto, objetos y detalles para permitir parallax determinista por capas. No incluyas texto, scripts, enlaces, imágenes raster ni recursos externos.",
            max_tokens=5000,
        )
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
        return raw

    @classmethod
    def generate_storyboard(
        cls,
        topic: str,
        target_duration_seconds: int = 60,
        style: str = "curiosity"
    ) -> Dict[str, Any]:
        """
        Genera el storyboard completo. Intenta llamar a OmniRoute con timeout acotado
        y utiliza el motor estructurado en caso de indisponibilidad.
        """
        scene_count = cls.calculate_scene_count(target_duration_seconds)

        # Intentar con OmniRoute si hay clave
        if OMNIROUTE_API_KEY:
            try:
                storyboard = cls._call_omniroute_llm(topic, target_duration_seconds, scene_count, style)
                if storyboard and "scenes" in storyboard and len(storyboard["scenes"]) > 0:
                    return storyboard
            except Exception as e:
                print(f"[OmniRouteClient Aviso] Falló LLM en OmniRoute ({e}). Activando generador estructurado de alta retención.")

        # Fallback autónomo estructurado
        return cls._generate_structured_storyboard(topic, target_duration_seconds, scene_count, style)

    @classmethod
    def _call_omniroute_llm(
        cls,
        topic: str,
        target_duration: int,
        scene_count: int,
        style: str
    ) -> Optional[Dict[str, Any]]:
        url = f"{OMNIROUTE_BASE_URL}/v1/chat/completions"
        prompt = f"""Eres el director audiovisual principal de una agencia con IA.
Crea un storyboard profesional para un video de {target_duration} segundos en {scene_count} escenas sobre: "{topic}".
Estilo narrativo: {style}.

Reglas de Oro:
1. Divide la historia en 3 Actos (Acto 1: Hook intrigante 0-10s; Acto 2: Desarrollo, giros y revelaciones; Acto 3: Clímax, conclusión y llamada a la acción).
2. Genera EXACTAMENTE {scene_count} escenas continuas y fluidas.
3. Para cada escena define:
   - title: Nombre descriptivo.
   - narrative_text: Guion exacto a narrar en voz en off (en español dinámico y conversacional).
   - visual_description: Prompt visual detallado para ilustrar la escena (personajes, iluminación, colores).
   - callout: 2 a 4 palabras clave en mayúsculas para el banner en pantalla.
   - visual_type: "image_ai" o "doodle_svg" o "motion_card".
   - sticker: nombre de apoyo ("idea", "question", "brain", "money", "danger", "shock", "arrow_up", "eye_patch").
   - sfx: sonido de entrada ("whoosh", "pop", "ding", "click").
   - bg_color: color de fondo (#FEF3C7, #EDE9FE, #E0F2FE, #FCE7F3, #DCFCE7, #F8FAFC).

Responde ÚNICAMENTE en JSON válido con este formato:
{{
  "topic": "{topic}",
  "target_duration_seconds": {target_duration},
  "style": "{style}",
  "visual_theme": "Descripción del estilo artístico uniforme para todas las escenas",
  "scenes": [
    {{
      "id": 1,
      "act": 1,
      "title": "...",
      "narrative_text": "...",
      "visual_description": "...",
      "callout": "...",
      "visual_type": "image_ai",
      "sticker": "question",
      "sfx": "whoosh",
      "bg_color": "#FEF3C7"
    }}
  ]
}}"""

        payload = {
            "model": "auto/chat",
            "messages": [
                {"role": "system", "content": "Eres un asistente de producción audiovisual. Responde siempre en JSON puro."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 4000
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {OMNIROUTE_API_KEY}",
                "Content-Type": "application/json"
            }
        )

        with urllib.request.urlopen(req, timeout=25) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            content = data["choices"][0]["message"]["content"]
            # Limpiar posibles markdown blocks
            clean_json = content.strip()
            if clean_json.startswith("```json"):
                clean_json = clean_json[7:]
            if clean_json.startswith("```"):
                clean_json = clean_json[3:]
            if clean_json.endswith("```"):
                clean_json = clean_json[:-3]
            res = json.loads(clean_json.strip())
            return res

    @classmethod
    def _generate_structured_storyboard(
        cls,
        topic: str,
        target_duration: int,
        scene_count: int,
        style: str
    ) -> Dict[str, Any]:
        """Generador heurístico multinivel que escala a 5 o 10 minutos adaptando el guion por actos."""
        clean_title = topic.replace("¿", "").replace("?", "").replace("¡", "").replace("!", "").strip()
        bg_colors = ["#FEF3C7", "#EDE9FE", "#E0F2FE", "#FCE7F3", "#DCFCE7", "#F8FAFC"]
        stickers = ["question", "idea", "brain", "shock", "danger", "money", "arrow_up", "eye_patch"]
        sfxs = ["whoosh", "pop", "ding", "click"]

        scenes = []
        for i in range(1, scene_count + 1):
            act = 1 if i <= max(2, scene_count // 4) else (2 if i <= (scene_count * 3) // 4 else 3)
            bg = bg_colors[(i - 1) % len(bg_colors)]
            stk = stickers[(i - 1) % len(stickers)]
            sfx = sfxs[(i - 1) % len(sfxs)]

            if i == 1:
                title = "El Gancho Inicial"
                text = f"¡Resulta que casi todo lo que creías saber sobre {clean_title} oculta un secreto que muy pocos conocen!"
                callout = "¡NO ES LO QUE CREES!"
                vis_desc = f"Primer plano de ilustración conceptual intrigante sobre {clean_title}, atmósfera de misterio con iluminación lateral dorada."
            elif i == 2:
                title = "El Origen Oculto"
                text = f"Para entender lo que realmente pasó, tenemos que viajar al momento exacto en que todo comenzó a cambiar."
                callout = "EL INICIO"
                vis_desc = f"Escenario histórico detallado que recrea el descubrimiento inicial de {clean_title} con paleta de tonos tierra."
            elif i == scene_count - 1:
                title = "La Consecuencia"
                text = f"El impacto fue tan masivo que transformó las costumbres de millones de personas sin que se dieran cuenta."
                callout = "IMPACTO MUNDIAL"
                vis_desc = f"Composición visual con un mapa de conexiones globales y datos flotantes de alto contraste."
            elif i == scene_count:
                title = "Remate y Llamado a la Acción"
                text = f"¿Tú ya sospechabas la verdad detrás de esta historia? Cuéntame tu opinión en los comentarios y sígueme para más descubrimientos."
                callout = "¿QUÉ OPINAS TÚ?"
                vis_desc = f"Personaje animado estilo doodle guiñando el ojo con una pancarta interactiva invitando al debate."
            else:
                title = f"Revelación {i}"
                text = f"En este punto, los registros revelan un dato desconcertante: no fue casualidad, sino una decisión meticulosamente calculada."
                callout = f"DATO CLAVE #{i}"
                vis_desc = f"Ilustración detallada de un laboratorio o sala de estrategia con planos y documentos sobre {clean_title}."

            scenes.append({
                "id": i,
                "act": act,
                "title": title,
                "narrative_text": text,
                "visual_description": vis_desc,
                "callout": callout,
                "visual_type": "image_ai" if i % 2 == 1 else "doodle_svg",
                "sticker": stk,
                "sfx": sfx,
                "bg_color": bg
            })

        return {
            "topic": topic,
            "target_duration_seconds": target_duration,
            "style": style,
            "visual_theme": f"Estilo moderno doodle-art y motion graphics contemporáneos sobre {topic}",
            "scenes": scenes
        }
