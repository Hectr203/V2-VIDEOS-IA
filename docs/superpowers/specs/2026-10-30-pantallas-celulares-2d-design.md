# Especificación de Diseño de Producción: Cómo Funcionan las Pantallas de Celular (2D Remotion)

## 1. Ficha Técnica del Proyecto
- **ID del Proyecto:** `pantallas-celulares-como-funcionan-2d`
- **Título Oficial:** "Cómo Funcionan las Pantallas de Celular: De los Cristales Líquidos a los Píxeles OLED"
- **Formato:** Vertical `9:16` (1080 x 1920 px, 30 FPS).
- **Duración Estimada:** Extendido (~125 a 130 segundos / ~2 minutos).
- **Motor de Voz:** ElevenLabs (`voice_id: IKne3meq5aSn9XLyUdCD` / Charlie, `model_id: eleven_flash_v2_5`).
- **Banda Sonora Principal:** `Música Cinematográfica Moderna Música Instrumental para Videos` (`mix---música-de-fondo-para-videos-y-presentaciones-música-ci`, 183.26 s) con auto-ducking calibrado en Remotion.
- **Estilo Visual:** Editorial / Vox Stage con texturas impresas ("printed, not lit"), tramas halftone, resaltadores cinéticos, personajes anatómicos con cinemática inversa y diagramas vectoriales dinámicos.

---

## 2. Desglose Narrativo y Guion en 7 Actos

### Acto 01: La Ilusión Bajo tus Dedos (0:00 - 0:18)
- **ID Escena:** `01_ilusion_pantalla`
- **Capítulo:** `01. LA ILUSIÓN BAJO TUS DEDOS`
- **Paleta:** Editorial Cream & Dark Slate (`#111827`, `#f7f1dd`, `#06b6d4`).
- **Locución:**
  > "¿Miras la pantalla de tu celular cientos de veces al día, verdad? Pero lo que tienes bajo tus dedos no es una simple lámina de vidrio con fotos. Es una hazaña de la nanotecnología: un ejército invisible de millones de interruptores eléctricos y emisores de luz trabajando al unísono."
- **Puesta en escena & Puntos de animación:**
  - Personaje principal estilizado con articulación anatómica deslizando el dedo en su teléfono móvil.
  - Cámara realiza un zoom cinemático ultra-profundo atravesando la carcasa y el cristal Gorilla Glass.
  - Aparición de partículas de luz y capas de despiece esquemático.

### Acto 02: El Sentido del Tacto (El Panel Capacitivo) (0:18 - 0:38)
- **ID Escena:** `02_panel_tactil`
- **Capítulo:** `02. ¿CÓMO SIENTE TUS DEDOS?`
- **Paleta:** Tech Blue / Electric (`#0f172a`, `#38bdf8`, `#facc15`).
- **Locución:**
  > "Antes de ver la imagen, la pantalla tiene que sentirte. Justo debajo del cristal hay una malla invisible de electrodos microscópicos con carga electrostática. Como nuestro cuerpo conduce electricidad por los iones de la piel, al tocar el cristal distorsionas ese campo eléctrico. Un microcontrolador mide la caída de capacitancia y calcula tus coordenadas exactas en milisegundos."
- **Puesta en escena & Puntos de animación:**
  - Perspectiva isométrica de la malla transparente de electrodos de Óxido de Indio y Estaño (ITO).
  - Dedo del personaje aproximándose: visualización de campos electrostáticos (líneas de fuerza que se curvan).
  - Al contacto, generación de onda expansiva de pulso eléctrico y lectura de coordenadas `(X, Y)`.
  - Mini-gag ilustrado: guante de lana bloqueando la carga vs toque directo con la piel.

### Acto 03: LCD contra OLED (La Batalla de la Luz) (0:38 - 1:00)
- **ID Escena:** `03_lcd_vs_oled`
- **Capítulo:** `03. LCD CONTRA OLED`
- **Paleta:** Dual Split Contrast (Izquierda ámbar/gris LCD, derecha negro profundo OLED).
- **Locución:**
  > "Ahora bien, ¿cómo se genera la imagen? Hay dos grandes tecnologías. En las pantallas LCD, un foco blanco gigante detrás ilumina todo el panel, y cristales líquidos giran como persianas microscópicas para bloquear o dejar pasar la luz. ¿El problema? La luz siempre se filtra un poco, convirtiendo los negros en tonos grisáceos."
- **Puesta en escena & Puntos de animación:**
  - Modelo en corte transversal de un panel LCD: luz trasera (Backlight LED), filtros polarizadores cruzados a 90 grados y moléculas de cristal líquido rotando como hélices.
  - Demostración de fuga lumínica (*light bleeding*) que impide lograr negros absolutos.

### Acto 04: La Revolución del Píxel Orgánico (1:00 - 1:22)
- **ID Escena:** `04_revolucion_oled`
- **Capítulo:** `04. LA REVOLUCIÓN DEL PÍXEL ORGÁNICO`
- **Paleta:** OLED Deep Black & Neon Green (`#050505`, `#10b981`, `#8b5cf6`).
- **Locución:**
  > "Pero en las pantallas OLED y AMOLED no existe ningún foco trasero. Cada diminuto píxel es su propia fuente de luz orgánica independiente. Cuando la pantalla necesita mostrar color negro, el píxel simplemente se apaga por completo, logrando un contraste infinito y ahorrando batería en modo oscuro."
- **Puesta en escena & Puntos de animación:**
  - Demostración visual de la matriz OLED: píxeles que se apagan a nivel individual (0 mA de corriente).
  - Comparativa de ahorro de energía: medidor de batería con gráfica de consumo en modo oscuro vs pantalla encendida.
  - Alto contraste dinámico con sombras de oclusión ambiental.

### Acto 05: La Fábrica de Colores (Subpíxeles RGB) (1:22 - 1:44)
- **ID Escena:** `05_subpixeles_rgb`
- **Capítulo:** `05. LA FÁBRICA DE COLORES (RGB)`
- **Paleta:** Síntesis Aditiva RGB (`#dc2626`, `#16a34a`, `#2563eb` sobre carbón).
- **Locución:**
  > "¿Y cómo logra reproducir millones de colores? Si nos acercamos con un microscopio a un solo píxel, descubrimos tres hermanos inseparables: los subpíxeles Rojo, Verde y Azul. Mezclando sus intensidades lumínicas con síntesis aditiva, nuestro cerebro percibe dieciséis coma siete millones de tonalidades distintas."
- **Puesta en escena & Puntos de animación:**
  - Microscopio virtual revelando la matriz PenTile / franjas RGB.
  - Animación de mezcla aditiva: rojo + verde se fusionan para generar amarillo vibrante; rojo + verde + azul a máxima potencia generan blanco cegador.
  - Infografía con contador dinámico ascendente hasta 16.7 millones de colores.

### Acto 06: 120 Hertzios y Nanotecnología (1:44 - 2:04)
- **ID Escena:** `06_refresco_120hz`
- **Capítulo:** `06. 120 HERTZIOS Y NANOTECNOLOGÍA`
- **Paleta:** Speed Violet & Electric Lime (`#1e1b4b`, `#a855f7`, `#84cc16`).
- **Locución:**
  > "Por si fuera poco, los transistores de película delgada refrescan esta matriz hasta ciento veinte veces por segundo para que todo se mueva fluido como el agua. Millones de luces y sensores de precisión atómica coordinados en la palma de tu mano, cada vez que mandas un mensaje."
- **Puesta en escena & Puntos de animación:**
  - Comparativa visual de scroll a 60 FPS vs 120 FPS con estela de fluidez física.
  - Cámara realiza un *pull-out* majestuoso desde el interior atómico de los semiconductores hasta volver a la escala humana del usuario.

### Acto 07: Outro Oficial 'Un Dato Más' (2:04 - 2:14)
- **ID Escena:** `07_outro_canal`
- **Capítulo:** `UN DATO MÁS`
- **Paleta:** Gold Editorial (`#fffbeb`, `#fef3c7`, `#b45309`).
- **Locución:**
  > "Síguenos en nuestras redes, en Un Dato Más. Comparte curiosidades que despiertan tu mente."
- **Puesta en escena & Puntos de animación:**
  - Logotipo oficial de "Un Dato Más" con emblema vectorial de libro y destello dorado.
  - Botón interactivo `SEGUIR` con efecto de pulsación y partículas de confeti/estrellas.
  - Enlaces y menciones a redes sociales.

---

## 3. Plan de Arquitectura y Componentes Técnicos

1. **Scaffolding:** Ejecución de `crear_produccion_2d.py` para generar la estructura canónica en:
   `video-studio/projects/30 de octubre de 2026/pantallas-celulares-como-funcionan-2d/`
2. **Audio Pipeline (`prepare.py`):**
   - Integración con ElevenLabs TTS (`with-timestamps`) para sincronización fonética palabra por palabra en `timeline.json`.
   - Normalización de locución con `loudnorm` (I=-17 LUFS, TP=-2 dBFS).
   - Mezcla de música envolvente `mix---música-de-fondo-para-videos-y-presentaciones-música-ci.mp3` y efectos sonoros (SFX de switches, electricidad, zooms y clicks).
3. **Biblioteca Vectorial SVG (`src/art.tsx`):**
   - Personaje con rig IK humano anatómico (rostro expresivo, ojos con esclerótica/pupila/brillos, pestañeo natural, gesticulación de manos con dedos modelados).
   - Capas estructurales de pantalla: Gorilla Glass, malla ITO capacitiva, polarizadores, cristales líquidos, matriz OLED y subpíxeles RGB.
   - Texturas de papel crema, filtros de grano y sombra suave (`drop-card`, `drop-tape`, `feDropShadow`).
4. **Montaje Cinematográfico (`src/Film.tsx`):**
   - Transiciones continuas mediante `interpolate` y cinemática elástica.
   - Subtítulos cinéticos estilo Vox con resaltador amarillo y seguimiento por palabra.
   - Auto-ducking dinámico de la música al 20% durante locución y 35% en aperturas y pausas.
5. **Control de Calidad y Exportación (`render.mjs`):**
   - Generación de hojas de contacto (`contact-sheet.jpg`) y stills de fotogramas intermedios para auditoría visual.
   - Renderizado final en alta fidelidad `master-1080p.mp4` a 1080x1920 30fps.
   - Generación de copy 1-clic para redes sociales y reporte de consumo de créditos de ElevenLabs.
