# Memoria del Proyecto: video-creator-studio

- **ID de Proyecto:** `video-creator-studio`
- **Fecha de creación:** 2026-10-22T19:00:02+00:00
- **Estado general:** Implementación inicial en progreso

---

## 1. Estado Activo y Criterios Vigentes
- **Objetivo actual:** Flujo IA de guion aprobado → storyboard editable/aprobado → SVG originales → animación y render local Remotion.
- **Hito/Sprint:** Primer flujo vertical del producto
- **Tarea en curso:** Implementación de etapas con gates, generación SVG vía OmniRoute y composición vertical/horizontal.
- **Restricciones y bloqueos:** Ninguno
- **Pendientes consolidados:**
  - [x] Completar el manifiesto y registrar el flujo acordado.
  - [x] Añadir estados de aprobación de guion y storyboard, generación SVG validada y render condicionado.
  - [x] Añadir selección de formato vertical/horizontal y catálogo dinámico de voces ElevenLabs.
  - [ ] Probar generación y render reales con credenciales OmniRoute/ElevenLabs configuradas.
  - [ ] Añadir trabajos de fondo/reanudables para renders largos y completar edición de material fuente en el nuevo flujo.
- **Siguiente acción:** Ejecutar un proyecto de prueba real y ajustar el estilo SVG según el video de referencia.

---

## 2. Decisiones Técnicas y ADRs
- Uso de Edge-TTS gratis con timestamps de karaoke y Remotion con física elástica de resortes
- Persistencia desacoplada por escena, VoiceHub multiproveedor con Edge-TTS fallback y renderizado individual de escenas

### [2026-10-23T03:05:51+00:00] Sesión: flujo de producción SVG con Remotion
- **Agente:** Asistente Principal
- **Tareas completadas:** Guion editable con gate de aprobación; storyboard creado tras aprobación; SVG originales generados por OmniRoute, validados y guardados por escena; gates antes de generación visual y render; animación SVG en Remotion; selección vertical/horizontal; consulta de voces ElevenLabs en su API.
- **Archivos afectados:** `video-studio/backend`, `video-studio/frontend`, `video-studio/remotion`, manifiesto y README del proyecto.
- **Decisiones técnicas:** OmniRoute genera SVG en texto; se valida con allowlist XML; el render se ejecuta localmente; cambios al storyboard invalidan su aprobación y los SVG afectados.
- **Pendientes:** No se ejecutó una llamada real a proveedores ni un render de video de punta a punta. Render de una hora aún requiere cola/trabajo reanudable y pruebas de recursos.
- **Riesgos:** El render sigue síncrono; duración larga depende de capacidad de hardware y del tiempo límite del servidor.

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

## 4. Hitos Anteriores (Bitácora Compactada)
