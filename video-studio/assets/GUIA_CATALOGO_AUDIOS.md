# Catálogo Maestro y Guía de Audios (381 Archivos Analizados)

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
| **Drama / Peligro / Crisis** (Adicciones, fentanilo, alertas) | `dramatico_serio_tension` | `music/Mix - Música De Fondo Para Videos y Presentaciones/12 - Música De Fondo Inspiradora y Dramática Para Videos.mp3` | 2:09 min | `0.04` (duck a `0.014`) |
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

### A. Transiciones y Movimientos de Cámara (`music/Trancisiones Necesarias/` + `sfx/`)
* **`sfx/whoosh.mp3`** (`vol: 0.20`): Barrido estándar de cámara entre escenas.
* **`music/Trancisiones Necesarias/Fast Whoosh Sound Effect.mp3`** (`vol: 0.20`): Whoosh dinámico ultrarrápido.
* **`music/Trancisiones Necesarias/01 - Abduction swish.wav`** (`vol: 0.18`): Swish limpio y moderno.
* **`music/Trancisiones Necesarias/EFECTO DE SONIDO.-TRANSICIÓN_GIRO LENTO_ZOOM _ENTRADA EXPLOSIVA.mp3`** (`vol: 0.20`): Zoom explosivo con giro.
* **`music/Trancisiones Necesarias/Deslizar - efecto de sonido gracioso.mp3`** (`vol: 0.22`): Deslizamiento cómico o caricaturesco.

### B. Micro-Interacciones de UI (`sfx/`)
* **`sfx/click.mp3`** (`vol: 0.22`): Pulsación de botones, switches, toggles.
* **`sfx/ding.mp3`** (`vol: 0.24`): Aciertos, notificaciones, tips clave y descubrimientos.
* **`sfx/pop.mp3`** (`vol: 0.26`): Aparición de burbujas, badges, tarjetas flotantes y pastillas.

### C. Expresiones y Celebraciones (`music/Expresiones (Celebraciones y Asombros)/`)
* `ALELUYA _ Efecto de sonido.mp3` (`vol: 0.20`): Solución milagrosa o descubrimiento triunfal.
* `Coro Celestial (Efecto de Sonido) Heavenly Choir.mp3` (`vol: 0.20`): Revelación divina o epifanía cómica.
* `Descargar Efecto de Sonido Acierto _ Correcto en HD.mp3` (`vol: 0.22`): Respuesta correcta o validación positiva.
* `Children Celebrating Sound Effect _ Niños Celebrando.mp3` (`vol: 0.22`): Festejo y vítores en multitud.
* `Asombro efecto de sonido para tus vídeos.mp3` (`vol: 0.20`): Reacción de '¡Woooow!'.

### D. Golpes, Caídas e Impactos (`music/Golpes y Caidas/`)
* `Efecto de sonido caer al piso.mp3` (`vol: 0.22`): Caída de personaje u objeto pesado.
* `Among Us (Kill) - Sound Effect.mp3` (`vol: 0.22`): Impacto seco o eliminación.
* `And His Name is JOHN CENA.mp3` (`vol: 0.22`): Entrada triunfal sorpresiva con fanfarria de trompetas.
* `Bruh Sound Effect _2.mp3` (`vol: 0.22`): Decepción resignada o momento incómodo.
* `Efecto de Sonido - Chan - Lluvia de Chanes.mp3` (`vol: 0.20`): Golpe de suspenso latino clásico.

### E. Gritos y Sustos (`music/Gritoss/`)
* `Grito de Hombre - efecto de sonido.mp3` (`vol: 0.16`): Grito cómico masculino.
* `Efecto de sonido - NOOO__ (grito).mp3` (`vol: 0.16`): Grito desesperado de negación.
* `El Tano Pasman - Nooo Noooo.mp3` (`vol: 0.16`): Clásica frustración futbolística.
* `Goat Scream - Origine Meme.mp3` (`vol: 0.16`): Grito de cabra humana viral.
* `Keemstar Screaming (Gritó_) Efecto Sonido 2021.mp3` (`vol: 0.16`): Grito meme hiperbólico.

### F. Fails y Errores (`music/Fails/`)
* `Descargar Efecto de Sonido Falla _ Error en HD.mp3` (`vol: 0.20`): Sonido oficial de fallo de sistema.
* `Disco rayado ORIGINAL Y SIN REPETICIONES.mp3` (`vol: 0.20`): Detención abrupta de la música o situación incómoda.
* `Cuak Efecto de Sonido Para Vídeos.mp3` (`vol: 0.20`): Remate cómico de desilusión.
* `Efecto de sonido abucheo.mp3` (`vol: 0.20`): Rechazo del público ante una mala idea.

### G. Risas y Humor (`music/Risas/`)
* `Risitas_ meme Original.mp3` (`vol: 0.20`): Carcajada asmática viral de Risitas.
* `La risa de Don Ramón.mp3` (`vol: 0.20`): Risa burlona nostálgica.
* `Estatua de tigre riendo.mp3` (`vol: 0.20`): Risa aguda descontrolada.

### H. Stingers de Terror y Suspenso (`music/Terror y Drama/`)
* `Inception BWONG Sound.mp3` (`vol: 0.20`): Golpe sónico monumental de intriga.
* `Cinema Sins (Dun) - Sound Effect.mp3` (`vol: 0.20`): Golpe de pecado o error detectado.
* `Dross - Perturbador [HQ Piano Cover].mp3` (`vol: 0.20`): Acorde disonante perturbador.
* `Among Us (Role Reveal) - Sound Effect.mp3` (`vol: 0.20`): Revelación de sospechoso o impostor.
* `Biohazard Alarm.mp3` (`vol: 0.16`): Alarma industrial de contaminación biológica o peligro radioactivo.

### I. Extras de Caricatura y Finanzas (`music/Extras/`)
* `Cash SFX _ Dinero Efecto de Sonido.mp3` (`vol: 0.22`): Sonido de caja registradora / dinero.
* `Cartoon Boing (Spring Sound).mp3` (`vol: 0.22`): Rebote de resorte elástico.
* `Cartoon Ricochet Sound Effect.mp3` (`vol: 0.20`): Rebote metálico de bala caricaturesca.
* `Efecto de una bomba.mp3` (`vol: 0.20`): Explosión de dibujo animado.

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
    src={staticFile('music/Trancisiones Necesarias/01 - Abduction swish.wav')}
    volume={0.20}
  />
</Sequence>
```

