# Manifiesto del proyecto

- ID: video-creator-studio
- Cliente y marca: Propio
- Tipo: nuevo
- Objetivo y problema: Crear y editar videos con IA desde el panel web o agentes de desarrollo, con aprobaciones humanas y render final local.
- Alcance / fuera de alcance: Guion y storyboard con OmniRoute; ilustraciones originales SVG generadas como código y animadas en Remotion; voz multiproveedor; edición de material fuente y composición vertical/horizontal. La generación de video raster por modelos externos no es parte del flujo visual principal.
- Usuarios: Creador/editor que define tema, duración, formato, voz y aprueba guion, storyboard y recursos.
- Requisitos funcionales y no funcionales: Persistir proyectos por etapas; permitir editar y regenerar escenas; producir SVG por escena sin depender de stickers genéricos; renderizar localmente con Remotion/FFmpeg; ofrecer salida 9:16 y 16:9; soportar duraciones configurables, inicialmente con objetivo máximo de una hora.
- Restricciones y aprobaciones: OmniRoute requiere conexión y credenciales configuradas; no avanzar a storyboard sin aprobación de guion; no generar recursos ni render final sin aprobación de storyboard; no iniciar render si faltan recursos requeridos. El agente puede operar el flujo, pero las aprobaciones son explícitas.
- Arquitectura y stack detectado: React/Vite, FastAPI, persistencia JSON existente, OmniRoute para texto/SVG, Remotion para composición y animación SVG, FFmpeg para codificación y montaje local.
- Frontend / backend / datos: `video-studio/frontend`, `video-studio/backend`, `video-studio/remotion`; los proyectos guardan metadatos, escenas, SVG, audios y estados en `video-studio/projects`.
- Memoria y grafo: `Agencia_Principal/contexts/projects/video-creator-studio/memoria.md`; CodeGraph del checkout.
- Criterios de aceptacion: Flujo visible y bloqueado por etapas; SVG original previsualizable/editable por escena; render local de Remotion; formatos vertical y horizontal; errores de proveedores y render comunicados sin aprobar automáticamente etapas.
- Pruebas y evidencias: Ejecutar build del frontend y comprobaciones backend pertinentes; registrar aquí resultados reales por entrega.
- Riesgos, decisiones y pendientes: La implementación existente aún auto-genera storyboard y render sin gate, usa stickers por defecto y no genera SVG originales; duración del generador actual limitada aproximadamente a diez minutos; verificar compatibilidad de ElevenLabs/modelos y la seguridad de secretos.
- Proximo paso: Implementar el primer flujo con gates explícitos y SVG generado por OmniRoute, validar render vertical/horizontal local.

- Stack Tecnológico Asignado: stacks/estandar
