---
name: estilo-cartoon-editorial-3d
description: Nuevo estándar visual y motor de personajes predominante por defecto de la agencia (Estilo Cartoon Editorial 2D+3D con Tinta Negra y Elenco Modular IK). Define la biblia de estilo de personajes cartoon con contorno negro uniforme (#0b0d10), rellenos planos flat cel, ojos sólidos expresivos, cinemática inversa 2D (solveIK2D), poses y vestuarios modulares intercambiables, creación coherente de cualquier nuevo personaje temático (granjero, científico, fisiculturista, profesor, etc.), escenario 3D multipiano sin pestañas superiores e integración selectiva de recortes web e imágenes IA de Gemini cuando la historia lo amerite. Usar siempre por defecto en toda nueva producción audiovisual salvo que el usuario elija otro estilo explícitamente.
---

# Estilo Cartoon Editorial 2D+3D — Nuevo Estándar Predominante Por Defecto

Este es el **estándar visual y de personajes predominante por defecto** de la agencia en Remotion (reemplaza a `estilo-kiwi-kurzgesagt-3d` como opción por defecto; el estilo Kiwi permanece disponible como alternativa seleccionable).

- **Elenco base y motor compartido:** Importar desde `video-studio/shared-art/` (`sharedCartoonStyle.tsx`, `solveIK2D`, `CartoonArmIK`, `CartoonLegIK`, `CartoonHand`, `CartoonFaceFeatures`, `Personaje1Base`, `Personaje2Nina`, `Personaje3Traje`, `Personaje4Marinerito`).
- **Creación coherente de personajes nuevos:** Cualquier personaje nuevo que requiera el guion (granjero, profesor, fisiculturista, científico, niño nuevo, etc.) se construye con la misma tinta `#0b0d10` (`4.4px`), rellenos planos *flat cel*, cabeza ovalada expresiva, ojos sólidos y extremidades IK de 2 segmentos (8 poses, 7 expresiones, vestuarios intercambiables y adaptación IP-Safe).
- **Escenario 3D multipiano y cero pestañas superiores:** `perspective: 1200px`, `FlipCounter3D`, `YellowCallout3D`, `DataPill3D`, `KiwiCaptionsPro`, `KiwiProgressBar` (prohibidos encabezados de diapositiva o contadores superiores).
- **Recortes web e imágenes IA de Gemini (opcional y meditado):** Integrar recortes reales descargados o fondos/insertos generados con Gemini (`image-generator`) solo cuando aporten claridad o impacto real a la historia (ej. volcán en erupción de fondo mientras el personaje explica).

Para la guía completa extendida, consultar `Agencia_Principal/skills/estilo-cartoon-editorial-3d/SKILL.md`.
