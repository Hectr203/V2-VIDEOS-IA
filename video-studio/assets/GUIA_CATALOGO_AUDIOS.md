# Catálogo Maestro y Guía de Audios (414 Archivos Analizados)

Esta guía clasifica la biblioteca integral de audio de `video-studio/assets` para que los agentes de IA y creadores seleccionen de inmediato la música de fondo (BGM), efectos sonoros (SFX) y reacciones ideales para cualquier temática audiovisual.

---

## 1. Reglas Fundamentales de Audio y Anti-Saturación

1. **Voz Siempre Dominante:** La narración de voz debe entenderse de manera limpia e indiscutible sobre cualquier elemento sonoro.
2. **Auto-Ducking Obligatorio en `Film.tsx`:** La música de fondo debe atenuarse automáticamente al **35% (-9 dB)** durante cada palabra o segmento donde el narrador hable.
3. **Pico Máximo Master < -1.0 dBFS:** La mezcla final nunca debe alcanzar 0 dBFS. El headroom mínimo de seguridad es de 1 dB para evitar saturación digital en reproductores y redes sociales.
4. **SFX Normalizados a -3.0 dBFS:** Los efectos de sonido deben situarse con volúmenes en Remotion entre `0.16` y `0.24` según su impacto.
5. **Búsqueda Instantánea con CLI:** Usa `python3 video-studio/scripts/buscar_audio.py --buscar <termino>` o `--categoria <nombre>` para obtener la ruta y volumen exactos al instante.

---

## 2. Mapa Rápido de Música de Fondo por Temática (BGM)

| Temática / Emoción | Categoría Recomendada | Pista Destacada | Duración | Volumen en Remotion |
|---|---|---|---|---|
| **Drama / Peligro / Crisis** (Adicciones, alertas, tensión) | `dramatico_serio_tension` | `music/Mix - Música De Fondo Para Videos y Presentaciones/12 - Música De Fondo Inspiradora y Dramática Para Videos.mp3` | 2:09 min | `0.04` (duck a `0.014`) |
| **Terror Psicológico / Tensión Oscura** | `dramatico_terror_tension` | `music/Terror y Drama/REPULSIVE - Forgotten [COPYRIGHT FREE DARK MUSIC].mp3` | 3:22 min | `0.04` (duck a `0.014`) |
| **Ciencia / Tecnología / Divulgación** (Química, medicina, física) | `ciencia_tecnologia_curiosidad` | `music/ambient_curiosity.mp3` | 2:00 min | `0.04` (duck a `0.014`) |
| **Inteligencia Artificial / Futuro / Algoritmos** | `ciencia_tecnologia_curiosidad` | `music/Mix - Música De Fondo Para Videos y Presentaciones/11 - Música Cinematográfica Moderna Música Instrumental para Videos.mp3` | 3:00 min | `0.04` (duck a `0.014`) |
| **Corporativo / Startups / Negocios** (SaaS, productividad) | `corporativo_negocios_productividad` | `music/Mix - Música De Fondo Para Videos y Presentaciones/04 - Música De Fondo Para Presentaciones y Videos Corporativos.mp3` | 2:30 min | `0.04` (duck a `0.014`) |
| **Épico / Videojuegos / Batallas** (Megalovania, Boss fights) | `videojuegos_soundtracks` | `music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/01 - 100. MEGALOVANIA (UNDERTALE Soundtrack) - Toby Fox.mp3` | 2:40 min | `0.04` (duck a `0.014`) |
| **Calma Nostálgica / Reflexión** (Minecraft, Zelda) | `videojuegos_soundtracks` | `music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/55 - C418 - Sweden - Minecraft Volume Alpha.mp3` | 3:35 min | `0.05` (duck a `0.018`) |
| **Viajes / Vlogs / Optimismo / Verano** (Tropical house) | `viajes_vlog_verano` | `music/MUSICA para VIDEOS de VIAJE 2020 🏖/02 - Tobu - Roots House NCS - Copyright Free Music.mp3` | 3:10 min | `0.04` (duck a `0.014`) |
| **Lofi Chill / Estudio / Trabajo Relajado** | `viajes_vlog_verano` | `music/MUSICA para VIDEOS de VIAJE 2020 🏖/34 - MUSICA LoFi CHILL para VIDEOS GRATIS 2022 🌿[NOT MONETIZABLE] ✅ FREE Download 🎸.mp3` | 3:05 min | `0.04` (duck a `0.014`) |
| **Naturaleza / Lluvia / Meditación** | `naturaleza_lluvia_calma` | `music/Mix - Lluvia Y Brillos/12 - Ambiente De Lluvia.mp3` | 3:00 min | `0.06` |

---

## 3. Biblioteca Legendaria de Videojuegos (98 Soundtracks)

Ubicados en `video-studio/assets/music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/`:

* **Épicos y Combate:** Undertale (*Megalovania*, *Hopes and Dreams*), Ultrakill (*Tenebre Rosso Sangue*), Persona 5 (*Life Will Change*), Dark Souls (*Gwyn Lord of Cinder*), Super Smash Bros Ultimate (*Lifelight*), Danganronpa.
* **Calma y Nostalgia:** Minecraft (*C418 - Sweden*), Zelda (*Song of Healing*, *Midna's Lament*, *Lon Lon Ranch*), Super Mario 64 (*Dire Dire Docks*), Super Mario Galaxy (*Rosalina's Storybook*), Chrono Trigger (*Corridors of Time*), The Sims (*Buy Mode 1*), To The Moon (*For River*).
* **Aventura y Acción:** GTA San Andreas (*Theme Full*), GTA 4 (*Theme Song*), Portal 2 (*Want You Gone*), The Last of Us (*Theme*), Sonic 2 (*Aquatic Ruin*), DuckTales (*The Moon Theme*), Crash Bandicoot 3, Super Mario RPG (*Forest Maze*).
* **Misterio y Tensión:** Silent Hill 2 (*Promise Reprise*), Papers Please (*Theme Song*), Phoenix Wright (*Pressing Pursuit ~ Cornered*).

---

## 4. Biblioteca de Viajes, Verano y Vlogs (34 Pistas)

Ubicados en `video-studio/assets/music/MUSICA para VIDEOS de VIAJE 2020 🏖/`:

* **Tropical House & EDM Sin Copyright:** Tobu (*Roots*), JJD (*Adventure Glitch Hop*), Diamond Eyes (*Everything Dubstep*), Alex Menco (*Summer Chill*), Fredji (*Happy Life*), Mike Perry (*Stay Young*).
* **Lofi & Chillout:** Lofi Chill 2022, Hip Hop Chill para videos, Chill Out para trabajar relajado.
* **Aventura & Adrenalina:** Videos Adrenalina Gratis, Música de Aventura, Música Imponente de Viajes.

---

## 5. Efectos de Sonido (SFX) para Animación 2D y Edición

### A. Transiciones y Movimientos de Cámara (`sfx/Trancisiones Necesarias/`)
* **`sfx/Trancisiones Necesarias/Fast Whoosh Sound Effect.mp3`** (`vol: 0.20`): Whoosh dinámico ultrarrápido.
* **`sfx/Trancisiones Necesarias/01 - Abduction swish.wav`** (`vol: 0.18`): Swish limpio y moderno.
* **`sfx/Trancisiones Necesarias/EFECTO DE SONIDO.-TRANSICIÓN_GIRO LENTO_ZOOM _ENTRADA EXPLOSIVA.mp3`** (`vol: 0.20`): Zoom explosivo con giro.
* **`sfx/Trancisiones Necesarias/Deslizar - efecto de sonido gracioso.mp3`** (`vol: 0.22`): Deslizamiento cómico o caricaturesco.
* **`sfx/Trancisiones Necesarias/Whoosh Sound Effect HD _ No Copyright.mp3`** (`vol: 0.20`): Barrido de cámara limpio.
* **`sfx/Trancisiones Necesarias/Sonido del Click del Mouse __ Mouse Click - Sound Effect.mp3`** (`vol: 0.22`): Click de ratón / interacción.

### C. Sound Effects Populares y Virales (`sfx/sound effects/`)
* **`sfx/sound effects/YEET - Sound Effect HD.mp3`** (`vol: 0.22`): Lanzamiento con fuerza / YEET.
* **`sfx/sound effects/Bruh Sound Effect.mp3`** (`vol: 0.22`): Reacción clásica Bruh.
* **`sfx/sound effects/taco bell.m4a`** (`vol: 0.22`): Campana icónica de Taco Bell / golpe sónico.
* **`sfx/sound effects/Among us sound effect.mp3`** (`vol: 0.22`): Tensión / asesinato Among Us.
* **`sfx/sound effects/Doraemon Notification Sound.mp3`** (`vol: 0.22`): Notificación tierna y mágica.
* **`sfx/sound effects/Illuminati Confirmed.mp3`** (`vol: 0.20`): Teoría conspirativa / misterio meme.
* **`sfx/sound effects/Glitch.wav`** (`vol: 0.20`): Error visual, fallo técnico o interferencia.
* **`sfx/sound effects/Bamboo Hit.mp3`** (`vol: 0.22`): Golpe caricaturesco de bambú estilo anime.
* **`sfx/sound effects/Reveal Sound Effect.mp3`** (`vol: 0.22`): Revelación de dato o aparición.
* **`sfx/sound effects/Twitch Alert Sound Effect.m4a`** (`vol: 0.22`): Alerta digital o evento en directo.
* **`sfx/sound effects/Spider-Man 3 Meme Sound.mp3`** (`vol: 0.22`): Canción triste o momento dramático meme.

### D. Expresiones y Celebraciones (`sfx/Expresiones (Celebraciones y Asombros)/`)
* `sfx/Expresiones (Celebraciones y Asombros)/ALELUYA _ Efecto de sonido.mp3` (`vol: 0.20`): Solución milagrosa o descubrimiento triunfal.
* `sfx/Expresiones (Celebraciones y Asombros)/Coro Celestial (Efecto de Sonido) Heavenly Choir.mp3` (`vol: 0.20`): Revelación divina o epifanía cómica.
* `sfx/Expresiones (Celebraciones y Asombros)/Descargar Efecto de Sonido Acierto _ Correcto en HD.mp3` (`vol: 0.22`): Respuesta correcta o validación positiva.
* `sfx/Expresiones (Celebraciones y Asombros)/Children Celebrating Sound Effect _ Niños Celebrando.mp3` (`vol: 0.22`): Festejo y vítores en multitud.
* `sfx/Expresiones (Celebraciones y Asombros)/Asombro efecto de sonido para tus vídeos.mp3` (`vol: 0.20`): Reacción de '¡Woooow!'.

### E. Golpes, Caídas e Impactos (`sfx/Golpes y Caidas/`)
* `sfx/Golpes y Caidas/Efecto de sonido caer al piso.mp3` (`vol: 0.22`): Caída de personaje u objeto pesado.
* `sfx/Golpes y Caidas/Among Us (Kill) - Sound Effect (HD).mp3` (`vol: 0.22`): Impacto seco o eliminación.
* `sfx/Golpes y Caidas/And His Name is JOHN CENA - Sound Effect (HD).mp3` (`vol: 0.22`): Entrada triunfal sorpresiva con fanfarria.
* `sfx/Golpes y Caidas/Bruh Sound Effect _2.mp3` (`vol: 0.22`): Decepción resignada o momento incómodo.
* `sfx/Golpes y Caidas/Efecto de Sonido - Chan - Lluvia de Chanes.mp3` (`vol: 0.20`): Golpe de suspenso latino clásico.

### F. Gritos y Sustos (`sfx/Gritoss/`)
* `sfx/Gritoss/Grito de Hombre - efecto de sonido.mp3` (`vol: 0.16`): Grito cómico masculino.
* `sfx/Gritoss/Efecto de sonido - NOOO__ (grito).mp3` (`vol: 0.16`): Grito desesperado de negación.
* `sfx/Gritoss/El Tano Pasman - Nooo Noooo.mp3` (`vol: 0.16`): Clásica frustración futbolística.
* `sfx/Gritoss/Goat Scream - Origine Meme (HD).mp3` (`vol: 0.16`): Grito de cabra humana viral.
* `sfx/Gritoss/Keemstar Screaming (Gritó_) Efecto Sonido 2021_.mp3` (`vol: 0.16`): Grito meme hiperbólico.

### G. Fails y Errores (`sfx/Fails/`)
* `sfx/Fails/Descargar Efecto de Sonido Falla _ Error en HD (Sin Copyright).mp3` (`vol: 0.20`): Sonido oficial de fallo de sistema.
* `sfx/Fails/Disco rayado ORIGINAL Y SIN REPETICIONES.mp3` (`vol: 0.20`): Detención abrupta de la música o situación incómoda.
* `sfx/Fails/Cuak Efecto de Sonido Para Vídeos - Efecto de Sonido Cuak.mp3` (`vol: 0.20`): Remate cómico de desilusión.
* `sfx/Fails/Efecto de sonido abucheo.mp3` (`vol: 0.20`): Rechazo del público ante una mala idea.

### H. Risas y Humor (`sfx/Risas/`)
* `sfx/Risas/Risitas_ meme Original.mp3` (`vol: 0.20`): Carcajada asmática viral de Risitas.
* `sfx/Risas/La risa de Don Ramón - Memes _shorts.mp3` (`vol: 0.20`): Risa burlona nostálgica.
* `sfx/Risas/Estatua de tigre riendo.mp3` (`vol: 0.20`): Risa aguda descontrolada.

### I. Extras de Caricatura y Finanzas (`sfx/Extras/`)
* `sfx/Extras/Cash SFX _13 _ Dinero Efecto de Sonido.mp3` (`vol: 0.22`): Sonido de caja registradora / dinero.
* `sfx/Extras/Cartoon Boing (Spring Sound) - Sound Effects for Editing.mp3` (`vol: 0.22`): Rebote de resorte elástico.
* `sfx/Extras/Cartoon Ricochet Sound Effect.mp3` (`vol: 0.20`): Rebote metálico de bala caricaturesca.
* `sfx/Extras/Efecto de una bomba.mp3` (`vol: 0.20`): Explosión de dibujo animado.

### J. Stingers de Terror y Suspenso (`music/Terror y Drama/`)
* `music/Terror y Drama/Inception BWONG Sound.mp3` (`vol: 0.20`): Golpe sónico monumental de intriga.
* `music/Terror y Drama/Cinema Sins (Dun) - Sound Effect (HD).mp3` (`vol: 0.20`): Golpe de pecado o error detectado.
* `music/Terror y Drama/Dross - Perturbador [HQ Piano Cover].mp3` (`vol: 0.20`): Acorde disonante perturbador.
* `music/Terror y Drama/Among Us (Role Reveal) - Sound Effect (HD).mp3` (`vol: 0.20`): Revelación de sospechoso o impostor.
* `music/Terror y Drama/Biohazard Alarm[WARNING_ The sound is very LOUD].mp3` (`vol: 0.16`): Alarma industrial de peligro.

---

## 6. Cómo Usar Audios en Remotion con `staticFile()`

```tsx
import { Audio, staticFile } from 'remotion';

// 1. Música de fondo con auto-ducking:
<Audio
  src={staticFile('music/Los MEJORES SOUNDTRACKS de los VIDEOJUEGOS/55 - C418 - Sweden - Minecraft Volume Alpha.mp3')}
  volume={(frame) => {
    const isSpeaking = voiceRanges.some(([s, e]) => frame >= s && frame <= e);
    return isSpeaking ? 0.018 : 0.05;
  }}
/>

// 2. Efecto de sonido puntual (SFX):
<Sequence from={90} durationInFrames={30}>
  <Audio
    src={staticFile('sfx/sound effects/YEET - Sound Effect HD.mp3')}
    volume={0.22}
  />
</Sequence>
```

