# Manifiesto del proyecto

- ID: video-creator-studio
- Cliente y marca: Propio
- Tipo: nuevo
- Objetivo y problema: Crear y producir videos de animación 2D y motion graphics con IA desde el panel web o mediante la orquestación de agentes de desarrollo, erradicando figuras rígidas en favor de personajes vivos, dirección audiovisual cinematográfica y render final local Remotion.
- Alcance / fuera de alcance: Guion y storyboard interactivos; personajes vectoriales SVG vivos generados en código con volumen, gradientes, rigging IK, física secundaria y 12 fps boil; 144 skills canónicas (`remotion-dev-skills` y `motion-video-skills`); voz multiproveedor (Edge-TTS por defecto, Applio RVC v2 y ElevenLabs); curaduría temática de 414 pistas de audio con auto-ducking al 35% y estándar EBU R128 (-18 a -19 LUFS); dirección cinematográfica plano a plano (shot cards); estilo documental Vox; composición 9:16 y 16:9; y entrega multimodal con copy limpio 1-clic para redes sociales. La generación raster por modelos de terceros no es parte del flujo principal.
- Usuarios: Creador/editor que responde al cuestionario guiado de 6 preguntas (tema, giro/tono, formato, duración, voz y outro/logo) y aprueba guion, storyboard y recursos.
- Requisitos funcionales y no funcionales: Cuestionario interactivo no técnico; orquestación de subagentes especializados; persistir proyectos por etapas; producir arte SVG con estándares editoriales (rostros completos, vestimenta confeccionada, manos articuladas); renderizar localmente con Remotion/FFmpeg; soportar duraciones configurables con checkpoints de 60s.
- Restricciones y aprobaciones: No avanzar a storyboard sin aprobación de guion; no generar recursos ni render final sin aprobación de storyboard; preservar el umbral acústico EBU R128 y auto-ducking en mezcla de audio; las aprobaciones creativas son explícitas del usuario.
- Arquitectura y stack detectado: React/Vite, FastAPI, SQLite transaccional; 26 agentes especializados coordinados por el Asistente Principal (`rutas-agentes.json`); catálogo canónico de 144 skills en `.agencia/catalogo-skills.json`; Remotion para composición y renderizado determinista; FFmpeg/FFprobe para validación y checkpoints atómicos; editor hermano `videoAssembler` disponible en loopback.
- Frontend / backend / datos: `video-studio/frontend`, `video-studio/backend`, `video-studio/remotion`; SQLite en `video-studio/video_studio.sqlite3`; recursos multimedia en carpetas locales de proyectos.
- Memoria y grafo: `Agencia_Principal/contexts/projects/video-creator-studio/memoria.md`; timeline estructurado en `.memoria/timeline.jsonl`; CodeGraph del checkout.
- Criterios de aceptacion: Flujo guiado de 6 preguntas; personajes vivos sin rigidez de cartón; imágenes reales procesadas con alfa; mezcla de audio balanceada con música y SFX; render Remotion local sin pérdida y salida vertical/horizontal; copy social listo para pegar.
- Pruebas y evidencias: 45 pruebas backend superadas (`uv run pytest`); suite de integridad de agencia (`validar_agencia.py`) con 144 skills y 26 agentes aprobados; rutas de agentes verificadas (`validar_rutas_agentes.py`); evidencia local vinculada vigente (`agencia.py comprobar`); benchmark de producción de 28 minutos comprobado atómicamente por FFprobe.
- Riesgos, decisiones y pendientes: Mantener bajo consumo en ElevenLabs mediante recomendación por defecto de Charlie + eleven_flash_v2_5; verificar fidelidad de personajes SVG complejos en art.tsx; integración pendiente de timeline/recortes y Whisper local desde `videoAssembler`.
- Proximo paso: Ejecutar prueba piloto interactiva con el cuestionario de 6 preguntas del Asistente Principal para validar la generación de personajes vivos y el renderizado final.

- Stack Tecnológico Asignado: stacks/estandar
