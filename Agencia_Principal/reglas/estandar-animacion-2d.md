# Estándar de Producción y Animación 2D en Remotion

Aplicar la [precedencia](precedencia.md) y el [contrato común](../agentes/contrato-agente.md).

## 1. Principio Fundamental de Calidad Visual
Cualquier agente o inteligencia artificial que trabaje en la generación de videos animados en `video-studio` debe alcanzar el estándar cinematográfico establecido en `fentanilo-2d-v2`:
- **Prohibido el uso de emojis, iconos de fuentes (FontAwesome, Lucide plano) o cajas rectangulares toscas** como sustituto de ilustración.
- **Todo elemento visual relevante debe ser arte vectorial SVG original** construido con gradientes multicapa, sombras proyectadas y filtros de iluminación sutiles.
- **Los personajes deben ser riggeados desde cero**:
  - Extremidades articuladas en dos segmentos usando cinemática inversa (`joint()`).
  - Torso con ciclo de respiración (`breathe = wave(f, speed, amp)`).
  - Ojos con ciclo de parpadeo estocástico (`blink`).
  - Cabello compuesto por mechones independientes con retardo físico (fase desfasada respecto al movimiento de la cabeza).
  - Expresiones faciales coherentes con la emoción del guion (`happy`, `pain`, `sleep`, `worry`, `dead`).

## 2. Metáforas Visuales y Explicación de Conceptos Complejos
Para cualquier temática (ciencia, inteligencia artificial, tecnología, economía, etc.):
- **Modelado de sistemas**: En lugar de texto estático, representar los procesos con metáforas mecánicas o biológicas activas (ej. cerraduras y llaves para interacciones moleculares o permisos; redes neuronales con pulsos eléctricos luminosos para procesamiento de datos; órganos o sistemas con ritmos acelerados o desacelerados).
- **Animaciones matemáticas reactivas**: Toda oscilación o movimiento continuo debe emplear funciones deterministas basadas en el frame actual (`f`): `wave()`, `ease()`, `mix()`, `clamp()`, `seeded()`.

## 3. Arquitectura y Almacenamiento Centralizado de Recursos
Para evitar dispersión de archivos y facilitar la escalabilidad de múltiples producciones:
1. **Directorio de la Producción**: `video-studio/productions/<id-produccion>/`
   - `storyboard.json`: Declaración de escenas, capítulos, paletas y textos.
   - `prepare.py`: Pipeline de audio TTS (Edge TTS con WordBoundary) y síntesis musical.
   - `timeline.json`: Marcas temporales calculadas en frames a 30 fps.
   - `subtitles.srt`: Subtítulos cronometrados.
   - `render.mjs`: Orquestador de renderizado Remotion.
   - `renders/`: Stills temporales, mosaico de control y borrador (ignorado en Git).
2. **Componentes Remotion**: `video-studio/remotion/src/projects/<id-produccion>/`
   - `art.tsx`: Biblioteca de definiciones SVG y componentes ilustrados.
   - `Film.tsx`: Montaje con cámara dinámica, transiciones y subtítulos cinéticos.
   - `timeline.json`: Datos de sincronización.
3. **Assets Públicos**: `video-studio/remotion/public/<id-produccion>/`
   - Locuciones (`<scene_id>.mp3`), música (`score.wav`), tipografía.
4. **Salida Final**: `video-studio/output/<id-produccion>.mp4`

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
4. **Render Draft 720p**: Verificar fluidez audiovisual.
5. **Render Master 1080p (CRF 17)**: Entrega en alta definición y verificación con `ffprobe`.
