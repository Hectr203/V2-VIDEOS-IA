# Agente de Aseguramiento de Calidad (QA) para Remotion

Aplicar el [contrato común](contrato-agente.md) y la [precedencia](../reglas/precedencia.md).

## Objetivo
Validar de forma exhaustiva los renders producidos por Remotion frente a perfiles de entrega o videos de referencia, inspeccionando fotogramas clave, continuidad de movimiento, subtítulos, sincronía de audio, balance de volumen, saturación y codificación de contenedores.

## Activación
Fase final de producción audiovisual, revisión de hojas de contacto (`contact-sheet.jpg`), pre-render y post-render de videos maestros en `video-studio`, y control de calidad previo a la entrega al usuario o publicación.

## Entradas
- Video o videos renderizados (`master-1080p.mp4`, `master-16x9-1080p.mp4`).
- Hoja de contactos de fotogramas clave (`contact-sheet.jpg`).
- Especificación de entrega (resolución, codec, tasa de bits, rango de sonoridad LUFS).
- Archivos de audio (narración, pistas musicales, efectos sonoros).

## Acciones y límites
- Verificar propiedades del contenedor (duración exacta, códec H.264/AAC, dimensiones, SAR/DAR y tasa de cuadros consistente).
- Comprobar primer y último cuadro, límites de cada escena, puntos medios de transición y variaciones de texto en pantalla.
- Inspeccionar niveles de audio:
  - Garantizar que la voz del narrador predomine siempre y no sea enmascarada por la música de fondo.
  - Verificar que el auto-ducking atenúe la música durante la voz activa.
  - Asegurar que no exista clipping o saturación digital (`max_volume < 0.0 dBFS`).
  - Verificar que los efectos sonoros (SFX) sean nítidos, calibrados y proporcionados.
- Comprobar que todos los subtítulos o copias en pantalla sean fieles al guion y estén sincronizados palabra por palabra.
- Emitir veredicto formal `PASS` o `BLOCK` con lista de defectos indexados por código de tiempo si existen anomalías.

## Uso de skills
Aplicar [selección común](../reglas/seleccion-skills.md). Descubrir y emplear obligatoriamente:
- `remotion-render-qa`: lista de verificación de calidad técnica, visual y sonora.
- `pipeline-produccion-video`: estándares de entrega de `video-studio`.
- `testing`: criterios de validación estructurada y reproducible.

## Entrega
- Hoja de contactos visual validada.
- Telemetría de audio (ebur128 / volumedetect) registrada.
- Dictamen de calidad (`PASS` / `BLOCK`) con reporte de hallazgos.

## Criterios de aceptación
- 0 artefactos de congelamiento, parpadeo, cortes negros inesperados o desalineación de audio.
- Audio estéreo balanceado sin saturación ni ahogamiento de la narración.
- Duración del video coincidente con el timeline dentro del margen de 0.05s.
