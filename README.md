# 🎬 V2-VIDEOS-IA · Plataforma Autónoma de Producción de Video & Animación con IA

> **Plataforma integral y autónoma para la creación de videos cinematográficos, animaciones vectoriales 2D orgánicas, documentales explicativos estilo Vox y piezas promocionales con Remotion, React y agentes especializados de Inteligencia Artificial.**

---

## 🌟 ¿Qué es esta herramienta?

**V2-VIDEOS-IA** transforma cualquier idea, guion, artículo o concepto en un video profesional de alta retención. A diferencia de los generadores convencionales que producen gráficos estáticos o "títeres de cartón tiesos", este sistema combina:

1. **Animación 2D Viva y Orgánica:** Rigging vectorial con cinemática inversa (IK), deformación elástica (*squash & stretch*), anticipación física y expresiones emocionales dinámicas.
2. **Estilos Cinematográficos y Editoriales:** Soporte nativo para narrativa documental tipo Vox (textura de papel de imprenta, tramas de medios tonos *halftone*, resaltador cinético y collage de fotos auténticas) y videos de producto con recetas de planos (*shot cards*).
3. **Orquestación de Agentes y 144 Habilidades:** Un equipo de agentes especializados coordinados por un Asistente Principal interactivo, respaldados por la suite oficial de **Remotion** y principios clásicos de animación de **Disney / Motion Design**.
4. **Curaduría Acústica y Masterización EBU R128:** Catálogo de 381 pistas musicales y efectos de sonido (SFX), análisis de decibeles con auto-ducking inteligente al 35% y cero distorsión digital.

---

## 🚀 ¿Cómo Usar Esta Herramienta? (3 Métodos)

### Método 1: Creación Asistida por IA (Recomendado para Creadores)

No necesitas programar ni configurar manualmente timelines. Todo se activa mediante una instrucción directa en el chat de tu agente de IA (**Antigravity IDE**, **Cursor**, **Claude Code**, **VS Code** o CLI):

```text
Actúa como el asistente principal en Agencia_Principal/asistente-principal.md para hacer un video: [tu idea o tema aquí]
```

*(O simplemente: `Actúa como el asistente principal en Agencia_Principal/asistente-principal.md para hacer un video`)*

#### ¿Cómo funciona la experiencia interactiva?
1. **Cuestionario Interactivo sin Tecnicismos:** La IA despliega un cuestionario de 5 preguntas claras (en Antigravity como modal nativo interactivo o artefacto editable; en otros IDEs como archivo Markdown en `video-studio/mis-temas/`):
   - **¿De qué va a tratar el video?** (Tema o hecho central libre).
   - **Giro y tono narrativo** (Científico con humor, Didáctico/Educativo 2D, Misterio/Curiosidades, Dramático/Crudo, Cultura Pop/Memes o Corporativo/Tech).
   - **Formato y relación de aspecto** (`9:16` vertical para TikTok/Reels/Shorts, `16:9` panorámico para YouTube, o ambos).
   - **Duración estimada** (30-60s ágil, 60-90s en 5 actos, o +2 min extendido).
   - **Motor de voz / TTS** (Edge-TTS nativo, clonación RVC v2 con Applio o voces premium con ElevenLabs).
2. **Orquestación Autónoma de Subagentes:** Una vez que respondes el cuestionario, el Asistente Principal despliega internamente a los roles especializados adecuados (animación viva, estilo Vox, director audiovisual, QA) sin pedirte decisiones técnicas complejas.
3. **Investigación Real y Audio Temático:** La IA investiga y descarga fotografías y documentos históricos auténticos con recorte transparente (`.png`), selecciona la música adecuada desde el catálogo de 381 audios y calibra la ganancia.
4. **Puerta de Control Visual:** Antes de renderizar, genera una hoja de contactos (`contact-sheet.jpg`) para comprobar encuadre, textos y fluidez.
5. **Entrega Final con Copy para Redes:** Entrega el video master final en alta definición junto con un copy optimizado (gancho, micro-copy, llamada a la acción y hashtags estratégicos) listo para publicar.

---

### Método 2: Plataforma Web (Dashboard & Editor Multipista)

Para gestionar proyectos, previsualizar hojas de contacto y explorar la API:

```bash
cd video-studio
./start.sh
```

* 🖥️ **Frontend Dashboard**: [http://localhost:5173](http://localhost:5173) (Pestaña "Proyectos 2D", explorador visual de escenas y visor de hojas de contacto).
* ⚙️ **Backend API (FastAPI)**: [http://localhost:8000/docs](http://localhost:8000/docs) (Endpoints REST `/api/v2/projects`).
* 🎞️ **Editor Multipista videoAssembler**: [http://localhost:5174](http://localhost:5174) (Edición manual multipista y exportación con FFmpeg).

---

### Método 3: Flujo por Comandos (CLI para Desarrolladores)

Si prefieres operar desde la terminal o integrar el motor en pipelines automatizados:

#### Paso 1: Generar el scaffolding del proyecto
```bash
python3 video-studio/scripts/crear_produccion_2d.py \
  --id "mi-nuevo-video" \
  --titulo "Título del Video" \
  --tema "Descripción conceptual y estilo visual"
```
*(Los proyectos se archivan cronológicamente en `video-studio/projects/<DD de mes de YYYY>/<slug>/`).*

#### Paso 2: Generar locuciones, timeline y banda sonora
Edita `storyboard.json` con las escenas y textos, y ejecuta:
```bash
python3 video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/prepare.py
```
*Genera audios `.mp3` sincronizados palabra por palabra, marcas temporales a 30 FPS y la música calibrada.*

#### Paso 3: Previsualización interactiva en Remotion Studio
```bash
cd video-studio/remotion
npx remotion studio --no-open
```
*Abre la previsualización en el navegador para calibrar timing, cámaras y animaciones en tiempo real.*

#### Paso 4: Generar la hoja de contactos de control (Contact Sheet)
```bash
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs --stills
```
*Genera `renders/contact-sheet.jpg` con una cuadrícula visual de todas las escenas para validar que no existan desalineaciones.*

#### Paso 5: Renderizado final en alta definición
```bash
# Renderizado vertical 9:16 (Shorts / Reels / TikTok)
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs

# Renderizado horizontal 16:9 (YouTube panorámico)
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs --horizontal

# Renderizado simultáneo en ambos formatos
node video-studio/projects/<DD de mes de YYYY>/mi-nuevo-video/render.mjs --aspect=both
```

---

## 🎭 El Equipo de Agentes Especializados

La agencia opera bajo contratos estrictos de responsabilidad delimitada en [Agencia_Principal/agentes/](Agencia_Principal/agentes/):

| Agente | Ficha de Rol | Especialidad y Responsabilidad |
| :--- | :--- | :--- |
| **Asistente Principal** | [asistente-principal.md](Agencia_Principal/asistente-principal.md) | Orquestador interactivo central; interactúa con el usuario, despliega el cuestionario y coordina subagentes. |
| **Agente Animación Viva** | [agente-animacion-viva.md](Agencia_Principal/agentes/agente-animacion-viva.md) | **Erradicación de títeres de cartón.** Inyecta anticipación física, deformación elástica (*squash & stretch*), 31 expresiones emocionales y linework vivo a 12 fps. |
| **Agente Director Audiovisual** | [agente-director-audiovisual.md](Agencia_Principal/agentes/agente-director-audiovisual.md) | Dirección de puesta en escena, selección de tarjetas de planos (*shot cards*), sincronización rítmica (*beat sync*) y crítica visual. |
| **Agente Estilo Vox** | [agente-estilo-vox.md](Agencia_Principal/agentes/agente-estilo-vox.md) | Estética editorial de imprenta ("printed, not lit"), tramas de medios tonos halftone, resaltador cinético y collage con fotos reales. |
| **Agente Animador 2D** | [agente-animador-2d.md](Agencia_Principal/agentes/agente-animador-2d.md) | Construcción de arte vectorial SVG enriquecido, cinemática inversa (IK) y montaje de componentes React en Remotion. |
| **Agente Motion Remotion** | [agente-motion-remotion.md](Agencia_Principal/agentes/agente-motion-remotion.md) | Cámaras virtuales continuas, interpolaciones deterministas (`perceptual-scale`) y transiciones entre escenas. |
| **Agente QA Remotion** | [agente-qa-remotion.md](Agencia_Principal/agentes/agente-qa-remotion.md) | Puerta de calidad obligatoria, auditoría de hoja de contactos y calibración acústica EBU R128 (-18 a -19 LUFS). |
| **Agente Replicador de Video** | [agente-replicador-video.md](Agencia_Principal/agentes/agente-replicador-video.md) | Análisis y clonación cuadro a cuadro de videos de referencia (MP4/Redes) hacia código canónico en Remotion. |

---

## 🧠 Catálogo de Habilidades (144 Skills)

La agencia cuenta con un catálogo exhaustivo de 144 habilidades descubribles y resolubles mediante el CLI local:

* 📘 **[Guía Oficial de Remotion Dev Skills](Agencia_Principal/skills/remotion-dev-skills/GUIA-REMOTION-DEV-SKILLS.md)**:
  - `remotion-best-practices`: Router maestro y aislamiento de frames en componentes hoja.
  - `remotion-markup`: Directrices de JSX/CSS: `scale`/`translate`/`rotate` directos, `{ output: 'perceptual-scale' }` y resortes.
  - `remotion-captions`: Subtitulado cinético sincronizado palabra por palabra.
  - `remotion-studio`: Inspección interactiva con Remotion Studio (`npx remotion studio --no-open`).
  - `remotion-render`: Optimización de exportación, CRF 17 y concurrencia.
  - `remotion-maps`: Mapas animados vectoriales y sobrevuelos 3D (MapLibre, Cesium, GeoJSON).
  - `remotion-multimedia`: Medición determinista de dimensiones y duraciones con Mediabunny.
* 🎬 **[Guía de Habilidades de Motion y Dirección](Agencia_Principal/skills/motion-video-skills/GUIA-MOTION-VIDEO-SKILLS.md)**:
  - `character-animation-engine`: 31 estados emocionales, linework orgánico con boil y dinámicas de personajes vivos.
  - `motion-design`: Los 12 principios clásicos de animación de Disney adaptados a código.
  - `vox-style-animation` & `vox-explainer`: Estilo editorial documental Vox, medios tonos y papel crema.
  - `make-awesome-video` & `video-shotcraft`: Dirección cinematográfica pro, beat sync y shot cards.
  - `handdraw-skill`: Animación de dibujo trazo a trazo y pizarras explicativas.
  - `motion-canvas` & `motion-canvas-agent`: Framework programático complementario con generadores y señales.

Para consultar cualquier habilidad desde la terminal:
```bash
python3 Agencia_Principal/scripts/agencia.py skills --nombre character-animation-engine
python3 Agencia_Principal/scripts/agencia.py skills --nombre remotion-markup
```

---

## 📏 Los 6 Mandamientos de Calidad del Video

1. **Cero Marionetas de Cartón (Animación Viva Obligatoria):** Prohibido generar personajes estáticos o recortes inmóviles. Todo elemento animado debe exhibir anticipación previa a la acción, deformación elástica (*squash & stretch*), inercia en extremidades y ciclos de respiración/parpadeo continuos.
2. **Investigación e Integración de Material Real:** Prohibido limitarse a gráficos sintéticos genéricos. Es obligatorio investigar en la web y descargar fotografías históricas, patentes o documentos auténticos, procesados con canal alfa transparente (`public/images/<slug>/`) e integrados estéticamente con el arte vectorial SVG.
3. **Curaduría Acústica Temática (381 Audios):** Prohibido usar música genérica repetitiva. La música se selecciona según el género exacto (retro/gaming, suspenso, ciencia, épico) desde `video-studio/assets/catalogo_audios.json`, normalizada a **-22 / -24 LUFS**, con **auto-ducking al 35%** durante la voz narradora y picos inferiores a **-1.0 dBFS** (EBU R128).
4. **Organización Cronológica por Fecha:** Ningún proyecto se almacena suelto en la raíz. Toda producción se aloja en `video-studio/projects/<DD de mes de YYYY>/<slug>/`.
5. **Puerta de Control Visual Pre-Render (Contact Sheet Gate):** Ningún video se entrega sin renderizar e inspeccionar visualmente su hoja de contactos (`render.mjs --stills`).
6. **Entrega con Copy Multimodal para Redes:** Todo cierre incluye un copy estructurado (gancho, micro-copy, llamada a la acción y 6-10 hashtags virales) listo para publicar.

---

## 🏗️ Estructura del Repositorio

```text
.
├── README.md                           # Este documento (Manual general y de IA)
├── skills-lock.json                    # Registro bloqueado de skills universales instaladas
├── .agents/skills/                     # Habilidades descubiertas por el IDE y agentes
├── docs/
│   └── GUIA_COMPLETA_PRODUCCION_2D.md  # Manual técnico exhaustivo de producción 2D
├── Agencia_Principal/                  # Orquestación de agentes y catálogo canónico
│   ├── asistente-principal.md          # Coordinador maestro e interacción interactiva
│   ├── agentes/                        # 26 agentes especializados (animación viva, Vox, director, QA)
│   ├── flujos/                         # Flujos de trabajo guiados (diseño visual, dev-flow)
│   ├── reglas/                         # Estándar de animación 2D y rutas de agentes
│   ├── skills/                         # Fuentes canónicas de habilidades (remotion-dev, motion-video)
│   └── scripts/                        # Scripts de verificación y catálogo (`agencia.py`)
├── video-studio/                       # Motor central de producción audiovisual
│   ├── projects/                       # Proyectos organizados cronológicamente por fecha
│   │   └── <DD de mes de YYYY>/<slug>/ # Carpeta auto-contenida de cada producción
│   ├── shared-art/                     # Rigs anatómicos compartidos, cinemática y partículas
│   ├── assets/                         # Catálogo de 381 audios y guía acústica
│   ├── scripts/                        # Scaffolding (`crear_produccion_2d.py`) y búsqueda de audio
│   ├── backend/                        # API FastAPI, SQLite y persistencia
│   ├── frontend/                       # Dashboard React + Tailwind
│   └── remotion/                       # Motor Remotion 4.x con Chromium Headless
├── videoAssembler/                     # Editor web multipista complementario
└── VibeVoice/                          # Modelos de síntesis de voz y ASR
```

---

## 🔧 Comandos de Mantenimiento y Verificación

Para auditar y comprobar la salud del sistema en cualquier momento:

```bash
# 1. Búsqueda instantánea de audios temáticos recomendados
python3 video-studio/scripts/buscar_audio.py --buscar "gaming"

# 2. Validación de integridad estructural y catálogo de la agencia
python3 Agencia_Principal/scripts/agencia.py validar

# 3. Comprobación y ejecución de tests con evidencia local
python3 Agencia_Principal/scripts/agencia.py verificar && python3 Agencia_Principal/scripts/agencia.py comprobar
```
