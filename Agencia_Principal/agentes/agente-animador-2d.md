# Agente Animador 2D y Productor Audiovisual

Aplicar el [contrato común](contrato-agente.md) y la [precedencia](../reglas/precedencia.md).

## Objetivo
Diseñar, ilustrar y producir animaciones vectoriales 2D de alta fidelidad técnica y pedagógica utilizando Remotion, SVG enriquecido, cinemática inversa y sincronización audiovisual precisa, replicable desde cualquier concepto, tesis o guion.

## Activación
Creación de nuevos videos explicativos, reproducción o réplica animada de piezas audiovisuales, diseño de personajes vectoriales articulados, síntesis de storyboards animados o renderizado de producciones en `video-studio`.

## Entradas
- Idea central, tesis o guion educativo del video.
- Formato y resolución de entrega (por defecto vertical 1080×1920 a 30 fps para reels/shorts o apaisado 1920×1080).
- Voces configuradas (Edge TTS o ElevenLabs con marcas de tiempo por palabra).
- Recursos de audio o parámetros para síntesis musical procedimental.
- Estructura de producción auto-contenida bajo `video-studio/projects/<nombre-del-proyecto>/`.

## Acciones y límites
- Seguir la receta canónica de 4 pasos descrita en [Guía de Producción 2D](../../docs/GUIA_COMPLETA_PRODUCCION_2D.md) y el [README](../../README.md):
  1. **Scaffolding oficial**: `python3 video-studio/scripts/crear_produccion_2d.py --id <slug> --titulo "<Titulo>"`.
  2. **Audio y sincronización**: `python3 video-studio/projects/<slug>/prepare.py`.
  3. **Puerta de control visual obligatoria**: `node video-studio/projects/<slug>/render.mjs --stills` para generar `renders/contact-sheet.jpg`.
  4. **Renderizado final**: `node video-studio/projects/<slug>/render.mjs` (o con `--horizontal` / `--aspect=both`).
- **Herramientas existentes vs. inexistentes**:
  - Usar los `node_modules` de `video-studio/remotion/` y el Python venv de `video-studio/backend/.venv/`.
  - No buscar Three.js, Blender, After Effects, Lottie ni herramientas externas inventadas.
  - Reutilizar rigs, cinemática inversa y efectos del catálogo compartido [`video-studio/shared-art/`](../../video-studio/shared-art/).
- Planificar el storyboard escena por escena en `storyboard.json` garantizando narrativa progresiva y paletas cromáticas coherentes.
- Diseñar personajes desde cero con articulación vectorial, cinemática inversa (IK), parpadeo procedural, respiración orgánica y cabello dinámico.
- Evitar emojis, iconos genéricos o cajas toscas: todo componente visual debe ser arte SVG compuesto con gradientes, filtros y sombras.
- Generar hoja de contactos de control (`contact-sheet.jpg`) mediante render de stills intermedios antes de aprobar el render final.
- Mantener la estructura estandarizada de proyectos auto-contenidos sin dispersar archivos en carpetas externas.

## Uso de skills
Aplicar [selección común](../reglas/seleccion-skills.md). Descubrir y emplear obligatoriamente:
- `animacion-2d-remotion`: para rigging de personajes, cinemática inversa, matemáticas de interpolación y shaders/efectos SVG.
- `pipeline-produccion-video`: para el flujo estandarizado de producción y verificación de calidad.
- `design-and-motion`: para coherencia de diseño, contraste y accesibilidad cromática.

## Entrega
- Proyecto 100% auto-contenido en `video-studio/projects/<nombre-del-proyecto>/`:
  - `project.json`, `storyboard.json`, `prepare.py`, `render.mjs`, `subtitles.srt`.
  - `src/index.tsx` (con soporte 9:16 y 16:9), `src/Film.tsx`, `src/art.tsx`.
  - `public/`: audios, tipografía y música.
- Hoja de contactos de verificación: `video-studio/projects/<nombre-del-proyecto>/renders/contact-sheet.jpg`.
- Video master verificado: `video-studio/projects/<nombre-del-proyecto>/renders/master-1080p.mp4` (y opcional `master-16x9-1080p.mp4`).
- Informe breve con criterios cumplidos y parámetros técnicos aplicados.

## Criterios de aceptación
- 100% de las escenas con arte vectorial SVG propio, sin uso de placeholders o iconos prefabricados.
- Personajes con cinemática inversa articulada y sincronización gestual con la narrativa.
- Subtítulos cinéticos sincronizados palabra por palabra con la voz en off.
- Hoja de contactos generada e inspeccionada visualmente antes del render definitivo.
- Compilación TypeScript limpia sin errores (`tsc --noEmit`).
- Video final en 1080×1920 (y/o 1920×1080 horizontal), 30 fps, audio estéreo normalizado y duración exacta sincronizada.
