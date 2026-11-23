---
name: estrategia-narrativa-ganchos-retencion
description: Estrategia narrativa, ingeniería de ganchos (0-3s), diseño de historias de alto entretenimiento y evaluación predictiva de éxito para videos informativos, curiosidades y storytelling multitemático (ciencia, historia, cultura pop, psicología, misterios). Evalúa si una temática y su guion son atractivos, entretenidos y capaces de retener audiencia antes de gastar créditos de voz o animar. Incluye el evaluador CLI scripts/evaluar_guion.py con matriz de 100 puntos.
---

# Estrategia Narrativa, Ganchos y Evaluación Predictiva de Éxito

Esta skill gobierna el **qué contamos, cómo enganchamos y por qué la audiencia se queda hasta el final** (independiente del motor de animación). Se ejecuta **antes** de generar locución TTS o programar escenas, garantizando que cada video sea informativo, entretenido, narrativamente sólido y atractivo para audiencias amplias de múltiples intereses.

---

## 1. Evaluador de Atractivo y Viabilidad Temática (Broad Appeal Check)
Antes de redactar el guion, evaluar el tema en 5 dimensiones (20 pts c/u = 100 pts):
1. **Amplitud de atracción (*Broad Appeal*):** ¿Le importa o intriga a alguien que NO es experto en el nicho? Si es demasiado técnico o cerrado, traducirlo a una pregunta cotidiana universal (*ej. "Reflexión especular en plata" → "¿De qué color es realmente un espejo?"*).
2. **Brecha de curiosidad (*Curiosity Gap*):** ¿Existe un dato contraintuitivo, un mito roto, un secreto oculto o una pregunta que el cerebro necesite cerrar?
3. **Potencial emocional y de entretenimiento:** ¿Despierta asombro, risa, indignación justa, nostalgia o escalofrío? La información pura sin emoción o humor aburre.
4. **Claridad visual y dramatizable:** ¿Se puede mostrar con acciones de nuestros personajes cartoon, contrastes visuales, recortes reales o fondos IA de Gemini sin depender de paredes de texto?
5. **Relevancia y frescura de ángulo:** Si el tema es conocido, ¿qué giro fresco o ángulo inesperado lo diferencia del resto del feed?

---

## 2. Laboratorio de Ganchos (Primeros 0 a 3 Segundos)
**Regla de oro:** Prohibido abrir con saludos o preámbulos (*"Hola amigos"*, *"Bienvenidos"*, *"Hoy vamos a hablar de..."*). Empezar directamente en la **Palabra 1** abriendo tensión o curiosidad.

### 7 Arquetipos Probados de Gancho
1. **Verdad Contraintuitiva:** *"Todo lo que te enseñaron sobre [X] está al revés..."*
2. **Pregunta Imposible Cotidiana:** *"¿Alguna vez te preguntaste de qué color es un espejo?"*
3. **Secreto Negativo (Aversión a la pérdida):** *"Este hábito diario está saboteando tu [X] sin que lo notes..."*
4. **Giro Oculto en Algo Familiar:** *"Durante décadas reímos con [X]... hasta que su creador escribió un libro que borró las risas."*
5. **In Media Res (Acción instantánea):** *"En menos de un femtosegundo, un electrón destruye la luz y fabrica otra nueva..."*
6. **Brecha Numérica / Escala Brutal:** *"Basta una capa mil veces más fina que un cabello para que puedas verte cada mañana..."*
7. **Promesa de Revelación Escalonada:** *"Hay tres secretos detrás de [X], y el último cambia cómo miras tu propia casa."*

### Matriz de Puntuación de Gancho (100 pts · Umbral Mínimo: 80/100)
| Dimensión | Qué exige | Puntos |
| :--- | :--- | :---: |
| **Contraste visual inmediato (Scroll-Stop)** | El primer fotograma tiene acción, contraste alto o tensión visual clara. | 20 |
| **Claridad antes que complejidad** | Se entiende de qué mundo trata en < 2 segundos, sin jerga académica árida. | 20 |
| **Gatillo de curiosidad (Open Loop)** | Abre una pregunta/secreto que obliga mentalmente a esperar el cierre. | 20 |
| **Traducción popular (Broad Appeal)** | Cualquier persona en scroll casual siente que el tema le incumbe. | 15 |
| **Resonancia emocional / humor** | Activa sorpresa, humor, nostalgia, asombro o intriga real. | 15 |
| **Sinergia audio-visual-texto** | El dato visual complementa la voz en vez de repetir literalmente cada palabra. | 10 |

*Si el gancho puntúa < 80, redactar 3 variantes alternativas y elegir la de mayor impacto antes de pasar a producción.*

---

## 3. Arquitectura de Retención y Entretenimiento (Anti-Aburrimiento)
1. **Escalada Obstáculo → Giro → Revelación:** Cada 2 o 3 escenas debe cerrarse un mini-bucle y abrirse el siguiente (*re-hook*), evitando el "valle de aburrimiento" a mitad del video.
2. **Interrupciones de patrón (*Pattern Interrupts*) cada 4–8 segundos:** Cambio de plano, cambio de pose/expresión de los personajes cartoon, entrada de contador/píldora, recorte real, fondo Gemini o golpe de SFX sincronizado.
3. **Ritmo hablado para el oído:** Frases cortas (12–22 palabras), verbos activos, analogías visuales y cero párrafos tipo Wikipedia.
4. **Fórmula Edutainment:** Alternar **Dato sorprendente + Analogía cotidiana o toque de humor/emoción + Impacto visual**.
5. **Cierre que invita a conversar:** Terminar con una revelación memorable o reflexión que genere debate natural en comentarios (en vez de un simple "dale like" vacío).

---

## 4. Evaluador Automático Pre-Producción (`scripts/evaluar_guion.py`)
Antes de ejecutar `prepare.py` (y gastar créditos de voz), ejecutar obligatoriamente el evaluador sobre el `storyboard.json` del proyecto:

```bash
python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py \
  --storyboard "video-studio/projects/<fecha>/<slug>/storyboard.json"
```

O para evaluar una idea/gancho preliminar antes de redactar:

```bash
python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py \
  --tema "¿Por qué los aviones dejan estelas blancas?" \
  --gancho "¿Sabías que esas líneas blancas en el cielo pueden crear tormentas reales?"
```

### Semáforo Predictivo de Éxito
- **VERDE (`>= 80/100`):** Alto potencial de retención, entretenimiento y claridad. Aprobado para síntesis de voz y animación.
- **AMARILLO (`65–79/100`):** Viable pero con fricción; aplicar las correcciones sugeridas en el gancho, re-ganchos o densidad de escenas antes de sintetizar audio.
- **ROJO (`< 65/100`):** Alto riesgo de abandono temprano; replantear el ángulo temático o reescribir las primeras dos escenas.
