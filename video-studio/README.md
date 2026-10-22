# 🎬 Video Studio IA — Automatización de Videos Estilo Resultaaquee

Plataforma completa y 100% gratuita para generar videos verticales de alta retención (Instagram Reels, TikTok y YouTube Shorts) con animaciones 2D estilo doodle/stickers con física de rebote elástico, subtítulos dinámicos palabra por palabra estilo karaoke y efectos de sonido sincronizados.

---

## 🚀 Inicio Rápido

Para iniciar tanto la **aplicación web en React** como el **backend en FastAPI**, ejecuta en la terminal:

```bash
./start.sh
```

- **Frontend Web (Panel de Control)**: [http://localhost:5173](http://localhost:5173)
- **Backend API (Swagger Docs)**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **Carpeta de Videos Exportados**: `output/`

---

## 🛠️ Generador por Consola (CLI en 1 Clic)

Si prefieres generar videos directamente desde la terminal o integrarlo en scripts de automatización:

```bash
source backend/.venv/bin/activate
python3 backend/cli.py --tema "¿Por qué los piratas usaban parches?" --voz "es-ES-AlvaroNeural" --salida "piratas.mp4"
```

Parámetros disponibles:
- `--tema` o `-t`: Tema, pregunta o idea del video.
- `--voz` o `-v`: Voz en español de Microsoft Edge-TTS (`es-ES-AlvaroNeural`, `es-MX-DaliaNeural`, `es-MX-JorgeNeural`, `es-ES-ElviraNeural`).
- `--estilo` o `-e`: `curiosity` (predeterminado), `humor`, `tech`, `money`.
- `--salida` o `-o`: Nombre del archivo MP4 resultante.

---

## 🏗️ Arquitectura y Modificación por el Desarrollador

El proyecto está diseñado de forma modular para que tengas el control total de cada capa:

```
video-studio/
├── assets/                  # Sonidos SFX, música de fondo y stickers SVG
│   ├── sfx/                 # pop.mp3, whoosh.mp3, ding.mp3, click.mp3
│   ├── music/               # ambient_curiosity.mp3
│   └── stickers/            # brain.svg, question.svg, idea.svg, shock.svg, etc.
├── backend/                 # API REST (FastAPI) y Pipeline
│   ├── services/
│   │   ├── script_generator.py # Guiones con gancho (0-3s) y estructura viral
│   │   ├── tts_service.py      # Edge-TTS gratis + marcas de tiempo por palabra
│   │   └── render_service.py   # Orquestador del render con Remotion
│   ├── cli.py               # Generador de consola en un solo comando
│   └── main.py              # Endpoints FastAPI
├── remotion/                # Motor de Video en React
│   └── src/
│       ├── components/
│       │   ├── AnimatedSticker.tsx  # Animación con física spring() y wiggle
│       │   ├── KaraokeSubtitles.tsx # Subtítulos dinámicos con resalte amarillo
│       │   ├── Scene.tsx            # Fondo dinámico con cuadrícula y callout
│       │   └── AudioMixer.tsx       # Mezcla voz + ducking de música + SFX
│       ├── DoodleComposition.tsx    # Orquestador 1080x1920 a 30 FPS
│       └── Root.tsx
├── frontend/                # Interfaz Web (React + Vite + Tailwind CSS)
│   └── src/
│       ├── components/
│       │   ├── QuickGenerator.tsx   # Modo 1-Click
│       │   ├── StoryboardStudio.tsx # Editor escena por escena
│       │   ├── VideoPlayerModal.tsx # Reproductor y descarga MP4
│       │   └── VideoGallery.tsx     # Historial de videos
│       └── App.tsx
└── output/                  # Videos finales en formato MP4
```

---

## 🎨 Cómo Personalizar Animaciones y Estilos

1. **Subtítulos Karaoke**:
   - Edita `remotion/src/components/KaraokeSubtitles.tsx`.
   - Puedes cambiar el color de la palabra activa (`#FFE600` amarillo neón a `#10B981` verde fosforito), el tamaño de fuente o el agrupamiento de palabras por bloque.

2. **Física del Rebote (Spring) y Doodles**:
   - Edita `remotion/src/components/AnimatedSticker.tsx`.
   - Modifica los parámetros del resorte: `damping`, `mass` y `stiffness` para hacer el rebote más suave o más elástico.

3. **Nuevos Stickers e Iconos**:
   - Guarda cualquier archivo `.svg` en `assets/stickers/nombre.svg`.
   - Automáticamente estará disponible en el editor de Storyboard y en el generador.

4. **Voces en Español (Edge-TTS)**:
   - Funciona sin API key ni costos mensuales.
   - Voces recomendadas: `es-ES-AlvaroNeural` (narrador dinámico), `es-MX-DaliaNeural` (narradora conversacional), `es-MX-JorgeNeural` (joven y enérgico).

---

## 💡 Uso de LLM Opcional (OpenAI / Claude / Gemini)

Por defecto, la herramienta incluye un motor heurístico de alta retención que no requiere internet ni claves. Si deseas generar guiones infinitos con un LLM, simplemente define la variable en tu entorno:

```bash
export OPENAI_API_KEY="tu-clave-aqui"
```

El sistema detectará automáticamente la clave y usará GPT-4o-mini para crear guiones aún más variados.
