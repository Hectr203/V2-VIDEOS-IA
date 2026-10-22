# Manifiesto del Video Assembler — especificación completa

Este documento describe **todo** lo necesario para leer, escribir, editar y renderizar manifiestos del Video Assembler. Está escrito para que lo entienda una persona **o una IA** (Claude Code, ChatGPT, etc.): si le das este archivo a una IA junto con un manifiesto, tiene la información completa para trabajarlo sin adivinar nada.

## 1. Qué es

Un manifiesto es un archivo **JSON** que describe la receta completa de un video: qué clips van, en qué orden, cómo se recortan, a qué velocidad, y qué pistas de voz y música llevan. **No contiene los archivos de video/audio** — solo referencias por nombre e instrucciones. El mismo manifiesto puede renderizarse en el navegador (editor web) o por terminal (CLI con ffmpeg nativo, mucho más rápido); el resultado es idéntico porque ambos usan el mismo generador de comandos (`src/lib/graph.ts`).

## 2. Esquema completo

```json
{
  "name": "mi-video",
  "clips": [
    {
      "file": "IMG_3360.mov",
      "trimIn": 1.0,
      "trimOut": 4.5,
      "speed": 1.5,
      "keepAudio": false,
      "audioVolume": 1.0,
      "cuts": [{ "from": 2.0, "to": 3.0 }]
    }
  ],
  "voice": {
    "file": "voz.wav",
    "trimIn": 0,
    "trimOut": null,
    "volume": 1.0,
    "cuts": [{ "from": 83, "to": 94 }]
  },
  "music": {
    "file": "track.mp3",
    "trimIn": 0,
    "trimOut": null,
    "volume": 0.15
  },
  "outputs": ["vertical", "horizontal"]
}
```

### Raíz

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `name` | string | sí | Nombre del proyecto. Los archivos de salida se llaman `{name}-vertical.mp4` / `{name}-horizontal.mp4` (caracteres no alfanuméricos se vuelven `-`). |
| `clips` | array | sí, mínimo 1 | Segmentos de video **en orden de aparición**. El orden del array ES el orden del video final. |
| `voice` | objeto \| null | no | Pista de narración. Corre desde el segundo 0 del video final. |
| `music` | objeto \| null | no | Pista de música de fondo. Corre desde el segundo 0 del video final. |
| `outputs` | array | sí | Formatos a renderizar: `"vertical"` (1080×1920) y/o `"horizontal"` (1920×1080). |

### Clip

| Campo | Tipo | Default | Descripción |
|---|---|---|---|
| `file` | string | — | Referencia al archivo. Ver §5 (resolución de archivos). |
| `trimIn` | número (seg) | 0 | Segundo del **archivo original** donde empieza el segmento usado. |
| `trimOut` | número (seg) | duración total | Segundo del archivo original donde termina. Debe ser > `trimIn`. |
| `speed` | número | 1.0 | Velocidad de reproducción, rango práctico 0.5–2.0. Afecta video y audio (el audio se corrige con `atempo`, mantiene tono y sincronía). |
| `keepAudio` | booleano | false | `true` = el audio original del clip entra a la mezcla final. `false` = clip mudo. |
| `audioVolume` | número | 1.0 | Volumen del audio del clip (0–2, 1 = 100%). Solo aplica si `keepAudio` es `true`. |
| `cuts` | array de `{from, to}` | `[]` | Rangos internos a **eliminar**, ver §3. |

### Pista de audio (voice / music)

| Campo | Tipo | Default | Descripción |
|---|---|---|---|
| `file` | string | — | Referencia al archivo (WAV, MP3, M4A, AAC, OGG, FLAC). |
| `trimIn` | número (seg) | 0 | Dónde empieza a usarse el archivo. |
| `trimOut` | número (seg) \| null | null | Dónde termina. `null` = hasta el final del archivo. |
| `volume` | número | 1.0 | Volumen (0–2). Recomendado 0.10–0.20 para música de fondo. |
| `cuts` | array de `{from, to}` | `[]` | Rangos internos a eliminar, ver §3. |

### Capa superpuesta (overlays, opcional)

Videos que aparecen **encima** del video principal durante un rango (picture-in-picture, B-roll chico, logos animados). Van en el array raíz `overlays`:

```json
"overlays": [
  { "file": "logo.mov", "start": 3, "end": 8, "trimIn": 0, "scale": 0.35, "position": "top-right" }
]
```

| Campo | Tipo | Default | Descripción |
|---|---|---|---|
| `file` | string | — | Video de la capa (se resuelve igual que los clips). |
| `start` / `end` | número (seg) | — | **Segundos del VIDEO FINAL** (no del archivo) donde aparece y desaparece. Ojo: es el único lugar del manifiesto donde los tiempos son del video final. |
| `trimIn` | número (seg) | 0 | Desde qué segundo del archivo fuente se toma la capa. |
| `scale` | número | 0.35 | Ancho de la capa como fracción del ancho de salida (0.15–0.8). |
| `position` | string | top-right | Una de: `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, `bottom-right` (margen 3%). |

- Las capas se dibujan en el orden del array (la última queda encima).
- El audio de la capa **se descarta siempre**.
- Si el archivo de la capa es más corto que `end - start`, la capa desaparece cuando el archivo se acaba.
- Las capas no alargan el video; `end` más allá de la duración total simplemente se corta ahí.
- Capas de **texto**: aún no soportadas (pendiente de un ffmpeg con drawtext; ver README).

## 3. Semántica de tiempos (LO MÁS IMPORTANTE)

- **Todos los tiempos (`trimIn`, `trimOut`, `cuts`) son segundos del ARCHIVO ORIGINAL**, no del video final. Si un clip usa `trimIn: 10` y tiene `cuts: [{from: 12, to: 14}]`, el corte se refiere a los segundos 12–14 del archivo fuente.
- **Orden de operaciones por clip**: (1) se toma el rango `[trimIn, trimOut]`; (2) se restan los `cuts` que caigan dentro (los que quedan fuera se ignoran, y los que se traslapan parcialmente se recortan al rango); (3) los pedazos restantes se re-empatan sin hueco; (4) el resultado se reproduce a `speed`.
- **Duración que un clip aporta al video final** = (suma de pedazos restantes en segundos) ÷ `speed`.
- **Duración total del video** = suma de lo anterior sobre todos los clips. La voz y la música NO alargan el video: si son más largas, se cortan donde termina el video.
- Los `cuts` pueden estar en cualquier orden y traslaparse; el motor los normaliza. Un pedazo restante menor a 0.01 s se descarta.
- En pistas de audio con `trimOut: null` y `cuts`, los cortes se aplican igual (el último tramo llega hasta el final del archivo).

## 4. Qué hace el render (para no adivinar)

- Salida: H.264 + AAC 192k estéreo 44.1 kHz, 60 fps, `+faststart`. Vertical = 1080×1920, horizontal = 1920×1080.
- **Adaptación de formato**: si el clip no coincide con el formato de salida, el video completo va centrado sobre un fondo del mismo clip escalado a llenar con desenfoque (blur). Nunca se recorta contenido ni hay barras negras.
- **Mezcla de audio**: audio de clips (si `keepAudio`) + voz + música se mezclan con `amix` SIN re-normalizar volúmenes (lo que pongas en `volume`/`audioVolume` es lo que suena).
- Los archivos de iPhone traen varias pistas (audio espacial, metadata); el motor siempre toma la primera pista de video y la primera de audio.
- Si un clip tiene `keepAudio: true` pero el archivo no tiene audio, el CLI lo detecta con ffprobe y usa silencio (con aviso).

## 5. Resolución de archivos

El manifiesto guarda nombres/rutas; cada entorno los resuelve distinto:

- **Editor web**: empareja por **nombre de archivo** (basename). Al abrir un manifiesto, si el archivo ya está en la biblioteca se reconecta solo; si no, queda marcado como faltante hasta que el usuario lo agregue. Con la **carpeta de medios conectada** (botón «📂 Conectar carpeta», navegadores Chromium), los archivos faltantes se buscan recursivamente en esa carpeta y se cargan sin intervención.
- **Advertencia para IA al escribir manifiestos**: como el emparejamiento es por nombre de archivo, evita referenciar nombres que existan repetidos en varias subcarpetas (ej. `untitled.wav` aparece en muchas carpetas de proyecto del autor) — tanto la web como el CLI tomarán el primero que encuentren. Si el nombre es ambiguo, usa la ruta relativa (`20/untitled.wav`) para el CLI y avisa al usuario que en la web debe verificar que cargó el correcto.
- **CLI**: primero intenta la ruta tal cual relativa a `--base`; si no existe, **busca recursivamente por nombre** bajo `--base` y usa la primera coincidencia (avisa si hay duplicadas). Rutas absolutas también funcionan.
- Recomendación al escribir manifiestos: usa solo el nombre del archivo (`IMG_3360.mov`) y deja que `--base` haga el trabajo.

## 6. Render por CLI (el camino rápido)

```bash
node cli/render.ts mi-video.json --base ~/Documents/Videos [--out ./salida] [--encoder videotoolbox|x264]
```

- `--base`: carpeta raíz donde buscar los archivos (default: la carpeta del manifiesto).
- `--out`: carpeta de salida (default: carpeta actual).
- `--encoder`: default `videotoolbox` en macOS (aceleración por hardware; render en ~tiempo real incluso con fuentes 4K), `x264` en otros sistemas.
- Requisitos: Node ≥ 22.18 y `ffmpeg`/`ffprobe` en el PATH (o variables de entorno `FFMPEG`/`FFPROBE`).
- Renderiza todos los formatos listados en `outputs`, uno por uno, con barra de progreso.

El render en navegador (ffmpeg.wasm) existe pero es 5–20× más lento y con límite de memoria (~2 GB): útil solo para material ligero. **Para clips 4K o videos largos, siempre CLI.**

## 7. Guía para IA: tareas comunes

Una IA con acceso a este proyecto puede crear/editar manifiestos y renderizarlos. Reglas de oro: valida que `trimOut > trimIn`, que los `cuts` caigan dentro del rango usado, y recuerda que todos los tiempos son del archivo fuente.

**«Córtale a la voz del 1:23 al 1:34»** → agrega a `voice.cuts`:
```json
"cuts": [{ "from": 83, "to": 94 }]
```

**«Quita los primeros 5 segundos del segundo clip»** → sube su `trimIn` a 5 (o `trimIn` actual + 5 si ya tenía recorte).

**«Parte el clip en dos y quita la parte de en medio»** → dos entradas del mismo `file`:
```json
{ "file": "demo.mov", "trimIn": 0,  "trimOut": 12, ... },
{ "file": "demo.mov", "trimIn": 18, "trimOut": 30, ... }
```
(equivalente a un solo clip con `cuts: [{from: 12, to: 18}]` — ambas formas son válidas).

**«Acelera el clip 3 al doble»** → `"speed": 2.0` en ese clip. Su aporte de duración se divide entre 2.

**«Hazlo también horizontal»** → `"outputs": ["vertical", "horizontal"]` y re-renderizar.

**«¿Cuánto dura el video?»** → calcula con la fórmula de §3; no asumas que es `trimOut - trimIn` si hay `cuts` o `speed ≠ 1`.

## 8. Sincronizar la edición con lo que dice el audio

El repo incluye un transcriptor local con marcas de tiempo por palabra (Whisper). Cuando el usuario pida cosas como *«cuando digo tal frase, pon tal clip»*, este es el flujo:

```bash
node cli/transcribe.ts /ruta/a/voz.wav          # → voz.transcript.json
```

- Salida: `{ text, words: [{ word, start, end }] }` — tiempos en segundos **del archivo de audio** (misma referencia que `trimIn`/`cuts` de la pista de voz).
- Busca la frase pedida en `words` (compara en minúsculas y sin puntuación) → obtén el `start` de la primera palabra y el `end` de la última.
- **Mapeo a tiempo del video final**: si la voz tiene `trimIn` o `cuts`, réstalos — el tiempo final = tiempo del archivo − trimIn − (duración de cortes anteriores a ese punto). Sin recortes, son iguales.
- Con ese rango ya puedes: colocar una capa (`overlays` usa tiempos del video final directamente), cortar la voz en ese punto, o ajustar los clips para que uno cubra exactamente ese rango.
- Requisitos: `whisper-cli` (brew whisper-cpp) y el modelo en `~/.cache/whisper/ggml-large-v3-turbo-q5_0.bin` (o `WHISPER_MODEL`). Precisión típica: ±0.1–0.3 s.

## 9. Ejemplo completo comentado

Video de 19.3 s: intro acelerada, demo con corte interno y audio propio, cierre; narración con un tramo eliminado y música bajita.

```json
{
  "name": "qstify-teaser",
  "clips": [
    { "file": "intro.mov", "trimIn": 0, "trimOut": 6, "speed": 1.5,
      "keepAudio": false, "audioVolume": 1 },
    { "file": "demo.mov", "trimIn": 4, "trimOut": 22, "speed": 1.2,
      "keepAudio": true, "audioVolume": 0.8,
      "cuts": [{ "from": 10, "to": 13 }] },
    { "file": "cierre.mov", "trimIn": 0, "trimOut": 2.8, "speed": 1,
      "keepAudio": false, "audioVolume": 1 }
  ],
  "voice": { "file": "voz.wav", "trimIn": 0.5, "trimOut": null, "volume": 1,
    "cuts": [{ "from": 12, "to": 15.5 }] },
  "music": { "file": "track3.mp3", "trimIn": 30, "trimOut": null, "volume": 0.12 },
  "outputs": ["vertical"]
}
```

Cálculo de duración: intro (6−0)/1.5 = 4 s · demo ((22−4)−3)/1.2 = 12.5 s · cierre 2.8/1 = 2.8 s → **19.3 s**. La voz y la música se cortan ahí automáticamente.
