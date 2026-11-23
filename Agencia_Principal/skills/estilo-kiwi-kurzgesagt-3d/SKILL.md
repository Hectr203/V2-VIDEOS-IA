---
name: estilo-kiwi-kurzgesagt-3d
description: Estilo visual y motor de animación predominante por defecto de la agencia (Estilo Kiwi / Kurzgesagt 3D Vivo). Combina personajes vectoriales tipo cápsula con sombreado volumétrico y rim-light, cinemática inversa 2D (IK), física de resortes WWDC, squash & stretch, profundidad espacial 3D multipiano, contadores mecánicos FlipCounter3D, recuadros amarillos, píldoras de datos, transiciones motivadas continuas y cero estética de presentación o pestañas superiores. Usar siempre por defecto en toda nueva producción audiovisual salvo que el usuario elija otro estilo explícitamente.
---

# Estilo Kiwi / Kurzgesagt 3D Vivo (Estándar Predominante por Defecto)

## 1. Principio Rector y Cero Sesgos
Este es el **estilo gráfico y de movimiento principal y por defecto** para todas las producciones audiovisuales de la agencia en Remotion, a menos que el usuario seleccione explícitamente otro estilo en el cuestionario inicial.

- **Universal y libre de sesgos temáticos:** La arquitectura visual funciona igual de bien para ciencia, medicina, historia, tecnología, finanzas, cultura, psicología o gastronomía. Las paletas atmosféricas se adaptan al tema (morado cósmico por defecto `#0f0428 → #1e0a47`, o variantes temáticas armónicas de alto contraste) conservando siempre la claridad de silueta, limpieza geométrica y profundidad 3D.
- **100 % Video Cinematográfico (PROHIBIDO parecer presentación o diapositivas):**
  - **Cero pestañas o encabezados superiores:** Prohibido colocar títulos de capítulo, nombres de proyecto en la esquina superior izquierda o contadores de página (`1 / 11`, `03 / 14`) en la esquina superior derecha.
  - **Solo barra de progreso inferior:** Únicamente se permite una línea/barra sutil en la parte inferior indicando el avance continuo del video.

## 2. Arquitectura Espacial 3D Multipiano (`perspective: 1200px`, `preserve-3d`)
Cada escena vive dentro de un escenario tridimensional determinista con paralaje real:
1. **`Z = -260px` (Atmósfera continua compartida):** `SharedCosmicBackdrop` montado de forma persistente entre escenas (degradado profundo + haces diagonales suaves + orbes bokeh flotantes). **Nunca cortar a negro entre escenas.**
2. **`Z = -85px` (Profundidad escenográfica):** Anillos orbitales inclinados (`rotateX(68deg)`), sofás volumétricos, tejido celular, paredes arteriales o estructuras geométricas de fondo.
3. **`Z = 0px` (Plano Héroe Vivo):** Personajes articulados (`KiwiCharacterIK`), avatares en aro (`KiwiAvatarPro`), órganos neón y metáforas científicas en movimiento constante.
4. **`Z = +90px` (Infografía 3D en Relieve):** Contadores mecánicos `FlipCounter3D` con volteo físico `rotateX(0 → -180deg)`, recuadros `YellowCallout3D` con borde `#facc15` y píldoras flotantes `DataPill3D`.
5. **`Z = +155px` (Primer Plano / Lente):** `ForegroundParticles3D` pasando frente a la cámara para reforzar profundidad real.

## 3. Estándar de Personajes Vivos (Cero Títeres Rígidos)
Reutilizar los componentes oficiales de `video-studio/shared-art/` (`KiwiCharacterIK`, `KiwiAvatarPro`, `solveIK`, `squashStretch`, `arcPoint`, `eyeBlinkScale`, `mouthOpenness`):
- **Silueta icónica elevada:** Cuerpo cápsula con gradiente volumétrico, *rim-light* superior y sombra de oclusión bajo barbilla/mangas; cabeza redonda con ojos grandes sólidos oscuros + destello especular nítido, cejas curvas expresivas, rubor cálido y nariz coral redonda.
- **Animación orgánica obligatoria (12 Principios de Disney + Emil Kowalski WWDC):**
  - Brazos articulados con **Cinemática Inversa 2D (`solveIK`)** moviéndose en **arcos parabólicos (`arcPoint`)**.
  - Respiración constante en torso, **parpadeo estocástico (`eyeBlinkScale`)**, cabello con retardo físico (*follow-through* / *trailing phase*) y *lip-sync* derivado de `timeline.json` (`mouthOpenness`).
  - **Anticipación** (4–6 frames en dirección opuesta antes de un salto o impacto) + **Squash & Stretch con conservación de área** (`sx = 1 + k`, `sy = 1 / sx`) + sobreoscilación física (`bounceSpring`).
  - **UI limpia sin rebotes nerviosos:** Usar `uiSpring` (amortiguación crítica `damping: 22, stiffness: 185`) para recuadros y subtítulos; reservar `bounceSpring` (`damping: 11, stiffness: 220`) para impactos, sellos y acciones de personajes.

## 4. Sincronización Exacta por Timestamps de Palabra (`timeline.json`)
- Nunca disparar los beats en frames arbitrarios. Usar `beatProgress(f, fps, startSec, durationSec)` leyendo los segundos exactos de `scene.words`:
  - Voltear `FlipCounter3D` en el frame exacto en que se pronuncia la cifra.
  - Ejecutar gestos IK, impactos, transformaciones y apariciones de `DataPill3D` exactamente en la palabra clave.
- **Subtítulos (`KiwiCaptionsPro`):** Tipografía blanca limpia en negrita sin caja oscura, con sombra suave y palabra activa resaltada en amarillo `#facc15` con leve escala (`1.07`) y margen lateral limpio (`margin: 0 7px`) para evitar que se peguen las palabras.

## 5. Transiciones Motivadas Continuas
Alternar puentes de cámara fluidos entre escenas (`zoom-dive` en Z y `whip-glide` lateral con `Easing.inOut(Easing.cubic)`) sobre el fondo compartido continuo, manteniendo fluidez absoluta tanto en formato vertical `9:16` (`1080x1920`) como panorámico `16:9` (`1920x1080`).

## 6. Biblioteca Compartida Lista para Importar
Todos los primitives y funciones físicas están centralizados y exportados desde:
- `video-studio/shared-art/math/kiwiMotion.ts`
- `video-studio/shared-art/components/KiwiPrimitives.tsx`
- Exportación unificada en `video-studio/shared-art/index.ts`
