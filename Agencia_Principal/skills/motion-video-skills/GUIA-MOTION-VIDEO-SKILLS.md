# Guía Integral de Motion & Video Skills de Código Abierto

Esta suite reúne 16 habilidades avanzadas de animación, dirección cinematográfica, estilos editoriales y motion graphics de código abierto, diseñadas para potenciar la creación de videos profesionales en la agencia eliminando animaciones acartonadas y dotando de vida orgánica a cada producción.

---

## 1. Categorías y Catálogo de Habilidades (16 Skills)

### A. Principios Fundamentales del Movimiento & Físicas (Cero Títeres Rígidos)
| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **motion-design** | `skills/motion-design/SKILL.md` | Los 12 principios clásicos de Disney adaptados a código: squash & stretch, anticipación, arcos, follow-through, timing y físicas de resortes. |
| **animation-basics** | `skills/animation-basics/SKILL.md` | Fundamentos teóricos del movimiento, curvas de aceleración (easing) y coreografía temporal para evitar movimientos mecánicos. |
| **character-animation-engine** | `skills/character-animation-engine/SKILL.md` | Motor de animación viva de personajes: 31 estados emocionales con overshoot, linework con boil a 12 fps, deformación elástica y sincronización con beats. |

### B. Estilos Editoriales, Documental & Collage (Estilo Vox / Scrapbook)
| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **vox-explainer** | `skills/vox-explainer/SKILL.md` | Pipeline integral para videos explicativos y ensayos documentales estilo Vox (guión, keyframes, locución y montaje). |
| **vox-style-animation** | `skills/vox-style-animation/SKILL.md` | Estética de imprenta ("printed, not lit"): papel crema, trama de medios tonos halftone, resaltador amarillo, anotaciones y recortes. |
| **documentary-narrative-engine** | `skills/documentary-narrative-engine/SKILL.md` | Motor narrativo para convertir temas complejos en guiones con estructura de 5 actos y beats visuales cinematográficos. |
| **documentary-image-prompts** | `skills/documentary-image-prompts/SKILL.md` | Generación de prompts para recopilación e investigación de imágenes reales, históricas y collage con marcas de tiempo. |
| **editorial-paper-collage-animation** | `skills/editorial-paper-collage-animation/SKILL.md` | Técnicas de auto-ensamblaje y composición animada de capas de collage y recortes de papel. |
| **motion** | `skills/motion/SKILL.md` | Transformación de imágenes de referencia en clips de animación estilo scrapbook retro. |

### C. Animación Dibujada a Mano & Pizarra Explicativa
| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **handdraw-skill** | `skills/handdraw-skill/SKILL.md` | Motor determinista trazo a trazo para explicaciones en pizarra, diagramas bocetados y animaciones SVG dibujadas a mano. |

### D. Videos de Producto, Lanzamiento & Motion Graphics
| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **make-awesome-video** | `skills/make-awesome-video/SKILL.md` | Flujo de dirección cinematográfica profesional: descomposición plano a plano, beat sync, crítica visual y notas de dirección de cámara. |
| **video-shotcraft** | `skills/video-shotcraft/SKILL.md` | Creación de videos cinemáticos de producto con Remotion, shot cards, plantilla Ink Press, beat sync y curaduría de SFX. |
| **brewreel** | `skills/brewreel/SKILL.md` | Videos promocionales verticales 9:16 para redes sociales, recetas por industria y selección de B-roll. |
| **motion-graphics** | `skills/motion-graphics/SKILL.md` | Motion graphics frame-exact para logos animados, tipografía cinética y clips de marca exportados a MP4. |

### E. Motores Programáticos Complementarios
| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **motion-canvas** | `skills/motion-canvas/SKILL.md` | Framework de animación 2D programática estructurada mediante generadores y señales matemáticas. |
| **motion-canvas-agent** | `skills/motion-canvas-agent/SKILL.md` | Herramientas de inspección, verificación visual y renderizado automatizado para Motion Canvas. |

---

## 2. Cómo se Integran en el Flujo de la Agencia

1. **Orquestación Transparente del Asistente Principal:**
   El usuario nunca tiene que elegir skills ni comandos técnicos. El Asistente Principal formula las preguntas de contenido (tema, giro narrativo, formato, duración, voz) e internamente decide qué roles y qué skills activar.

2. **Cero Marionetas de Cartón:**
   - Todo personaje u objeto animado debe aplicar principios de `motion-design` y `character-animation-engine`: anticipación previa al movimiento, amortiguación crítica, respiración orgánica y micro-movimientos continuos.
   - Las transiciones no son simples cortes; utilizan puentes continuos (`remotion-continuous-motion`, `make-awesome-video`, `vox-style-animation`).

3. **Curaduría de Audio y Sonoridad EBU R128:**
   - La selección de audios de fondo y efectos (SFX) mapea el género exacto del guion desde el catálogo de 381 audios de la agencia.
   - Normalización de decibeles a -22 / -24 LUFS y auto-ducking dinámico al 30-35% durante la voz narradora.

4. **Investigación e Integración de Material Real:**
   - Prohibido limitarse a gráficos sintéticos genéricos.
   - Recopilación de imágenes y documentos auténticos, procesados con canal alfa transparente e integrados editorialmente con la escenografía vectorial SVG.
