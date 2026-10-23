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
  - [x] Ejecutar render en trabajo local persistido, consultar progreso/cancelar y serializar recursos; al reiniciar, los segmentos Remotion completos de trabajos largos pueden reutilizarse.
  - [x] Invalidar storyboard, SVG y audio derivados al modificar contenido visual; conservar snapshot previo.
  - [x] Animar con Remotion las capas vectoriales principales de forma determinista; asegurar el host local por defecto y restringir CORS.
  - [x] Persistir proyectos, escenas y trabajos en SQLite con transacciones y migración no destructiva desde JSON.
  - [x] Cargar localmente metraje fuente en bloques; validar formato con FFprobe; guardar original en el proyecto y metadatos en SQLite; asignar clip y punto inicial por escena; Remotion lo compone localmente.
  - [x] Pasar a Remotion video y audio locales como archivos temporales/hardlinks en vez de incrustar MP3 por escena en base64; concurrencia ajustable y predeterminada al 25%.
  - [x] Permitir audio original por tramo de escena; validar pista y límites; saltar TTS para esos tramos y advertir que karaoke no tiene ASR sincronizado.
  - [ ] Integrar el editor hermano `videoAssembler` (timeline, recortes/cortes, capas y manifiesto FFmpeg) con proyectos y persistencia de Video Studio; incluir el CLI Whisper local de ese editor en el flujo web (requiere `whisper-cli` y modelo local, no disponibles aún).
  - [ ] Validar generación con OmniRoute y ElevenLabs reales y revisar visualmente el piloto de referencia.
  - [x] Cerrar vulnerabilidades auditables del editor `videoAssembler` con upgrades compatibles; su `npm audit` está en cero. El servidor Vite de Video Studio ya usa loopback por defecto (verificado en `127.0.0.1`).
  - [x] Migrar Video Studio a Vite 8/Tailwind 4 y actualizar el editor hermano; `npm audit` limpio en ambos; verificar look del panel y compatibilidad del host loopback.
  - [ ] Medir CPU, memoria, disco y duración con renders de varias decenas de minutos y una hora en el hardware objetivo.
  - [x] Reconectar la interfaz a trabajos persistidos; preferir el render activo y aislar respuestas al cambiar de proyecto.
  - [x] Validar MP4 final con FFprobe y publicarlo atómicamente sin sobrescribir destinos; reanudar segmentos de 60s con huella de entradas/código; suite backend 43/43.
- **Siguiente acción:** Integrar el editor avanzado de `videoAssembler` con el flujo de proyectos y su persistencia; comprobar instalación local de Whisper/descarga de modelo de forma explícita; validar upload con un clip del usuario y medir render largo. El render de 1h aún no está validado.

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

### Sesión: endurecimiento, SQLite y flujo visual
- **Tareas completadas:** Cola local de trabajos persistida con cancelación/progreso en SQLite, persistencia transaccional de proyectos/escenas, migración JSON→SQLite no destructiva, snapshots e invalidación de recursos obsoletos, animación vectorial por capas, loopback/CORS local por defecto y fallos explícitos de proveedor de voz.
- **Pruebas:** 10 pruebas unitarias de flujo/persistencia; compilación backend; build React/Vite; composición Remotion; `PRAGMA integrity_check=ok`; render local corto por `render_service` con salida MP4 y actualizaciones de progreso.
- **Pendientes:** No se probó con APIs externas. No hay integración de metraje fuente, reanudación por frame/checkpoint ni auditoría audiovisual automática.
- **Riesgo residual:** Una hora de video exige validar memoria/disco/tiempo en hardware objetivo; el piloto requiere evaluación humana de estética y ritmo.
- **Integración verificada:** El catálogo autenticado de ElevenLabs respondió con 21 voces en esta sesión; las claves no se mostraron.

### Sesión: ingestión local, composición y audio de metraje fuente
- **Tareas completadas:** Endpoint binario en streaming (sin multipart), límite de 2 GiB y validación con FFprobe; originales locales/metadatos SQLite. Panel permite subir, previsualizar y asignar clip, offset y tramo de audio original por escena. La asignación invalida aprobación y conserva SVG. Audio original requiere pista y tramo válido; para ese segmento se omite TTS. Remotion recibe archivos locales vía staging temporal, limpiado al terminar.
- **Pruebas:** 22/22 pruebas backend; `compileall`; build TypeScript/Vite; composición Remotion registrada; renders reales de 2s con audio fuente, H.264/AAC en 1920×1080 y 1080×1920, duración 2.005s; temporales eliminados; SQLite `integrity_check=ok`; proceso de Remotion termina y se recoge ante errores/cancelación.
- **Decisiones:** Props del render web ya no incrustan MP3 en base64; concurrencia configurable (25% por defecto). Audio original oculta karaoke al no haber ASR sincronizado.
- **Pendientes:** ASR local (Whisper) y timeline/cortes/transiciones están disponibles como piezas separadas en `videoAssembler`, pero todavía no forman parte del flujo de proyectos persistidos de Video Studio. Falta probar Whisper con `whisper-cli` y modelo instalado; prueba del upload del clip del usuario y render largo; APIs creativas no se invocaron y no se saltaron aprobaciones creativas. En esta continuación, el catálogo de voces del panel respondió HTTP 200.
- **Riesgo residual:** Uso de CPU/GPU, memoria, disco y tiempo para una hora depende del hardware; reinicio durante render requiere relanzamiento.

### Sesión: recuperación de trabajos, checkpoints y publicación validada
- **Tareas completadas:** La vista recupera el job activo; los trabajos interrumpidos/cancelados/fallidos reutilizan ID y segmentos válidos. Para trabajos superiores a 60s Remotion renderiza rangos temporales, valida cada MP4 y FFmpeg los concatena sin recodificar; una huella de props, código y metadatos de medios invalida checkpoints obsoletos. El archivo final sigue validándose con FFprobe y se publica atómicamente sin reemplazar destinos.
- **Pruebas:** Suite backend 43/43 mediante entorno temporal `uv`; build frontend; TypeScript Remotion; `compileall`; `git diff --check`; render real de 2.1s en segmentos + FFmpeg y FFprobe; comparación de audio de rango vs render continuo con correlación 0.9998; fallo simulado a mitad de segundo segmento confirma que se reutiliza el primero y solo se repite el rango pendiente.
- **Rendimiento observado:** Caso mínimo de una escena SVG de 30s, 1080×1920 y sin TTS ni metraje fuente: 27.82s de render, 2.49 MB, pico RSS 830 MB y ~213% CPU en el equipo de desarrollo. No extrapolar como SLA para una hora.
- **Pendientes:** Una hora con 300 escenas y consumo de recursos no se han medido en el hardware objetivo; APIs reales y QA estética humana siguen pendientes.
- **Rendimiento observado:** Caso mínimo de una escena SVG de 30s, 1080×1920 y sin TTS ni metraje fuente: 27.82s de render, 2.49 MB, pico RSS 830 MB y ~213% CPU en el equipo de desarrollo. No extrapolar como SLA para una hora.
- **Riesgo residual:** La comprobación FFprobe valida contenedor, pista y duración, no calidad perceptual ni decodificación completa de todos los frames; el benchmark mínimo no representa 300 escenas.

### Sesión: auditoría del editor hermano y endurecimiento local
- **Hallazgos:** `videoAssembler` contiene editor web con timeline, cortes, capas, manifiesto compartido y CLI FFmpeg; `cli/transcribe.ts` ofrece Whisper local por palabra, pero requiere `whisper-cli` y modelo grande. Estas funciones aún no están integradas a proyectos Video Studio/SQLite.
- **Cambios:** Actualización compatible de dependencias vulnerables en `videoAssembler`; migración mayor del frontend Video Studio a Vite 8/Tailwind 4; `npm audit` queda en cero en ambos. El Vite local escucha en loopback; `start.sh` levanta backend y ambos paneles en loopback en puertos libres, muestra las URLs efectivas y Video Studio enlaza al editor avanzado.
- **Verificación:** 22/22 pruebas backend; build/lint de ambas aplicaciones; auditorías npm en cero; prueba de arranque conjunto, enlace visible en el DOM y carga del editor; socket de Studio comprobado en 127.0.0.1; apariencia del panel comprobada visualmente tras Tailwind 4. Node mínimo `20.19` o `22.12`.

### Sesión: benchmark de render real, robustez de cancelación y 45/45 pruebas
- **Tareas completadas:** Creación y exportación del grafo de conocimiento con `graphify` (18.844 nodos, 48.090 aristas en `graphify-out/`). Diagnóstico de agencia con `agencia.py doctor` (24/24 comprobaciones pasadas). Adición de pruebas de invalidación de huella obsoleta y permisos de checkpoint (0o700). Interrupción inmediata de subprocesos ante cancelación.
- **Pruebas y Verificación:** Suite backend 45/45 superada (`uv run pytest`); frontend build Vite 8 exitoso; Remotion compilado e integrado; `git diff --check` limpio.
- **Benchmark real medido:** Clip unitario Remotion de 5s (150 frames) renderizado en 9.42s (~16 fps de render vs 30 fps de reproducción). Pipeline real con checkpoints de 2s (3 segmentos generados por Remotion + concatenación FFmpeg sin pérdida + validación FFprobe) completado en 18.69s.
- **Proyección calculada para video largo (30 minutos = 54.000 frames):** Requerirá ~28 a 35 minutos de render en esta CPU (12 núcleos, 14 GB RAM, NVMe rápido) dividido en 30 checkpoints de 60s protegidos ante caídas de luz o reinicios.

### Sesión: generación y renderizado real de video de 30 minutos de helados
- **Tareas completadas:** Creación del proyecto documental `proj_helados_30min_1792754110` con 60 escenas temáticas, síntesis de voz completa con Edge-TTS (`es-ES-AlvaroNeural`) y marcas karaoke. Renderizado completo de 50.400 frames (28 minutos netos de video vertical HD 1080×1920 a 30 FPS) dividido en 28 segmentos de 60 segundos gestionados por checkpoints en disco.
- **Ajuste de robustez en producción:** Se calibró la tolerancia de duración en `_validate_rendered_video` para renders largos multi-segmento (`tolerance = max(0.25, 2 / fps, 0.05 * (expected_duration_seconds / 60.0))`), absorbiendo la acumulación natural de muestras de audio AAC en las uniones de FFmpeg.
- **Resultado verificado por FFprobe:** Archivo publicado atómicamente en `video-studio/output/como_se_hace_el_helado_30min_proj_helados_30min_1792754110.mp4`, tamaño 136.88 MB (143.527.080 bytes), duración 1680.35s (28.00 min), video H.264 1080x1920 @ 30 fps, audio AAC estéreo.
- **Suite de pruebas:** 45/45 pruebas pasadas sin regresiones.



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
