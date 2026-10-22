# Video Assembler

Editor de video mínimo con interfaz gráfica para ensamblar videos verticales y horizontales a partir de: clips pregrabados reutilizables + footage nuevo + voz + música de fondo. Corre 100% en el navegador (sin backend, sin subir archivos a ningún servidor), con un CLI de render nativo para el trabajo pesado.

## 🤖 Para agentes de IA — léeme primero

Si eres una IA (Claude Code, Copilot, etc.) y te pasaron este repo, esto es todo lo que necesitas para trabajar aquí sin explorar a ciegas:

**Qué es esto.** Una herramienta personal de edición de video con dos mitades que hablan el mismo idioma: una GUI web (React) donde el usuario edita visualmente, y un CLI (`cli/render.ts`) que renderiza con ffmpeg nativo. El idioma común es el **manifiesto**: un JSON que describe el video completo.

**Lee estos archivos, en este orden:**
1. [`manifiesto.md`](manifiesto.md) — especificación completa del manifiesto: cada campo, semántica de tiempos (crítica: todos los tiempos son segundos del archivo fuente), y una guía de tareas comunes con ejemplos. **Léelo antes de crear o editar cualquier manifiesto.**
2. `src/lib/graph.ts` — la fuente de verdad: traduce el manifiesto a argumentos de ffmpeg. GUI y CLI lo comparten; lo que haga este archivo ES el comportamiento del render.
3. `cli/render.ts` — el renderizador de terminal (resolución de archivos, ffprobe, progreso).

**Lo que el usuario típicamente te pedirá:**
- Crear o editar un manifiesto a partir de instrucciones en lenguaje natural («córtale la voz del 1:23 al 1:34», «acelera el clip 2») → edita el JSON según `manifiesto.md`.
- Renderizarlo: `node cli/render.ts manifiesto.json --base <carpeta-de-medios> [--out <salida>]`. Requiere Node ≥ 22.18 y `ffmpeg`/`ffprobe` en el PATH. En macOS usa VideoToolbox por defecto (rápido); **nunca sugieras el render del navegador para material 4K o videos largos**.
- En la máquina del autor, el material vive en `~/Documents/Videos` (clips reutilizables en `ayuda/`, proyectos en carpetas numeradas con su nota de voz `untitled.wav`).

**Comandos del proyecto:** `npm install` · `npm run dev` (editor en local) · `npm run build` (typecheck + bundle, verifica esto tras cambios) · `npm run lint`.

**Sincronizar con el audio:** si el usuario pide editar según lo que dice la voz («cuando digo X pon tal clip»), transcribe primero: `node cli/transcribe.ts voz.wav` → JSON con cada palabra y su tiempo. Detalles y mapeo de tiempos en `manifiesto.md` §8.

**Principio rector que debes respetar:** este proyecto es deliberadamente mínimo y NO se itera constantemente. No agregues funcionalidades, dependencias ni refactors que el usuario no pidió. Si algo grande parece buena idea, propónlo — no lo implementes.

## Principio rector: solo lo básico

Este proyecto **no está pensado para iterarse constantemente**. Se construye una vez, se usa, y solo recibe ajustes puntuales cuando algo realmente lo justifique. Si en el futuro se le quiere agregar algo grande (transiciones, subtítulos automáticos, etc.), eso es un proyecto nuevo, no un parche a este.

## Arquitectura

- **Frontend:** React + Vite, SPA. La GUI es el **editor**: cargar clips, recortar con preview, ordenar, mezclar audio, y generar el manifiesto JSON.
- **Render primario:** `cli/render.ts` — script de Node que lee el manifiesto y renderiza con **ffmpeg nativo** (en macOS usa aceleración por hardware VideoToolbox). Es el camino para el flujo típico: clips de iPhone 4K/HEVC y salidas de 2+ minutos.
- **Render secundario:** `ffmpeg.wasm` en el navegador — útil para ensamblados cortos y ligeros. La GUI advierte cuando el material excede lo que el navegador aguanta (~800 MB o clips 4K).
- **Manifiesto JSON:** el contrato entre GUI y CLI. La GUI lo genera y lo puede volver a cargar; el CLI lo renderiza. También permite que Claude Code arme/renderice videos desde terminal.
- **Hosting:** Cloudflare Pages (gratis). `ffmpeg.wasm` requiere headers COOP/COEP → `public/_headers`. Recomendado protegerlo con Cloudflare Access.

### Por qué el CLI es el camino principal (medido, no supuesto)

El material real son clips de iPhone de 37–213 MB (4K/60fps HEVC, pistas extra de metadata) y salidas de 1.5–5.7 minutos. Un proyecto típico suma 500 MB–1.5 GB de fuente: fuera del techo de memoria de `ffmpeg.wasm` (~2 GB) y decodificar 4K HEVC en WebAssembly es 5–20× más lento que nativo. El navegador edita y previsualiza bien (el `<video>` nativo reproduce todo sin problema); el render pesado lo hace ffmpeg nativo en segundos/minutos.

## Uso

### GUI (editor)

```bash
npm install
npm run dev        # abre la interfaz en local
npm run build      # genera dist/ para Cloudflare Pages
```

1. Conecta tu carpeta de medios con «📂 Conectar carpeta» (una sola vez): al abrir manifiestos, los archivos se cargan solos. La búsqueda es recursiva (subcarpetas incluidas) y empareja por nombre exacto de archivo — si hay nombres duplicados usa el primero que encuentre. La conexión persiste entre sesiones (solo pide un clic de confirmación por sesión) y requiere navegador Chromium. Luego agrega clips (se ensamblan en orden; arrastra para reordenar).
2. Por clip: recorte inicio/fin, velocidad (0.5×–2×), conservar o no el audio del clip con su volumen.
3. Carga voz (WAV/MP3) y música, cada una con recorte y volumen. Con solo audio cargado (sin clips), ▶ reproduce el resultado con sus cortes aplicados — útil para revisar una voz limpiada antes de armar el video.
4. Capas: «+ Capa» pone un video *encima* del principal (picture-in-picture) durante un rango — arrastra su bloque morado en la timeline para moverlo en el tiempo, y ajusta tamaño/posición en el inspector. (Capas de texto: pendientes — requieren un ffmpeg con drawtext, p. ej. `brew install ffmpeg-full`.)
5. Elige formato: vertical (1080×1920), horizontal (1920×1080) o ambos.
6. **Descargar manifiesto** (recomendado) o **Exportar en navegador** (solo material ligero). Para abrir un manifiesto puedes usar el botón o **arrastrar el .json a la ventana** (también acepta archivos de video/audio sueltos).

### CLI (render nativo)

```bash
node cli/render.ts manifiesto.json --base /ruta/a/tus/videos [--out ./salida] [--encoder videotoolbox|x264]
```

- `--base`: carpeta raíz donde están los archivos; si una ruta del manifiesto no existe tal cual, se busca recursivamente por nombre de archivo.
- Encoder por defecto: `videotoolbox` en macOS (hardware), `x264` en otros sistemas.
- Requiere Node ≥ 22.18 y `ffmpeg`/`ffprobe` en el PATH (o variables `FFMPEG`/`FFPROBE`).

### Transcripción de la voz (editar por frases)

```bash
node cli/transcribe.ts /ruta/a/voz.wav        # → voz.transcript.json
```

Transcribe la nota de voz localmente (Whisper, sin internet) y devuelve **cada palabra con su segundo exacto**. Para qué sirve: pedirle a la IA cosas como *«cuando digo 'así que por eso decidí crear mi propio editor' pon tal clip, y que termine cuando acabo la frase X»* — la IA localiza las frases en la transcripción, calcula el rango de tiempo y arma el manifiesto sincronizado con lo que dices.

- Requiere `whisper-cli` (`brew install whisper-cpp`) y el modelo en `~/.cache/whisper/ggml-large-v3-turbo-q5_0.bin` ([descarga](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin), 547 MB, una sola vez).
- Los tiempos son del archivo de audio (misma referencia que `trimIn`/`cuts` de la voz). Precisión ±0.1–0.3 s.
- Flujo completo y mapeo de tiempos para IA: `manifiesto.md` §8.

### Manifiesto (contrato GUI ↔ CLI)

> **Especificación completa en [`manifiesto.md`](manifiesto.md)** — cada campo, semántica de tiempos, resolución de archivos y guía para IA. Si vas a editar manifiestos (humano o IA), lee ese archivo. Lo de abajo es solo el resumen.

```json
{
  "name": "qstify-launch-teaser",
  "clips": [
    { "file": "ayuda/IMG_3360.mov", "trimIn": 0, "trimOut": 3, "speed": 1.0, "keepAudio": false, "audioVolume": 1.0 },
    { "file": "footage/demo1.mov", "trimIn": 4, "trimOut": 22, "speed": 1.2, "keepAudio": true, "audioVolume": 0.8,
      "cuts": [{ "from": 10, "to": 13 }] }
  ],
  "voice": { "file": "untitled.wav", "trimIn": 0, "trimOut": 90, "volume": 1.0,
    "cuts": [{ "from": 83, "to": 94 }] },
  "music": { "file": "track3.mp3", "trimIn": 0, "trimOut": null, "volume": 0.15 },
  "outputs": ["vertical", "horizontal"]
}
```

- `trimOut: null` en audio = hasta el final. La música se corta sola al terminar el video.
- `cuts` (opcional, en clips y pistas de audio): rangos internos a eliminar, en segundos del archivo original — el material se re-empata automáticamente. En la GUI se agregan con el editor "✂ Cortar de … a …" (acepta `83.5` o `1:23.5`).
- En la GUI los archivos se emparejan por **nombre**; en el CLI por ruta relativa a `--base` o búsqueda por nombre.

## Decisiones de diseño (cerradas)

- **Adaptación de formato:** cuando el clip no coincide con la salida, el video completo va centrado sobre un fondo del mismo clip escalado a llenar + blur (look de redes sociales). Sin crop destructivo, sin barras negras.
- **Audio por clip:** el audio original se descarta por defecto; toggle `keepAudio` + volumen por clip para conservarlo (con `atempo` para mantener sincronía si cambia la velocidad).
- **Normalización:** todo se re-encodea a 60 fps, H.264 + AAC 44.1 kHz estéreo, mezclado con `amix` sin re-normalizar volúmenes.
- **Archivos:** selección manual por sesión desde el dispositivo. Sin integración con cloud storage (ajuste puntual futuro si se vuelve tedioso).

## Deploy (Cloudflare Pages)

- Build command: `npm run build` · Output: `dist`
- Los headers COOP/COEP salen de `public/_headers` (necesarios para `ffmpeg.wasm` multihilo).
- Recomendado: Cloudflare Access con contraseña simple, ya que la URL es pública.

## Fuera de alcance (v1)

- Transiciones o efectos visuales
- Subtítulos/captions automáticos
- Integración con almacenamiento en la nube
- Múltiples pistas de video simultáneas
- Cuentas de usuario / colaboración en tiempo real
