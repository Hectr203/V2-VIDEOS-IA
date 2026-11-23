---
name: estilo-cartoon-editorial-3d
description: Nuevo estándar visual y motor de personajes predominante por defecto de la agencia (Estilo Cartoon Editorial 2D+3D con Tinta Negra y Elenco Modular IK). Define la biblia de estilo de personajes cartoon con contorno negro uniforme (#0b0d10), rellenos planos flat cel, ojos sólidos expresivos, cinemática inversa 2D (solveIK2D), poses y vestuarios modulares intercambiables, creación coherente de cualquier nuevo personaje temático (granjero, científico, fisiculturista, profesor, etc.), escenario 3D multipiano sin pestañas superiores e integración selectiva de recortes web e imágenes IA de Gemini cuando la historia lo amerite. Usar siempre por defecto en toda nueva producción audiovisual salvo que el usuario elija otro estilo explícitamente.
---

# Estilo Cartoon Editorial 2D+3D — Nuevo Estándar Predominante Por Defecto

## 1. Principio Rector y Reemplazo del Estándar Anterior
Este es el **nuevo lenguaje visual, gráfico y de personajes predominante por defecto** para todas las producciones audiovisuales de la agencia en Remotion, reemplazando al estilo cápsula anterior (`estilo-kiwi-kurzgesagt-3d`, que permanece disponible como opción alternativa seleccionable en el cuestionario inicial).

- **Coherencia estilística absoluta en todo personaje nuevo:**
  Todo personaje que exija el tema del video (un granjero, un profesor, un fisiculturista, una doctora, un niño nuevo, un astronauta, un científico o un personaje histórico) **DEBE crearse bajo esta misma biblia gráfica**, de modo que cualquier personaje del canal parezca dibujado por el mismo artista y pertenezca al mismo universo visual.
- **100 % Video Cinematográfico (PROHIBIDO parecer presentación o diapositivas):**
  - **Cero pestañas o encabezados superiores:** Prohibido mostrar títulos de capítulo, nombres de proyecto arriba a la izquierda o contadores de página (`1 / 14`) arriba a la derecha.
  - **Solo barra de progreso inferior:** Únicamente se permite la línea limpia `KiwiProgressBar` en el borde inferior.

## 2. Biblia de Diseño de Personajes Modulares (`video-studio/shared-art/cartoon/`)
Importar y construir siempre desde `video-studio/shared-art` (módulo `cartoon/`):

- **Tinta y acabado:**
  - Contorno negro tinta uniforme `CARTOON_INK = '#0b0d10'`, `CARTOON_STROKE = 4.4`, `strokeLinecap="round"`, `strokeLinejoin="round"`.
  - Rellenos planos opacos (*flat cel*) con paletas armónicas editoriales y contraste limpio (evitar mezclar personajes glossy 3D o trazos infantiles primitivos dentro de la misma escena).
- **Anatomía completa y articulación IK real (Cero poses estáticas rígidas):**
  - Cabeza ovalada expresiva (ancho mayor que alto), orejas redondeadas integradas, ojos circulares sólidos con parpadeo (`cartoonBlink`) y mirada direccionable (`lookX`, `lookY`).
  - Brazos (`CartoonArmIK`) y piernas (`CartoonLegIK`) articulados en 2 segmentos mediante **`solveIK2D`**, con pies aterrizados y manos intercambiables (`CartoonHand`: `abierta`, `puno`, `senalando`, `palma_arriba`).
  - Signos anatómicos obligatorios de IK para evitar rodillas cruzadas en X o codos invertidos:
    - Codo izquierdo natural hacia abajo: `bend = -1` (`+1` solo al cruzar brazos).
    - Codo derecho natural hacia abajo: `bend = +1` (`-1` solo al cruzar brazos).
    - Rodilla izquierda natural: `bend = +1` (`-1` al caminar hacia adelante); rodilla derecha: `bend = -1`.
- **Versatilidad obligatoria en cada personaje (existente o nuevo):**
  - **8 poses naturales:** `neutral`, `caminando`, `explicando`, `brazos_cruzados`, `pensativo`, `celebrando`, `triste_encogido`, `señalando`.
  - **7 expresiones + *lip-sync*:** `serio`, `enojado`, `feliz`, `triste`, `sorpresa`, `pensativo`, `hablando` (`CartoonFaceFeatures`), con soporte para `mouthOpen`, `tears` y `blush`.
  - **Vestuarios y accesorios intercambiables:** Mínimo 2–3 variantes por personaje y cumplimiento estricto de propiedad intelectual (*IP-Safe*) aplicando variaciones preventivas cuando la historia aluda a figuras o franquicias reales.
- **Elenco base reutilizable ya listo para importar:**
  - `Personaje1Base` (adulto base con bigote y gorro/sombrero, escala `1.00×`).
  - `Personaje2Nina` (niña con vestido y coletas con *follow-through*, escala `0.82×`).
  - `Personaje3Traje` (adulto alto con traje sastre y sombrero fedora, escala `1.12×`).
  - `Personaje4Marinerito` (niño con traje marinero y gorra removible, escala `0.85×`).
- **Cómo derivar un personaje nuevo según el tema:**
  - Ejemplo *Granjero*: reutilizar `sharedCartoonStyle.tsx`, proporción `1.0×`, sombrero de paja con tinta `#0b0d10`, overol con tirantes y hebillas planas, botas de lodo y horca/pala modular.
  - Ejemplo *Fisiculturista*: misma cabeza ovalada y ojos sólidos, torso trapezoidal ancho y `thickness` mayor en `CartoonArmIK` (`32–36px`) con camiseta deportiva sin mangas (`sleeveRatio: 0.28`), manteniendo exactamente el mismo trazo `4.4px`.
  - Ejemplo *Profesor / Científico*: proporción `1.08×`, bata blanca con solapas y bolsillo con bolígrafos, lentes rectangulares finos y cabello peinado en el mismo estilo.

## 3. Escenario 3D Multipiano, Ritmo y Componentes UI
Conservar la fluidez espacial 3D en Remotion (`perspective: 1200px`, `preserve-3d`) combinando el arte cartoon en el plano héroe con infografía flotante:
1. **`Z = -240px`:** Atmósfera temática continua o escenario editorial cartoon / fondo fotográfico o generado con Gemini cuando aporte sentido a la historia.
2. **`Z = 0px`:** Personajes cartoon articulados vivos (cambiando de pose, mirada y expresión cada 2–4 segundos al ritmo exacto de `timeline.json`).
3. **`Z = +90px`:** Contadores mecánicos `FlipCounter3D`, recuadros `YellowCallout3D` y píldoras `DataPill3D` sincronizados con `beatProgress`.
4. **`Z = +155px`:** `ForegroundParticles3D` o `RainOverlay` ambiental.
5. **Subtítulos (`KiwiCaptionsPro`) y Barra (`KiwiProgressBar`):** Limpios, legibles y sin colisiones con `BrandUnDatoMasCard` en el cierre.

## 4. Integración Estratégica y Meditada de Recortes Web e Imágenes IA (Gemini)
**No es obligatorio al 100 % en cada video**, sino una herramienta narrativa opcional que se activa **solo cuando realmente ayuda a entender, contextualizar o enganchar**:
- **Recortes de imágenes reales de internet:** Cuando un hecho histórico, objeto real, documento, mapa o figura pública gane claridad con material auténtico, investigar, descargar y procesar con fondo limpio/alfa en `public/images/<slug>/` e integrarlo con marco editorial, sombra suave (`cinemaShadow`) y animación orgánica junto al personaje cartoon.
- **Imágenes generadas con Gemini (suscripción disponible / subagente `image-generator`):** Cuando una escena necesite un escenario impactante o visual difícil de transmitir solo con vectores (por ejemplo, una erupción volcánica espectacular de fondo mientras el personaje cartoon explica la geología, el espacio profundo o una época histórica), generar la imagen cuidando que armonice cromáticamente y colocar al personaje cartoon actuando en primer plano con separación clara de contraste.
