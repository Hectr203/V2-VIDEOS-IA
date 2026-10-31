# Memoria del Proyecto: video-creator-studio

- **ID de Proyecto:** `video-creator-studio`
- **Fecha de creación:** 2026-10-22T19:00:02+00:00
- **Estado general:** Implementación inicial en progreso

---

## 1. Estado Activo y Criterios Vigentes
- **Objetivo actual:** Orquestación interactiva de videos 2D con Remotion, animación viva de personajes (IK rigging, squash & stretch), estilo documental Vox, dirección audiovisual y render local acelerado con checkpoints.
- **Hito/Sprint:** Integración completa de suites Remotion y Motion skills (144 skills) y orquestación interactiva según el Asistente Principal.
- **Tarea en curso:** Verificación del flujo de producción audiovisual interactivo con personajes animados de alta categoría editorial y calibración acústica EBU R128.
- **Restricciones y bloqueos:** Ninguno
- **Pendientes consolidados:**
  - [x] Integrar 12 skills oficiales de Remotion y 16 skills open-source de motion/animación en `.agents/skills/` y `Agencia_Principal/skills/` (144 skills totales).
  - [x] Crear 3 nuevos agentes especializados: `agente-animacion-viva`, `agente-director-audiovisual` y `agente-estilo-vox`.
  - [x] Actualizar `asistente-principal.md` con el cuestionario interactivo de 6 preguntas, motor TTS multiproveedor (Edge-TTS, Applio RVC v2, ElevenLabs), outro CTA/logo y entrega multimodal con copy 1-clic para redes.
  - [x] Actualizar `estandar-animacion-2d.md` con prohibición estricta de figuras rígidas de cartón, personajes SVG con volumen/gradientes y curaduría de 414 audios con auto-ducking al 35% y estándar EBU R128 (-18 a -19 LUFS).
  - [x] Actualizar y reescribir `README.md` con los 3 métodos de uso, tabla de agentes, 6 mandamientos de calidad y comandos de verificación.
  - [ ] Implementar prueba piloto interactiva con el cuestionario de 6 preguntas para un nuevo video documental/curiosidades.
  - [ ] Integrar el editor hermano `videoAssembler` (timeline, recortes/cortes, capas y manifiesto FFmpeg) con proyectos y persistencia de Video Studio.
  - [ ] Probar Whisper local (`whisper-cli` y modelo local) en el flujo web de Video Studio.
  - [ ] Medir CPU, memoria, disco y duración con renders de 1 hora completa con múltiples escenas complejas en el hardware objetivo.
- **Siguiente acción:** Iniciar producción interactiva de un video nuevo invocando al Asistente Principal con el protocolo de 6 preguntas para validar la composición de personajes vivos en `art.tsx` y el renderizado en Remotion.

---

## 2. Decisiones Técnicas y ADRs
- **ADR-001 (Síntesis Vocal y Audio):** Edge-TTS gratuito por defecto con karaoke, soporte de clonación Applio RVC v2 (modelo Morgan Freeman) y ElevenLabs premium (estándar recomendado: Charlie + `eleven_flash_v2_5`); curaduría inteligente de 414 pistas temáticas (`catalogo_audios.json`), auto-ducking calibrado al 35% y masterización acústica bajo estándar EBU R128 (-18 a -19 LUFS, picos < -1 dBFS).
- **ADR-002 (Renderizado Determinista y Checkpoints):** Renderizado local con Remotion y resortes físicos; segmentación atómica en checkpoints de 60s concatenados por FFmpeg sin recodificación; huella de invalidación por metadatos/código; validación final exhaustiva con FFprobe antes de publicación atómica.
- **ADR-003 (Persistencia y Seguridad Local):** Persistencia desacoplada por escena y jobs en SQLite transaccional (`video_studio.sqlite3`); servidores Vite y FastAPI confinados a loopback (`127.0.0.1`); endpoints binarios en streaming con límite de 2 GiB y saneamiento de temporales.
- **ADR-004 (Estándares de Animación Viva 2D):** Integración de 144 skills canónicas (`remotion-dev-skills` y `motion-video-skills`); erradicación total de figuras rígidas de cartón y monigotes primitivos en favor de personajes vectoriales SVG esculpidos con volumen, gradientes lineales/radiales, filtros `feDropShadow`, rigging IK, anticipación, *squash & stretch*, inercia en extremidades y *boiling linework* a 12 fps.
- **ADR-005 (Orquestación de Agentes y Copy Multimodal):** Protocolo interactivo de 6 preguntas sin abrumar al usuario con tecnicismos; coordinación de 26 roles especializados (incluyendo directores visuales, estilo Vox y QA); entrega de bloque de copy listo para 1-clic en redes sociales y auditoría transparente de créditos consumidos.

---

## 3. Historial Reciente (Ventana Deslizante: Últimas 5 Sesiones)

### [2026-10-22T19:00:02+00:00] Inicialización
- **ID Evento:** `ev_20261022190002_af56dc`
- **Agente:** Director de Proyecto / Asistente Principal
- **Tareas completadas:** Estructura de proyecto y memoria inicializadas con éxito.
- **Archivos afectados:** Ninguno
- **Decisiones técnicas:** Ninguna
- **Pendientes:** Completar `manifiesto.md` y definir requerimientos iniciales.
- **Riesgos:** Ninguno.

---

### [2026-10-22T19:10:19+00:00] Sesión: `ev_20261022191019_d7b6ee` | Agente: Asistente Principal
- **ID Evento:** `ev_20261022191019_d7b6ee`
- **Agente:** Asistente Principal
- **Tareas completadas:** Desarrollo completo de Video Studio IA: Frontend React, Backend FastAPI, Remotion 1080x1920 y Edge-TTS
- **Archivos afectados:** Ninguno
- **Decisiones técnicas:** Uso de Edge-TTS gratis con timestamps de karaoke y Remotion con física elástica de resortes
- **Pendientes:** Ninguno. Frontend y Backend en ejecución activa.
- **Riesgos identificados:** Ninguno

---

### [2026-10-22T19:40:19+00:00] Sesión: `ev_20261022194019_0f721e` | Agente: Asistente Principal
- **ID Evento:** `ev_20261022194019_0f721e`
- **Agente:** Asistente Principal
- **Tareas completadas:** Ampliación Enterprise: Storyboard interactivo con versionado, orquestador CLI, integración de OmniRoute en Azure con rotación/fallback y soporte de duraciones de 1 a 10 min
- **Archivos afectados:** Ninguno
- **Decisiones técnicas:** Persistencia desacoplada por escena, VoiceHub multiproveedor con Edge-TTS fallback y renderizado individual de escenas
- **Pendientes:** Ninguno. Verificación completa superada.
- **Riesgos identificados:** Ninguno

---

### [2026-10-31T05:21:20+00:00] Sesión: `ev_20261031052120_7db716` | Agente: Asistente Principal
- **ID Evento:** `ev_20261031052120_7db716`
- **Agente:** Asistente Principal
- **Tareas completadas:** Integración de suites de Remotion y Motion skills (144 skills totales), creación de 3 nuevos agentes especializados (animación viva, director audiovisual, estilo vox), actualización de estándares visuales de personajes SVG y protocolo interactivo de 6 preguntas
- **Archivos afectados:** `Agencia_Principal/asistente-principal.md`, `Agencia_Principal/reglas/estandar-animacion-2d.md`, `Agencia_Principal/reglas/rutas-agentes.json`, `Agencia_Principal/agentes/agente-animacion-viva.md`, `Agencia_Principal/agentes/agente-director-audiovisual.md`, `Agencia_Principal/agentes/agente-estilo-vox.md`, `Agencia_Principal/skills/remotion-dev-skills`, `Agencia_Principal/skills/motion-video-skills`, `README.md`
- **Decisiones técnicas:** Adopción de suites remotion-dev-skills y motion-video-skills; erradicación estricta de figuras rígidas de cartón en favor de rigging IK, squash & stretch y 12 fps boil; curaduría sonora de 414 audios con auto-ducking a 35% y cumplimiento EBU R128 (-18 a -19 LUFS); cuestionario interactivo de 6 preguntas con soporte de Edge-TTS, Applio RVC v2 y ElevenLabs; entrega final con copy 1-clic para redes
- **Pendientes:** Integrar el editor avanzado de videoAssembler con persistencia SQLite de Video Studio; implementar prueba piloto interactiva con el cuestionario de 6 preguntas para un nuevo video documental
- **Riesgos identificados:** Mantener bajo consumo de cuota en ElevenLabs mediante recomendación por defecto de Charlie + eleven_flash_v2_5; verificar fidelidad visual de los personajes SVG en art.tsx para cumplir el estándar editorial sin degradación de rendimiento

---

## 4. Hitos Anteriores (Bitácora Compactada)
