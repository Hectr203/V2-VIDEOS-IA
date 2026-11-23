---
name: estilo-kiwi-kurzgesagt-3d
description: Estilo visual y motor de animación predominante por defecto de la agencia (Estilo Kiwi / Kurzgesagt 3D Vivo). Combina personajes vectoriales tipo cápsula con sombreado volumétrico y rim-light, cinemática inversa 2D (IK), física de resortes WWDC, squash & stretch, profundidad espacial 3D multipiano, contadores mecánicos FlipCounter3D, recuadros amarillos, píldoras de datos, transiciones motivadas continuas y cero estética de presentación o pestañas superiores. Usar siempre por defecto en toda nueva producción audiovisual salvo que el usuario elija otro estilo explícitamente.
---

# Estilo Kiwi / Kurzgesagt 3D Vivo (Estándar Predominante por Defecto)

## 1. Principio Rector y Cero Sesgos
Este es el **estilo gráfico y de movimiento principal y por defecto** para todas las producciones audiovisuales de la agencia en Remotion, a menos que el usuario seleccione explícitamente otro estilo en el cuestionario inicial.

- **Universal y libre de sesgos temáticos:** Adaptable a ciencia, medicina, historia, tecnología, finanzas, cultura, psicología o gastronomía. Las paletas atmosféricas se adaptan al tema conservando siempre silueta limpia, iluminación volumétrica y profundidad 3D.
- **100 % Video Cinematográfico (PROHIBIDO parecer presentación o diapositivas):**
  - **Cero pestañas o encabezados superiores:** Prohibido colocar títulos de capítulo, nombres de proyecto arriba a la izquierda o contadores de página (`1 / 11`, `03 / 14`) arriba a la derecha.
  - **Solo barra de progreso inferior:** Únicamente se permite una línea sutil en la parte inferior indicando el avance del video.

## 2. Arquitectura Espacial 3D Multipiano (`perspective: 1200px`, `preserve-3d`)
1. `Z = -260px`: `SharedCosmicBackdrop` persistente entre escenas (sin cortes a negro).
2. `Z = -85px`: Escenografía y anillos orbitales en perspectiva (`rotateX`).
3. `Z = 0px`: Personajes articulados (`KiwiCharacterIK`), avatares (`KiwiAvatarPro`) y diagramas neón vivos.
4. `Z = +90px`: `FlipCounter3D` (`rotateX`), `YellowCallout3D` y `DataPill3D`.
5. `Z = +155px`: `ForegroundParticles3D` en primer plano.

## 3. Físicas, IK y Biblioteca Reutilizable
Importar directamente desde `video-studio/shared-art/` (`kiwiMotion.ts` y `KiwiPrimitives.tsx`, re-exportados en `video-studio/shared-art/index.ts`):
- `solveIK`, `arcPoint`, `squashStretch`, `uiSpring`, `bounceSpring`, `beatProgress`, `eyeBlinkScale`, `mouthOpenness`.
- `KiwiCharacterIK`, `KiwiAvatarPro`, `FlipCounter3D`, `YellowCallout3D`, `DataPill3D`, `KiwiCaptionsPro`, `KiwiProgressBar`, `SharedCosmicBackdrop`, `ForegroundParticles3D`.

Para la guía completa extendida, consultar `Agencia_Principal/skills/estilo-kiwi-kurzgesagt-3d/SKILL.md`.
