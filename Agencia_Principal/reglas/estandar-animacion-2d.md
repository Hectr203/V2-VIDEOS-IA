# Estándar de Producción y Animación 2D en Remotion

Aplicar la [precedencia](precedencia.md) y el [contrato común](../agentes/contrato-agente.md).

## 1. Principio Fundamental de Calidad Visual
Cualquier agente o inteligencia artificial que trabaje en la generación de videos animados en `video-studio` debe alcanzar el estándar cinematográfico establecido en `fentanilo-2d-v2`:
- **Prohibido el uso de emojis, iconos de fuentes (FontAwesome, Lucide plano) o cajas rectangulares toscas** como sustituto de ilustración.
- **Todo elemento visual relevante debe ser arte vectorial SVG original** construido con gradientes multicapa, sombras proyectadas y filtros de iluminación sutiles.
- **Los personajes deben ser riggeados desde cero y exhibir animación viva (PROHIBIDOS TÍTERES DE CARTÓN O FIGURAS RÍGIDAS):**
  - Extremidades articuladas en dos segmentos usando cinemática inversa (`joint()`).
  - Torso con ciclo de respiración (`breathe = wave(f, speed, amp)`).
  - Ojos con ciclo de parpadeo estocástico (`blink`) y pupilas reactivas al punto focal de la escena.
  - Cabello compuesto por mechones independientes con retardo físico y follow-through (fase desfasada respecto a la cabeza).
  - Expresiones faciales orgánicas con transiciones suaves y overshoot (`happy`, `pain`, `sleep`, `worry`, `dead`, etc.).
  - Físicas de resorte (*springs*), anticipación previa al movimiento (crouch o contra-giro) y aplastamiento/estiramiento (*squash & stretch*) manteniendo volumen constante. Queda terminantemente prohibido dejar figuras estáticas o recortes planos tiesos.
- **Integración obligatoria de imágenes del mundo real (Universal):**
  - Para todo video, es forzoso investigar a fondo la temática y descargar imágenes reales y auténticas (fotografías históricas, documentos originales, retratos de creadores o protagonistas, bocetos, patentes, sprites o consolas auténticas), evitando por completo sustitutos sintéticos o ilustraciones genéricas.
  - Las imágenes deben procesarse con recorte limpio y canal alfa transparente (`.png`) en `public/images/<slug>/`.
  - En `art.tsx` y `Film.tsx`, se integran con tratamiento editorial cinematográfico: marcos sutiles, sombras proyectadas (`drop-shadow`), badges cronológicos y micro-animaciones combinadas con la escenografía vectorial SVG.
## 2. Metáforas Visuales y Explicación de Conceptos Complejos
Para cualquier temática (ciencia, inteligencia artificial, tecnología, economía, etc.):
- **Modelado de sistemas**: En lugar de texto estático, representar los procesos con metáforas mecánicas o biológicas activas (ej. cerraduras y llaves para interacciones moleculares o permisos; redes neuronales con pulsos eléctricos luminosos para procesamiento de datos; órganos o sistemas con ritmos acelerados o desacelerados).
- **Animaciones matemáticas reactivas**: Toda oscilación o movimiento continuo debe emplear funciones deterministas basadas en el frame actual (`f`): `wave()`, `ease()`, `mix()`, `clamp()`, `seeded()`.

## 3. Arquitectura y Organización por Fecha de Creación
Para evitar la dispersión de archivos y mantener el orden histórico cuando se acumulan decenas o cientos de producciones, **los proyectos se organizan cronológicamente dentro de carpetas por fecha de creación**:
`video-studio/projects/<DD de mes de YYYY>/<slug>/`
*(Ejemplo: `video-studio/projects/25 de octubre de 2026/efectos-drogas-jovenes-2d/`)*

**Queda estrictamente prohibido guardar proyectos, archivos o enlaces simbólicos en la raíz de `video-studio/projects/`. Todo proyecto debe residir forzosamente dentro de su carpeta de fecha de creación (`video-studio/projects/<DD de mes de YYYY>/<slug>/`) para evitar cualquier duplicidad.** Esta regla es validada automáticamente mediante un hook de ciclo de vida.

Estructura canónica de cada proyecto:
1. `project.json`: Metadatos del proyecto (título, descripción, resolución, versión, autor).
2. `storyboard.json`: Declaración de escenas, capítulos, paletas, textos y notas editoriales.
3. `timeline.json`: Marcas temporales calculadas a 30 fps con marcas por palabra.
4. `subtitles.srt`: Subtítulos cronometrados portables.
5. `prepare.py`: Pipeline de audio TTS (Edge TTS con WordBoundary) y síntesis musical procedural.
6. `render.mjs`: Orquestador autónomo de renderizado Remotion (Full HD, borrador y stills).
7. `src/`:
   - `index.tsx`: Entrypoint y registro autónomo de Remotion (`registerRoot`).
   - `Film.tsx`: Montaje con cámara dinámica, secuencias, audio y subtítulos cinéticos.
   - `art.tsx`: Biblioteca de definiciones SVG, rigging IK, personajes y elementos reutilizables.
   - `timeline.json`: Datos de sincronización accesibles por el bundler.
8. `public/`:
   - Locuciones (`<scene_id>.mp3`), música (`score.wav`), tipografía empaquetada.
9. `renders/`:
   - `master-1080p.mp4`: Video final Full HD de alta calidad (CRF 17).
   - `preview-720p.mp4`: Previsualización borrador para iteración rápida.
   - `contact-sheet.jpg`: Mosaico visual de control de calidad.
   - `stills/`: Capturas fotograma a fotograma de cada escena.

## 4. Puerta de Calidad Obligatoria Pre-Render (Contact Sheet Gate)
Ningún agente puede entregar o considerar completado un video sin cumplir este protocolo:
1. **Render de Stills**: Generar fotogramas de control para el 100% de las escenas (`render.mjs --stills`).
2. **Generación del Mosaico (Contact Sheet)**:
   ```bash
   ffmpeg -v error -y -pattern_type glob -i 'renders/*.png' \
     -vf 'scale=240:-1,tile=4x4:padding=6:margin=6' -frames:v 1 \
     renders/contact-sheet.jpg
   ```
3. **Inspección Visual**: Verificar que no existan cortes de texto, solapamientos, desalineaciones ni desproporciones.
4. **Render Draft 720p**: Verificar fluidez audiovisual (`render.mjs --draft`).
5. **Render Master 1080p (CRF 17)**: Entrega en alta definición y verificación con `ffprobe`.

## 5. Catálogo de Arte Compartido (`video-studio/shared-art/`)
Para evitar duplicación excesiva de código SVG y cinemática en cada proyecto:
- Rigs anatómicos universales (`HandRigs`, `ParticleSystems`, `BaseBodies`) deben consumirse desde `../../shared-art/` cuando aplique.
- Cada proyecto mantiene su propio `art.tsx` para ilustraciones temáticas específicas del guion, garantizando que el proyecto sea ejecutable de forma autónoma.

## 6. Soporte Multi-Aspect Ratio (Vertical y Horizontal)
Todo proyecto canónico debe admitir composiciones verticales (9:16) y horizontales (16:9):
- **Vertical (9:16, 1080x1920)**: Orientado a TikTok, Instagram Reels y YouTube Shorts (`node render.mjs`).
- **Horizontal (16:9, 1920x1080)**: Orientado a YouTube widescreen (`node render.mjs --horizontal`).
- **Ambos formatos simultáneos**: `node render.mjs --aspect=both`.
- En `Film.tsx`, la composición debe adaptar su viewBox o escala mediante las props de resolución (`width`, `height`).

## 7. Estándar de Audio, Mezcla y Anti-Saturación
1. **Claridad de la Narración:** La voz en off debe dominar la mezcla de forma limpia e inteligible en todo momento.
2. **Auto-Ducking Obligatorio:** En `Film.tsx`, la música de fondo debe descender automáticamente al **35% (-9 dB)** durante cada intervalo donde el narrador pronuncie palabras (`voiceRanges`).
3. **Control de Headroom:** El pico máximo de la mezcla en el archivo final MP4 debe situarse estrictamente por debajo de **-1.0 dBFS** (verificable con `ffmpeg -af volumedetect`).
4. **Catálogo Centralizado de Audios (381 pistas):** Consulta la guía [`video-studio/assets/GUIA_CATALOGO_AUDIOS.md`](../../video-studio/assets/GUIA_CATALOGO_AUDIOS.md) y [`video-studio/assets/catalogo_audios.json`](../../video-studio/assets/catalogo_audios.json).
5. **CLI de Búsqueda Instantánea:** Utiliza `python3 video-studio/scripts/buscar_audio.py --buscar <query>` para localizar pistas y efectos de sonido con su volumen recomendado.
6. **Curaduría y Giro Temático del Video (MANDATORIO):** La música y los efectos sonoros deben elegirse siempre en consonancia estricta con el género, tono emocional y peso narrativo del video (prohibido reusar la misma música para todo):
   - *Videojuegos / Gaming / Retro:* Soundtracks legendarios de videojuegos (`Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS`) y SFX auténticos de 8-bit/16-bit (saltos, monedas, power-up, muerte).
   - *Dramático / Tensión / Crudo:* Cuerdas orquestales con crescendo, atmósferas oscuras o lluvia con truenos distantes.
   - *Ciencia / Tecnología / Divulgación:* Pizzicato ágil, marimba o sintetizadores modernos que estimulen la curiosidad intelectual.
   - *Corporativo / Emprendimiento / Negocios:* Guitarras limpias, ritmo minimalista y confianza profesional.
   - *Viajes / Vlogs / Verano:* Tropical house, lofi chillout y beats frescos y optimistas.
   - *Humor / Parodia / Viral:* Memes virales, reacciones sonoras, cuaks cómicos y discos rayados.
7. **Análisis Acústico de Decibeles y Calibración Dinámica de Ganancia:**
   - Cada pista de música o SFX posee ganancias masterizadas de fábrica muy dispares (algunas pistas de videojuegos o EDM superan -10 LUFS, mientras piezas acústicas caen a -24 LUFS).
   - En `prepare.py`, es forzoso medir el nivel de decibeles (`ffmpeg -af volumedetect` o `ebur128`) antes del renderizado.
   - Normalizar la música de fondo a un target base de -22 a -24 LUFS antes de alimentarla a Remotion para asegurar que ninguna melodía enmascare la voz.
   - Normalizar los SFX y limitar picos a -6 dBFS para mantener transiciones de alto impacto sin saturación ni sustos auditivos.
   - Auto-ducking en `Film.tsx`: reducción al 30-35% durante el habla y ganancia completa en pausas dramáticas.
   - El master final renderizado debe cumplir rigurosamente el estándar EBU R128 (-18 a -19 LUFS integrado, True Peak < -1.0 dBFS).

## 8. Documentación Técnica de Referencia
Para consultar el manual operativo completo de agentes, convenciones de paths y anti-alucinación, leer:
- Documento maestro: [`docs/GUIA_COMPLETA_PRODUCCION_2D.md`](../../docs/GUIA_COMPLETA_PRODUCCION_2D.md)
- Catálogo de Audios: [`video-studio/assets/GUIA_CATALOGO_AUDIOS.md`](../../video-studio/assets/GUIA_CATALOGO_AUDIOS.md)
- Manual de agentes en la raíz: [`README.md`](../../README.md)
- Suite oficial de habilidades Remotion: [`GUIA-REMOTION-DEV-SKILLS.md`](../skills/remotion-dev-skills/GUIA-REMOTION-DEV-SKILLS.md)
- Suite de habilidades de Motion y Dirección: [`GUIA-MOTION-VIDEO-SKILLS.md`](../skills/motion-video-skills/GUIA-MOTION-VIDEO-SKILLS.md)

## 9. Estándares Oficiales de Remotion y Motion Skills (`remotion-dev/skills` & `motion-video-skills`)
1. **Aislamiento de `useCurrentFrame()`:** Mantener `useCurrentFrame()` en los componentes hoja más pequeños que lo requieran (títulos individuales, overlays o visualizadores) para evitar que la composición completa se re-renderice en cada fotograma.
2. **Propiedades CSS Directas y `perceptual-scale`:** Emplear propiedades directas `scale`, `translate` y `rotate` en lugar de cadenas concatenadas en `transform`. En toda animación de zoom o escala, utilizar `{ output: 'perceptual-scale' }` dentro de `interpolate()` para asegurar aceleración perceptualmente natural.
3. **Curvas Easing y Físicas de Resorte:** Utilizar `Easing.bezier()` y `Easing.spring()` para desaceleraciones suaves y físicas de impacto creíbles.
4. **Cero transiciones CSS o Tailwind impuras:** Toda animación debe derivarse determinísticamente del frame (`f`). Prohibir clases como `animate-*` o `transition: all`.
5. **Animación Orgánica y Expresiva (`character-animation-engine` & `motion-design`):** Todo elemento debe contar con anticipación física previa al movimiento, amortiguación crítica (damping ratio 1.0 estándar, 0.8 con inercia), deformación elástica (squash & stretch) y linework con ebullición sutil a 12 fps para evitar la sensación de títeres de cartón rígidos.
6. **Dirección Cinematográfica y Beat Sync (`make-awesome-video` & `video-shotcraft`):** Toda producción debe apoyarse en tarjetas de recetas de planos (*shot cards*), encadenamiento con puentes visuales continuos y sincronización rítmica con la pista de audio antes de autorizar el render final.
7. **Previsualización en Remotion Studio:** Abrir Remotion Studio (`npx remotion studio --no-open`) para inspección interactiva y ajuste de timing antes de solicitar renderizados pesados a disco.

