# 🎬 V2-VIDEOS-IA · Plataforma Autónoma de Estrategia, Preproducción y Producción de Video con IA

> **Sistema integral dividido en dos fases: (1) Preproducción estratégica operada como un Social Media Manager profesional —ideación guiada, investigación activa en navegador de videos exitosos, validación de mercado y guion base— y (2) Producción audiovisual 2D+3D con Remotion, React y agentes especializados.**

---

## 🌟 ¿Qué es esta herramienta?

**V2-VIDEOS-IA** convierte cualquier idea inicial en una pieza audiovisual con fundamento real de mercado, alto potencial de retención y acabado profesional:

1. **Preproducción como Social Media Manager (Dos Prompts Maestros):** Antes de gastar tiempo o créditos en producir, el sistema guía tu idea con preguntas estratégicas, navega en internet para estudiar videos exitosos reales, analiza ganchos y estructuras narrativas ganadoras, valida si el video será entretenido y entrega un **guion base auditado (`>= 80/100`)**.
2. **Estándar Visual Cartoon Editorial 2D+3D y Animación Viva:** Rigging vectorial con tinta negra uniforme (`#0b0d10`), rellenos *flat cel*, cinemática inversa (IK), deformación elástica (*squash & stretch*) y alternativas como Kiwi/Kurzgesagt 3D Vivo o Estilo Documental Vox.
3. **Orquestación de Agentes y 164 Habilidades Canónicas:** Un equipo coordinado por el Asistente Principal que integra **12 skills auditadas de preproducción, estrategia viral e investigación web**, la **Tríada de Diseño Sonoro Pro (`earshot` + `real-sound` + `real-sfx` + `openverse-audio`)**, y la suite de **Remotion** y **Motion Design**.
4. **Curaduría Acústica Anti-Repetición, Oídos Locales y 5M+ Audios Libres:** Biblioteca local de **414 pistas musicales y SFX** (`169` SFX indexados en `real-sfx` + `78` cues UI `uisfx` CC0), acceso directo a **5M+ audios abiertos en Openverse**, medición exacta LUFS/dBTP y síntesis limpia con **Earshot**, y masterización EBU R128.

---

## 🎯 Flujo de Trabajo Recomendado (Idea → Mercado → Guion Base → Producción)

```text
[Tu idea inicial: "quiero hacer un video sobre los perros"]
                         │
                         ▼
   ┌────────────────────────────────────────────────────────────┐
   │  PROMPT MAESTRO 1 · Ideación Guiada y Validación           │
   │  • Preguntas estratégicas (objetivo, audiencia, tono, red) │
   │  • 5–7 ángulos filmables + filtro de entretenimiento       │
   │  • Salida: Brief Validado + "Qué NO haremos"               │
   └────────────────────────────────────────────────────────────┘
                         │
                         ▼
   ┌────────────────────────────────────────────────────────────┐
   │  PROMPT MAESTRO 2 · Social Media Manager Integral          │
   │  • Navegador / Web: investiga videos exitosos y outliers   │
   │  • Extrae ganchos 0–3s, narrativa, retención y humor       │
   │  • Evalúa mercado/viabilidad + 6–8 ganchos de 3 capas      │
   │  • Entrega: Guion Base validado (evaluar_guion.py >= 80)   │
   │    + Packaging social (título, portada, copy, hashtags)    │
   │  • NO genera el archivo de video final en esta etapa       │
   └────────────────────────────────────────────────────────────┘
                         │  (Solo cuando apruebes el guion base)
                         ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 2 · Producción Audiovisual (Herramientas dedicadas)  │
   │  • video-studio / Remotion / TTS / Render 9:16 y 16:9      │
   └────────────────────────────────────────────────────────────┘
```

---

## 🚀 ¿Cómo Usar Esta Herramienta? (Los 2 Prompts Maestros + Producción)

### Método 1: Preproducción Estratégica Asistida por IA (Recomendado — 2 Prompts Maestros)

Copia y pega el prompt que corresponda a tu momento actual en tu agente de IA (**Antigravity IDE**, **Cursor**, **Claude Code**, **VS Code** o CLI). **Ambos prompts se concentran exclusivamente en ideación, validación de mercado y base del guion** (no generan el video final).

---

#### 💡 Prompt Maestro 1: Ideación Guiada y Validación (Para partir de una idea simple)

**Cuándo usarlo:** Cuando tienes una idea suelta o muy general (por ejemplo: *"quiero hacer un video sobre los perros"*) y quieres que el asistente te haga las preguntas estratégicas adecuadas para aterrizar el enfoque, público, tono, formato y viabilidad.

```text
Actúa como el Asistente Principal definido en Agencia_Principal/asistente-principal.md en MODO A (Ideación Guiada y Validación), operando como mi gestor profesional de redes sociales (Social Media Manager) y apoyándote en las skills `preproduccion-social-video`, `interview-me`, `idea-refine`, `viral-short-form-ideas` y `customer-research`.

Mi idea inicial es: "[escribe aquí tu idea inicial, por ejemplo: quiero hacer un video sobre los perros]"

Reglas obligatorias para esta sesión:
1. NO escribas todavía el guion definitivo ni generes el archivo de video final ni ejecutes scripts de producción/renderizado.
2. Primero hazme las preguntas estratégicas imprescindibles (de forma clara, ordenada y sin abrumarme) para definir:
   - Objetivo principal del video (alcance, guardados, envíos, debate o autoridad).
   - Público objetivo exacto y qué curiosidad, dolor o mito tiene hoy.
   - Plataforma y formato (TikTok, Instagram Reels, YouTube Shorts 9:16 o YouTube 16:9) y duración ideal.
   - Tono y enfoque de entretenimiento (curiosidad sorprendente, verdad contraintuitiva, humor, historia emocional, comparativa o ranking).
   - Restricciones o identidad de marca a respetar.
3. Con mis respuestas, transforma mi idea inicial en 5 a 7 ángulos concretos y filmables, evalúa su atractivo general (Broad Appeal), brecha de curiosidad, nivel de entretenimiento y viabilidad real, y recomiéndame el Top 2 con justificación de Social Media Manager.
4. Cierra entregándome un Brief Validado (incluyendo explícitamente "Qué NO haremos") y pregúntame si confirmo ese enfoque para pasar a investigación de mercado y guion base.
```

---

#### 📊 Prompt Maestro 2: Asistente Principal de Creación y Estrategia (Social Media Manager Integral)

**Cuándo usarlo:** Cuando ya validaste tu enfoque (o en tu creación recurrente de nuevos videos) y quieres que el asistente principal actúe como tu encargado de redes sociales: investigue en internet videos similares exitosos con el navegador, analice qué ganchos y dinámicas funcionan, evalúe si el video será entretenido y te entregue el **guion base completo y empaquetado** listo para pasar a producción.

```text
Actúa como el Asistente Principal definido en Agencia_Principal/asistente-principal.md en MODO B (Creación y Estrategia Integral de Preproducción), operando como mi Social Media Manager dedicado junto con el agente de redes sociales y el agente estratega narrativo (`preproduccion-social-video`, `niche-research`, `yt-viral`, `content-strategy`, `social`, `viral-hooks`, `viral-short-form`, `viral-captions-and-ctas`, `yt-script`, `yt-package`, `estrategia-narrativa-ganchos-retencion` y `post-scorer`).

Tema / Brief / Nicho para el nuevo video: "[escribe aquí el Brief confirmado o el tema que quieres trabajar]"
Plataforma(s) y duración objetivo: "[ej.: TikTok / Reels / Shorts 9:16 de 60 segundos]"

Ejecuta este flujo completo de preproducción SIN generar ni renderizar el archivo de video final:
1. Investigación activa en navegador e internet: cuando dispongas de navegador o búsqueda web, investiga videos similares que ya hayan tenido éxito y tendencias recientes en YouTube, TikTok, Reels, Reddit o Google. Extrae patrones verificables (sin inventar datos ni enlaces): videos outliers que superen el promedio de su canal (usando `swipe.py` si recolectas >= 4 videos por canal), ganchos de 0–3 segundos, estructura narrativa, dinámicas de retención y qué hace entretenido el contenido. Traduce esos hallazgos en recomendaciones accionables y define qué nos diferenciará (Information-Gain Gate).
2. Diagnóstico de mercado y entretenimiento: clasifica la pieza (Buscable, Compartible o Híbrida), evalúa si será genuinamente entretenida y emite un veredicto de viabilidad (ALTA / MEDIA CON AJUSTES / BAJA — PIVOTAR).
3. Laboratorio de ganchos (0–3s): diseña 6 a 8 ganchos en al menos 3 arquetipos distintos detallando sus 3 capas simultáneas (Gancho Verbal sin saludos genéricos + Gancho Visual del primer fotograma + Texto en Pantalla de 3–6 palabras) y recomienda el ganador.
4. Base completa del guion validada: estructura el guion escena por escena (6–10s por escena) con tensión inicial, re-ganchos cada 2 escenas, ritmo hablado natural sin clichés de IA, notas `[EN PANTALLA: ...]`, sugerencias selectivas de apoyo visual y cierre conversacional con un único CTA libre de engagement bait. Audita el guion con `evaluar_guion.py` hasta obtener VERDE (>= 80/100).
5. Empaquetado social listo para publicar: propón 3 combinaciones de Título + Texto de Portada (sin repetir palabras, validando longitud con `title.py`), copy SEO listo para copiar y pegar (validado con `post-scorer >= 75/100`), 3–5 hashtags de nicho y comentario fijado.
6. Al finalizar, ofrece guardar el entregable en `video-studio/mis-temas/preproduccion-<slug>.md` y pregúntame si ajustamos algo o si autorizo pasar a la Fase 2 de producción audiovisual.
```

---

#### 🎬 Paso Opcional (Fase 2): Pasar el Guion Base Aprobado a Producción Audiovisual

Cuando ya tengas el guion base validado (`video-studio/mis-temas/preproduccion-<slug>.md`) y decidas producir el archivo MP4 con el motor de `video-studio` / Remotion:

```text
Actúa como el asistente principal en Agencia_Principal/asistente-principal.md para pasar a Fase 2 (producción audiovisual) con este guion aprobado: video-studio/mis-temas/preproduccion-[slug].md
```

---

### 💡 Ejemplos Prácticos de Ejecución

| Escenario | Qué envías | Qué entrega el Asistente |
| :--- | :--- | :--- |
| **Idea en bruto (Prompt Maestro 1)** | *"quiero hacer un video sobre los perros"* | Hace 5 preguntas estratégicas (objetivo, público, red, tono, límites), convierte la idea en 6 ángulos filmables (ej. *"3 gestos diarios que estresan a tu perro sin que lo notes"*), evalúa atractivo/entretenimiento y confirma un **Brief Validado** con lista *"Qué NO haremos"*. |
| **Creación recurrente con investigación web (Prompt Maestro 2)** | Brief confirmado *"3 gestos diarios que estresan a tu perro — Reels/TikTok 60s"* | Navega en YouTube/TikTok/Reddit para estudiar videos exitosos reales del tema, extrae ganchos y dinámicas de retención ganadoras, valida viabilidad (**ALTA · Híbrido Buscable/Compartible**), propone 6–8 ganchos de 3 capas, redacta el guion escena por escena auditado en **VERDE (`>= 80/100`)** con `evaluar_guion.py`, y entrega título/portada (`title.py`), copy SEO (`post-scorer`), hashtags y comentario fijado. |

---

### Método 2: Plataforma Web (Dashboard & Editor Multipista — Fase 2 Producción)

Para gestionar proyectos de producción, previsualizar hojas de contacto y explorar la API:

```bash
cd video-studio
./start.sh
```

* 🖥️ **Frontend Dashboard**: [http://localhost:5173](http://localhost:5173) (Pestaña "Proyectos 2D", explorador visual de escenas y visor de hojas de contacto).
* ⚙️ **Backend API (FastAPI)**: [http://localhost:8000/docs](http://localhost:8000/docs) (Endpoints REST `/api/v2/projects`).
* 🎞️ **Editor Multipista videoAssembler**: [http://localhost:5174](http://localhost:5174) (Edición manual multipista y exportación con FFmpeg).

---

### Método 3: Flujo por Comandos (CLI para Desarrolladores — Fase 2 Producción)

Si prefieres operar desde la terminal o integrar el motor en pipelines automatizados tras validar el guion en Fase 1:

#### Paso 1: Generar el scaffolding del proyecto
```bash
python3 video-studio/scripts/crear_produccion_2d.py \
  --id "mi-nuevo-video" \
  --titulo "Título del Video" \
  --tema "Descripción conceptual y estilo visual"
```
*(Los proyectos se archivan cronológicamente en `video-studio/projects/<DD de mes de YYYY>/<slug>/`).*

#### Paso 2: Auditar el guion antes de sintetizar voz (Preproducción CLI)
```bash
python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py \
  --storyboard "video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/storyboard.json"
```

#### Paso 3: Generar locuciones, timeline y banda sonora
```bash
python3 video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/prepare.py
```

#### Paso 4: Previsualización interactiva en Remotion Studio
```bash
cd video-studio/remotion
npx remotion studio --no-open
```

#### Paso 5: Hoja de contactos y renderizado final
```bash
# Hoja de contactos de control visual
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs --stills

# Renderizado vertical 9:16 (Shorts / Reels / TikTok)
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs

# Renderizado horizontal 16:9 (YouTube panorámico) o ambos (--aspect=both)
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs --horizontal
```

---

## 🎭 El Equipo de Agentes Especializados

La agencia opera bajo contratos estrictos de responsabilidad delimitada en [Agencia_Principal/agentes/](Agencia_Principal/agentes/):

| Agente | Ficha de Rol | Fase | Especialidad y Responsabilidad |
| :--- | :--- | :---: | :--- |
| **Asistente Principal** | [asistente-principal.md](Agencia_Principal/asistente-principal.md) | Fase 1 y 2 | Orquestador interactivo central; opera los **2 Prompts Maestros** de preproducción y coordina el traspaso a producción. |
| **Agente de Redes Sociales** | [redes-sociales.md](Agencia_Principal/agentes/redes-sociales.md) | **Fase 1** | **Social Media Manager:** investigación web/navegador de tendencias y videos exitosos, mercado, audiencia y empaquetado social sin *engagement bait*. |
| **Agente Estratega Narrativo** | [agente-estratega-narrativo.md](Agencia_Principal/agentes/agente-estratega-narrativo.md) | **Fase 1** | Entrevista guiada, análisis de *outliers* (`swipe.py`), ganchos de 3 capas, retención, guion base y auditoría (`evaluar_guion.py >= 80/100`). |
| **Agente Animación Viva** | [agente-animacion-viva.md](Agencia_Principal/agentes/agente-animacion-viva.md) | Fase 2 | **Erradicación de títeres de cartón.** Anticipación física, *squash & stretch*, 31 expresiones emocionales y linework orgánico. |
| **Agente Director Audiovisual** | [agente-director-audiovisual.md](Agencia_Principal/agentes/agente-director-audiovisual.md) | Fase 2 | Puesta en escena, *shot cards*, *beat sync*, curaduría de audio anti-repetición y crítica visual. |
| **Agente Estilo Vox** | [agente-estilo-vox.md](Agencia_Principal/agentes/agente-estilo-vox.md) | Fase 2 | Estética editorial de imprenta ("printed, not lit"), tramas *halftone*, resaltador cinético y collage con fotos reales. |
| **Agente Animador 2D** | [agente-animador-2d.md](Agencia_Principal/agentes/agente-animador-2d.md) | Fase 2 | Arte vectorial SVG bajo `estilo-cartoon-editorial-3d`, cinemática inversa (IK) y componentes React en Remotion. |
| **Agente Motion Remotion** | [agente-motion-remotion.md](Agencia_Principal/agentes/agente-motion-remotion.md) | Fase 2 | Cámaras virtuales continuas, interpolaciones deterministas (`perceptual-scale`) y transiciones motivadas. |
| **Agente QA Remotion** | [agente-qa-remotion.md](Agencia_Principal/agentes/agente-qa-remotion.md) | Fase 2 | Puerta de calidad obligatoria, auditoría de hoja de contactos y calibración acústica EBU R128 (-18 a -19 LUFS). |
| **Agente Replicador de Video** | [agente-replicador-video.md](Agencia_Principal/agentes/agente-replicador-video.md) | Fase 2 | Análisis y clonación cuadro a cuadro de videos de referencia hacia código canónico en Remotion. |

---

## 🧠 Catálogo de Habilidades (164 Skills Canónicas)

### 1. Skills Auditadas de Preproducción, Estrategia Viral e Investigación (Fase 1 · Sin generación de video)

| Categoría | Skills integradas y verificadas | Capacidad clave |
| :--- | :--- | :--- |
| **Orquestación Social & Ideación Guiada** | `preproduccion-social-video` *(nueva nativa)*, `interview-me`, `idea-refine`, `viral-short-form-ideas` *(nueva MIT)* | Entrevista estratégica progresiva, 5–7 ángulos filmables, matriz de contenido, pilares y filtro de entretenimiento. |
| **Investigación Web, Tendencias y Outliers** | `niche-research` *(nueva MIT)*, `yt-viral` *(nueva MIT · `swipe.py`)*, `customer-research` *(nueva MIT)* | Navegación en vivo de tendencias (últimos 7 días), detección de videos que superan `>= 2.0x` la mediana de su canal y minería segura de dolores de audiencia. |
| **Estrategia de Mercado y Redes** | `content-strategy` *(nueva MIT)*, `social` *(nueva MIT)*, `voice-builder` | Buscable vs. Compartible, *Information-Gain Gate*, ingeniería inversa viral, anti-AI-tells y aislamiento de voz de marca. |
| **Ganchos (0–3s), Retención y Guion Base** | `estrategia-narrativa-ganchos-retencion` *(`evaluar_guion.py`)*, `viral-hooks` *(nueva MIT)*, `viral-short-form` *(nueva MIT)*, `yt-script` *(nueva MIT · 21 fórmulas + `hookscore.py`)*, `reels-scripting`, `documentary-narrative-engine` | Ganchos en 3 capas (visual + verbal + texto), re-ganchos cada 2 escenas, ritmo ágil y auditoría cuantitativa pre-producción (`>= 80/100`). |
| **Empaquetado y Copy Social** | `yt-package` *(nueva MIT · `title.py`)*, `viral-captions-and-ctas` *(nueva MIT)*, `post-scorer` | Títulos + portadas sin duplicación (40/60 chars), copy SEO nativo, 3–5 hashtags, CTAs anti-engagement-bait y comentario fijado. |

### 2. Skills de Producción Audiovisual, Diseño Sonoro Pro, Remotion y Motion (Fase 2)

* 🎧 **Tríada de Diseño Sonoro Pro (Auditada e Integrada):**
  - `earshot` + `real-sound` (`Leonxlnx/earshot`, MIT): medición acústica exacta en CPU (`earshot measure` para LUFS, True Peak, espectro y ataques `peak_s`), fabricación de SFX limpios aprendidos de dominio público (`earshot make`, kit `film`, 922 diseños) y flujo profesional de mezcla determinista con auditoría de licencias.
  - `real-sfx` (`Clipwing/skills`, scripts MIT + 78 cues UI `uisfx` CC0): analiza el render cuadro a cuadro (`look.py`, `find_moments.py`, `from_cues.py`), coloca efectos reales desde `video-studio/assets/sfx` (`169` SFX indexados) en el fotograma exacto con `--voice-safe --duck` y valida cero duplicación sintética (`critique.py`).
  - `openverse-audio` (API oficial WordPress Foundation, MIT): búsqueda y descarga directa sin API key de **5M+ audios con licencia abierta (`CC0`/`PDM`/`CC-BY`)**, medición automática con FFmpeg y generación de `CREDITS.md`.
* 🎨 **Estilos Visuales:** `estilo-cartoon-editorial-3d` (estándar por defecto), `estilo-kiwi-kurzgesagt-3d`, `vox-style-animation`, `editorial-paper-collage-animation`.
* 📘 **[Guía Oficial de Remotion Dev Skills](Agencia_Principal/skills/remotion-dev-skills/GUIA-REMOTION-DEV-SKILLS.md):** `remotion-best-practices`, `remotion-markup`, `remotion-captions`, `remotion-studio`, `remotion-render`, `remotion-maps`, `remotion-multimedia`.
* 🎬 **[Guía de Habilidades de Motion y Dirección](Agencia_Principal/skills/motion-video-skills/GUIA-MOTION-VIDEO-SKILLS.md):** `character-animation-engine`, `motion-design`, `make-awesome-video`, `video-shotcraft`, `handdraw-skill`, `motion-canvas`.

Para consultar cualquier habilidad o probar los evaluadores desde la terminal:
```bash
python3 Agencia_Principal/scripts/agencia.py skills --consulta preproduccion
python3 Agencia_Principal/scripts/agencia.py skills --nombre preproduccion-social-video
python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py \
  --tema "3 gestos que estresan a tu perro" \
  --gancho "El abrazo que le das a tu perro cada mañana podría estar poniéndolo en alerta."
```

---

## 📏 Los 7 Mandamientos de Calidad (Preproducción + Producción)

1. **Validar Mercado y Guion Antes de Producir (Fase 1 Obligatoria):** Ningún video entra a síntesis de voz o render sin un ángulo claro, análisis real de mercado/referencias (cuando haya navegador/web) y puntaje `>= 80/100` en `evaluar_guion.py`.
2. **Cero Marionetas de Cartón (Animación Viva Obligatoria):** Todo elemento animado exhibe anticipación, *squash & stretch*, inercia IK y ciclos de respiración/parpadeo continuos bajo `estilo-cartoon-editorial-3d` (o el estilo elegido).
3. **Investigación e Integración Selectiva de Material Real / IA:** Recortes reales procesados (`public/images/<slug>/`) o fondos IA de Gemini solo cuando potencien la claridad o el impacto de la historia.
4. **Curaduría Acústica Anti-Repetición (414 Audios):** Selección basada en la historia con `buscar_audio.py --historia --evitar-recientes`, 12–20 micro-SFX por minuto y mezcla EBU R128 (-18 a -19 LUFS, True Peak `< -1.0 dBFS`).
5. **Organización Cronológica por Fecha:** Toda producción final se aloja en `video-studio/projects/<DD de mes de YYYY>/<slug>/` y los experimentos en `video-studio/proyectos-test/`.
6. **Puerta de Control Visual Pre-Render (Contact Sheet Gate):** Ningún video se entrega sin renderizar e inspeccionar visualmente su hoja de contactos (`render.mjs --stills`).
7. **Empaquetado Social sin Engagement Bait:** Todo cierre entrega título/portada validados, bloque limpio listo para copiar y pegar, 3–5 hashtags de nicho y comentario fijado.

---

## 🏗️ Estructura del Repositorio

```text
.
├── README.md                           # Manual general con los 2 Prompts Maestros y flujo completo
├── skills-lock.json                    # Registro de skills externas instaladas
├── .agents/skills/                     # Habilidades descubiertas automáticamente por el IDE
├── docs/
│   └── GUIA_COMPLETA_PRODUCCION_2D.md  # Manual técnico exhaustivo de producción 2D
├── Agencia_Principal/                  # Orquestación de agentes y catálogo canónico (164 skills)
│   ├── README.md                       # Documentación de la agencia + 2 Prompts Maestros y auditoría
│   ├── asistente-principal.md          # Coordinador maestro (Modo A Ideación + Modo B Estrategia + Fase 2)
│   ├── agentes/                        # Agentes especializados (redes-sociales, estratega narrativo, animación, QA)
│   ├── flujos/                         # Flujos de trabajo guiados
│   ├── reglas/                         # Estándar de animación 2D, precedencia y rutas-agentes.json
│   ├── skills/                         # Fuentes canónicas (preproduccion, viral-content, youtube-strategy, marketing-strategy, remotion, motion)
│   └── scripts/                        # Scripts de verificación y catálogo (`agencia.py`)
├── video-studio/                       # Motor central de producción audiovisual (Fase 2)
│   ├── mis-ideas/                      # Banco automático privado de ideas e historias (`[fecha] - [Categoría] - Tema.md`, ignorado por Git)
│   ├── mis-temas/                      # Briefs validados y cuestionarios privados (ignorado por Git)
│   ├── projects/                       # Producciones finales organizadas por fecha
│   ├── shared-art/                     # Rigs compartidos (`cartoon/`, cinemática IK, partículas)
│   ├── assets/                         # Catálogo de 414 audios e historial anti-repetición
│   ├── scripts/                        # Scaffolding (`crear_produccion_2d.py`), `buscar_audio.py` y `elevenlabs_cli.py`
│   ├── backend/                        # API FastAPI, SQLite, persistencia y Gateway Multi-Cuenta ElevenLabs (`.env.example`)
│   ├── frontend/                       # Dashboard React + Tailwind
│   └── remotion/                       # Motor Remotion 4.x con Chromium Headless
└── videoAssembler/                     # Editor web multipista complementario
```

---

## 🔧 Comandos de Mantenimiento y Verificación

Para auditar y comprobar la salud del sistema en cualquier momento:

```bash
# 1. Búsqueda de audios temáticos anti-repetición
python3 video-studio/scripts/buscar_audio.py --historia "curiosidades divertidas sobre perros" --evitar-recientes

# 2. Evaluación rápida de un gancho en preproducción
python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py \
  --tema "Perros" \
  --gancho "El abrazo que le das a tu perro cada mañana podría estar poniéndolo en alerta."

# 3. Gateway Multi-Cuenta y Selector Dinámico de Voces ElevenLabs
python3 video-studio/scripts/elevenlabs_cli.py estado
python3 video-studio/scripts/elevenlabs_cli.py voces --edad young

# 4. Tríada de Diseño Sonoro Pro (Fase 2 · Openverse, Earshot, Real SFX)
python3 Agencia_Principal/skills/audio-pro-skills/openverse-audio/scripts/buscar_openverse.py \
  --buscar "whoosh transition" --licencia cc0 --max-dur 2.5 --limite 5
earshot make "a soft whoosh for a transition" -o /tmp/test_whoosh.wav && earshot measure /tmp/test_whoosh.wav
cd Agencia_Principal/skills/audio-pro-skills/real-sfx && python3 scripts/setup.py check

# 5. Validación de integridad estructural y catálogo de la agencia
python3 Agencia_Principal/scripts/agencia.py validar

# 6. Comprobación y ejecución completa de pruebas con evidencia local
cd Agencia_Principal && python3 scripts/agencia.py verificar && python3 scripts/agencia.py comprobar
```
