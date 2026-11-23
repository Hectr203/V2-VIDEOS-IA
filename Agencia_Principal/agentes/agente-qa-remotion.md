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
  - Asegurar que no exista clipping o saturación digital (`True Peak < -1.0 dBFS`, sonoridad integrada `-18` a `-19 LUFS`).
  - Verificar que exista una capa rica y dinámica de efectos sonoros (SFX abundantes y variados acordes a la historia) perfectamente equilibrados sin sobrepasar ni enmascarar la voz narradora, y que la música seleccionada no sea repetitiva respecto a producciones recientes.
  - Auditar el audio con "oídos objetivos" antes de dar `PASS`: ejecutar `earshot measure <render.mp4>` (y `earshot timeline` / `earshot sheet` si el extra `[listen]` está instalado) para comprobar LUFS, True Peak dBTP y desfases de sincronía en milisegundos, y usar los controles de `real-sfx` (`critique.py`, `verify.py`, `levels.py`) cuando se haya aplicado mezcla de SFX frame-a-frame para descartar duplicación sintética (*doubling*), enmascaramiento o golpes fuera de cuadro.
  - Verificar coherencia visual estricta del estándar `estilo-cartoon-editorial-3d` (o el estilo elegido por el usuario), cero pestañas superiores y correcta integración de cualquier recorte web o imagen IA de Gemini utilizada.
- Comprobar que todos los subtítulos o copias en pantalla sean fieles al guion y estén sincronizados palabra por palabra.
- Emitir veredicto formal `PASS` o `BLOCK` con lista de defectos indexados por código de tiempo si existen anomalías.

## Uso de skills
Aplicar [selección común](../reglas/seleccion-skills.md). Descubrir y emplear obligatoriamente:
- `remotion-render-qa`: lista de verificación de calidad técnica, visual y sonora.
- `pipeline-produccion-video`: estándares de entrega de `video-studio`.
- `testing`: criterios de validación estructurada y reproducible.
- `remotion-render`: protocolos de exportación, flags de renderizado, CRF y concurrencia.
- `remotion-studio`: previsualización e inspección interactiva previa a renders definitivos.
- `make-awesome-video`: pasada de crítica visual independiente y verificación contra storyboard.
- `earshot`: telemetría acústica BS.1770 (LUFS, True Peak, espectro, ataques y desfases) para auditar el audio sin estar "sordo".
- `real-sfx`: verificación de sincronía frame-a-frame, niveles por rol, detección de enmascaramiento y ausencia de duplicación sintética (`critique.py`, `verify.py`, `levels.py`).

## Entrega
- Hoja de contactos visual validada.
- Telemetría de audio (ebur128 / volumedetect) registrada.
- Dictamen de calidad (`PASS` / `BLOCK`) con reporte de hallazgos.

## Criterios de aceptación
- 0 artefactos de congelamiento, parpadeo, cortes negros inesperados o desalineación de audio.
- Audio estéreo balanceado sin saturación ni ahogamiento de la narración.
- Duración del video coincidente con el timeline dentro del margen de 0.05s.
