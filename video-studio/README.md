# 🎬 Video Studio IA — Producción local de videos asistida por IA

Plataforma para planificar videos con IA y producirlos localmente con SVG animados, Remotion, voz, subtítulos y FFmpeg. OmniRoute y algunos proveedores de voz requieren conexión y credenciales.

El repositorio también incluye `../videoAssembler`, un editor web complementario de timeline para recortar/reordenar clips, cortar rangos de audio, añadir capas y exportar un manifiesto para FFmpeg nativo. `start.sh` levanta ambos paneles localmente y Video Studio muestra el enlace «Editor avanzado». Son herramientas complementarias, no una integración de datos: el manifiesto del editor aún no se guarda en SQLite ni se importa automáticamente al proyecto de Video Studio; los medios deben seleccionarse en ese editor.

La persistencia principal usa SQLite (`video_studio.sqlite3` en la raíz de esta aplicación, o la ruta definida por `VIDEO_STUDIO_DB_PATH`). Proyectos, escenas, medios fuente (metadatos) y trabajos de render se guardan en esa base; los originales multimedia se conservan localmente dentro de cada proyecto. Al primer inicio se migran proyectos JSON heredados; los originales se conservan. Incluye el archivo SQLite y sus archivos WAL en tu rutina de respaldo, o detén la aplicación y copia la base para un respaldo simple.

---

## 📖 Documentación Esencial y Guías de Producción 2D

Para desarrolladores y agentes de Inteligencia Artificial que trabajen en este repositorio:

- 📘 **[Guía Completa de Producción 2D (docs/GUIA_COMPLETA_PRODUCCION_2D.md)](../docs/GUIA_COMPLETA_PRODUCCION_2D.md)**: Manual exhaustivo de arquitectura, mapa de dependencias exacto (anti-alucinaciones), receta canónica en 4 pasos, estándares de rigging cinemático SVG, catálogo `shared-art/`, render multi-aspecto (9:16 y 16:9) y resolución de problemas.
- 🤖 **[Manual Operativo de Agentes en la Raíz (README.md)](../README.md)**: Reglas maestras de trabajo autónomo, orden canónico de archivos y control de calidad por Contact Sheet.
- 🎨 **[Catálogo de Arte Compartido (shared-art/)](./shared-art/README.md)**: Librería centralizada de rigs y sistemas de partículas reutilizables.
- 📂 **[Proyectos Canónicos Autónomos (projects/)](./projects/)**: Cada producción (`projects/<slug>/`) es 100% auto-contenida con su propio pipeline `prepare.py`, orquestador `render.mjs`, arte `src/art.tsx` y montaje `src/Film.tsx`.

---

## 🚀 Inicio Rápido

Requisitos: Node.js `^20.19.0` o `>=22.12.0`, Python 3, y `ffmpeg`/`ffprobe` en el `PATH`. En una instalación limpia, instala las dependencias una vez:

```bash
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt
npm ci --prefix frontend
npm ci --prefix remotion
npm ci --prefix ../videoAssembler
```

## Flujo actual de producción

1. El usuario define tema, duración y voz; OmniRoute genera el guion.
2. El guion se puede editar y debe aprobarse explícitamente.
3. OmniRoute convierte el guion aprobado en un storyboard editable.
4. Tras aprobar el storyboard, OmniRoute genera una ilustración SVG original por escena. El backend valida el SVG y lo guarda en el proyecto.
5. El usuario puede añadir clips fuente al proyecto y asignarlos por escena (con punto de inicio), conservando el SVG para poder alternar entre ambos.
6. Remotion compone y anima los SVG, o integra el clip fuente asignado; el render se ejecuta localmente.

El render está bloqueado hasta que el storyboard esté aprobado y cada escena tenga un SVG original válido o un clip fuente asignado. Los videos fuente admitidos son MP4, MOV, M4V, WebM y MKV, con un máximo de 2 GiB por archivo y 20 GiB por proyecto; FFprobe valida pista de video/audio y duración. Los uploads se transmiten por bloques, se guardan con permisos locales restrictivos y el backend no necesita `python-multipart`. Los medios y audios se presentan a Remotion como archivos locales temporales, no como grandes bloques base64 dentro de los props. El objetivo es sustituir los stickers predeterminados como visual principal. OmniRoute requiere `OMNIROUTE_API_KEY` configurada en `backend/.env`; no hay clave integrada en el código.

Los renders del panel se ejecutan como trabajos locales persistidos: el navegador recibe un ID, consulta estado/progreso y puede solicitar cancelación; al recargar la página se reconecta al trabajo activo. Se ejecuta un render a la vez para proteger CPU/GPU y memoria. La concurrencia predeterminada de Remotion es `25%`, ajustable mediante `VIDEO_STUDIO_RENDER_CONCURRENCY` según los recursos del equipo. Los trabajos de más de 60 segundos se dividen en segmentos de 60 s; al reiniciar, los segmentos ya validados se reutilizan y como máximo se vuelve a renderizar el segmento que estaba en curso. El reintento conserva el ID del trabajo y verifica una huella de props, código Remotion y medios antes de reutilizar segmentos. La huella usa tamaño/fecha de modificación en medios para evitar volver a leer archivos fuente de varios GiB; una edición externa que preserve ambos metadatos podría no invalidar el checkpoint. Estos checkpoints están en `render_checkpoints/` (caché local derivada, fuera de los endpoints de archivos); borrarla no afecta al proyecto, pero obliga a renderizar de nuevo. Remotion y FFmpeg escriben a MP4 parciales; FFprobe valida pista de video y duración antes de publicar el resultado atómicamente. Los finales fallidos/incompletos no se publican.

Referencia medida en el equipo de desarrollo: composición de prueba sencilla de 30 s, una escena SVG, 1080×1920, sin TTS ni metraje fuente; 27.82 s de render, 2.49 MB de salida, pico RSS de 830 MB y ~213% de CPU. El flujo de segmentos + FFmpeg se probó en un render real de 2.1 s con el umbral reducido solo para la prueba; el umbral de producción sigue en 60 s. Ninguna de estas pruebas representa una producción de 300 escenas ni garantiza tiempos, memoria o almacenamiento para una hora; medir con el hardware y los recursos reales del proyecto antes de producción larga.

Los tres servidores se enlazan a `127.0.0.1` por defecto y el script elige puertos libres para los paneles. Para acceso desde una red privada se puede definir `VIDEO_STUDIO_HOST=0.0.0.0` y `VIDEO_STUDIO_BROWSER_HOST` con el nombre/IP que abrirá el navegador; configurar también `VIDEO_STUDIO_CORS_ORIGINS` según el origen del panel. No exponer el backend directamente a Internet sin autenticación.

Estado de integraciones de voz: Edge-TTS, Google TTS y ElevenLabs son proveedores conectados a servicios externos; el render sí es local. ElevenLabs se lista desde su API cuando existe `ELEVENLABS_API_KEY`. VibeVoice no se ofrece como opción hasta contar con un adaptador de inferencia real. No se reemplaza silenciosamente el proveedor elegido si falla.

La edición de metraje fuente en Video Studio permite seleccionar un archivo y punto de inicio por escena; por defecto el clip se silencia y se conserva la voz generada. Si el original contiene audio, el usuario puede activarlo y definir el tramo; entonces se omite TTS para esa escena. Video Studio todavía no genera subtítulos karaoke desde ese audio. `videoAssembler` incluye un transcriptor Whisper local por CLI, pero requiere instalar `whisper-cli` y descargar/configurar su modelo; no está conectado al panel ni a las escenas de Video Studio. La línea de tiempo multipista tampoco comparte aún los proyectos SQLite de Video Studio. Los archivos subidos ocupan espacio local y deben incluirse en respaldos junto con SQLite.

Para iniciar **Video Studio**, **Video Assembler** y el **backend FastAPI**, ejecuta en la terminal:

```bash
./start.sh
```

- El script imprime las URLs locales efectivas (elige puertos libres para ambos paneles).
- **Backend API (Swagger Docs)**: `http://localhost:8000/docs`
- **Carpeta de Videos Exportados**: `output/`

El editor multipista de `videoAssembler` renderiza proyectos grandes con su CLI de FFmpeg nativo (`node cli/render.ts ...`); el render de navegador WebAssembly se reserva para material ligero. Su transcriptor opcional Whisper es local, pero requiere instalar `whisper-cli` y descargar/configurar un modelo. Estas funciones aún no comparten estado ni proyectos SQLite con el flujo de guion/storyboard de Video Studio.

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
│   ├── sfx/                 # Efectos organizados (sound effects, transiciones, fails, risas, etc.)
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

## Configuración de OmniRoute

El flujo web requiere `OMNIROUTE_API_KEY` y usa `OMNIROUTE_MODEL` desde `backend/.env`; consulta `backend/.env.example`. Las llamadas generan guion, storyboard y SVG. El contenido y el render se guardan localmente. Las voces ElevenLabs se consultan dinámicamente con `ELEVENLABS_API_KEY`.
