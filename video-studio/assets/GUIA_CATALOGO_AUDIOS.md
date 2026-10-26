# Guía y Catálogo Inteligente de Audios (video-studio/assets)

Esta guía clasifica la biblioteca de audio local (94 archivos analizados) para seleccionar de manera inmediata la banda sonora y los efectos adecuados según la temática, el tono emocional y el objetivo del video.

---

## 1. Mapa Semántico de Selección de Música por Tema

| Temática del Video | Pista Recomendada (`video-studio/assets/`) | Duración | Tono Emocional / Instrumentación |
|---|---|---|---|
| **Dramático / Tensión / Crudo** (Adicciones, riesgos, fentanilo, crisis) | `music/Mix - Música De Fondo Para Videos y Presentaciones/12 - Música De Fondo Inspiradora y Dramática Para Videos.mp3` | 2:09 min | Orquestal, cuerdas en crescendo, emocional, gravedad y redención |
| **Suspenso / Clímax Atmosférico** (Efectos de tormenta, peligro inminente) | `music/Mix - Lluvia Y Brillos/14 - Truenos En La Lluvia.mp3` | 2:00 min | Lluvia torrencial con truenos distantes (ideal para escenas oscuras) |
| **Ciencia / Tecnología / Divulgación** (Química, medicina, cafeína, física) | `music/ambient_curiosity.mp3` | 2:00 min | Pizzicato ligero, marimba, ritmo ágil y pedagógico sin distraer |
| **Misterio Moderno / Tecnología Profunda** (IA, algoritmos, futuro) | `music/Mix - Música De Fondo Para Videos y Presentaciones/11 - Música Cinematográfica Moderna Música Instrumental para Videos.mp3` | 3:00 min | Sintetizadores cinematográficos, pulso moderno y profundidad |
| **Corporativo / Startups / Negocios** (SaaS, productividad, finanzas, métricas) | `music/Mix - Música De Fondo Para Videos y Presentaciones/04 - Música De Fondo Para Presentaciones y Videos Corporativos.mp3` | 2:30 min | Elegante, minimalista, guitarras limpias y ritmo empresarial |
| **Motivacional / Emprendimiento** (Éxito, historias de superación) | `music/Mix - Música De Fondo Para Videos y Presentaciones/15 - Música Corporativa y Motivadora Para Videos.mp3` | 2:45 min | Acordes mayores, progresión ascendente, energía positiva |
| **Educativo / Familiar / Amigable** (Guías paso a paso, aprendizaje) | `music/Mix - Música De Fondo Para Videos y Presentaciones/20 - 🎨 Música De Fondo Para Videos Educativos Música Para Presentaciones 🎶.mp3` | 2:25 min | Didáctico, cálido, optimista y cercano |
| **Juvenil / Dinámico / Verano** (Estilo de vida, tendencias, energía) | `music/Mix - Música De Fondo Para Videos y Presentaciones/08 - Wake Up - MBB [ MÚSICA SIN COPYRIGHT ].mp3` | 3:05 min | Tropical house suave, beats frescos, estilo vlog |
| **Naturaleza / Calma / Reflexión** (Descanso, meditación, bienestar) | `music/Mix - Lluvia Y Brillos/12 - Ambiente De Lluvia.mp3` | 3:00 min | Lluvia suave continua para fondos introspectivos |

---

## 2. Efectos de Sonido (SFX) para Animación 2D

Ubicados en `video-studio/assets/sfx/`. Todos normalizados a pico de **-3.0 dBFS**:

* **`whoosh.mp3`** (Volumen sugerido en Film: `0.20`):
  - Uso: Barridos de cámara, transiciones entre actos, zooms cinéticos y movimientos rápidos de personajes.
* **`click.mp3`** (Volumen sugerido en Film: `0.22`):
  - Uso: Clics de ratón, toggles, switches, pulsación de botones y selección de opciones en interfaces.
* **`ding.mp3`** (Volumen sugerido en Film: `0.25`):
  - Uso: Descubrimientos clave, tips destacados, notificaciones exitosas y puntos de inflexión positivos.
* **`pop.mp3`** (Volumen sugerido en Film: `0.28`):
  - Uso: Aparición de burbujas, stickers, pastillas, diagramas flotantes y badges.

---

## 3. Biblioteca de Memes y Cultura de Internet (39 Audios)

Ubicados en `video-studio/assets/music/Sonidos memes/` para videos de humor, parodias y remates virales:

* **Remates cómicos y reacciones:**
  - `01 - niño gritando - efecto de sonido.mp3` (Grito cómico de sorpresa)
  - `05 - Sonido de desaparecer.mp3` (Teletransporte / desaparición instantánea)
  - `20 - ¡JIJIJA! sonido.mp3` (Risa burlona icónica)
  - `31 - AUUGHHH!.mp3` (Ronquido meme viral)
  - `34 - cristiano ronaldo siuuu reverse.mp3` (Celebración SIUUU revertida)
  - `40 - Why are you running sound effect.mp3` (Frase meme persecución)
* **Música saturada / lo-fi humorística:**
  - `07 - Musica de tutorial saturada.mp3` (Tutoriales retro / ironía)
  - `10 - Música de tutoriales pero pobre.mp3` (Música nostálgica de baja calidad)
  - `29 - Pou music with poor audio.mp3` (Música clásica de videojuego móvil)

---

## 4. Reglas de Mezcla y Balance Sonoro

1. **Auto-Ducking obligatorio:** En `Film.tsx`, la música de fondo siempre debe atenuarse automáticamente al **35% (-9 dB)** mientras el narrador habla.
2. **Cero saturación:** La mezcla final en MP4 debe tener un pico máximo inferior a **-1.0 dBFS** (verificable con `volumedetect`).
3. **Pista única de fondo:** No superponer simultáneamente dos pistas orquestales o fondos musicales que choquen armónicamente.
