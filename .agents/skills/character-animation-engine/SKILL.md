---
name: character-animation-engine
description: Animated hand-painted cartoon and expressive character animation engine with 31 emotional states, squash and stretch, anticipation, boiling linework, and alive fluid movement. Use to prevent rigid paper-puppet / cardboard animations and create organic, living characters.
---

# Character Animation Engine (Animación Viva de Personajes)

## Objetivo y Principio Fundamental
Erradicar animaciones rígidas tipo "títeres de cartón" o "recortes planos estáticos". Proporcionar a los agentes las reglas, matemáticas y patrones para dotar de vida orgánica a cualquier personaje (Clawd, avatares o figuras vectoriales 2D) con 31 estados emocionales, deformación elástica (*squash & stretch*), anticipación física y ritmo continuo.

## Cuándo usar
- Cuando el video requiere personajes animados que actúan, sienten, reaccionan o bailan.
- Cuando una animación se siente tiesa, robótica o sin vida.
- Al implementar transiciones de humor (asombro, alegría, miedo, furia, alivio) sin cortes bruscos.
- Al orquestar ciclos de idle (*respiración, parpadeo, vaivén corporal*) sincronizados con el tempo/BPM de la música.

## Los Tres Pilares de Animación Viva
1. **Hecho a mano (*Handmade*):** Trazos con variación orgánica, linework con ebullición (*boiling lines* a 12 fps), texturas vivas y color con cuerpo.
2. **Vivo (*Alive*):** NADA permanece congelado. Todo estado emocional tiene su propio movimiento ocioso (`feel()`). Los rostros actúan mediante anticipación, parpadeo estocástico y sobreoscilación (*overshoot*).
3. **Una sola pieza (*One Piece*):** El video tiene un arco emocional continuo. Las escenas se encadenan con transiciones motivadas (wipe de pincel, barrido con smear, corte en acción, iris).

## Principios Clásicos de Animación Aplicados al Código
- **Anticipación:** Antes de un movimiento grande, realizar uno pequeño en dirección opuesta (agacharse antes de saltar, encogerse antes de gritar).
- **Squash & Stretch (Aplastamiento y Estiramiento):** Los cuerpos se comprimen con el impacto y se estiran a altas velocidades, preservando su volumen geométrico.
- **Follow-Through & Overlapping Action (Acción Continuada):** El cabello, ropa o accesorios no se detienen al mismo tiempo que el cuerpo; tienen inercia y retraso físico.
- **Arcos de Movimiento:** Todo movimiento natural viaja en parábolas y curvas, nunca en líneas rectas mecánicas.
- **Tiempo de Lectura para el Espectador:** Separar causa y reacción. Dar tiempo al ojo humano para encontrar el punto focal antes del siguiente evento.

Para la guía completa de API y parámetros, consultar [ANIMATION_GUIDE.md](ANIMATION_GUIDE.md).
