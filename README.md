# 🎬 Ecosistema Audiovisual y Agencia de Producción IA

Plataforma integral y arquitectura de producción de video con Inteligencia Artificial. Combina agentes autónomos, animación vectorial 2D en Remotion con cinemática inversa, síntesis de voz neuronal, banda sonora procedimental y un panel web de control multiformato (9:16 vertical y 16:9 horizontal).

---

## 📌 Documentación de Referencia Rápida

* 📖 **[Guía Completa de Producción y Animación 2D](docs/GUIA_COMPLETA_PRODUCCION_2D.md)**: Manual técnico exhaustivo para desarrolladores y agentes de IA.
* 🤖 **[Agente Animador 2D](Agencia_Principal/agentes/agente-animador-2d.md)**: Ficha de rol y contrato operativo de animación dentro de la Agencia.
* 📐 **[Estándar de Animación y Rigging 2D](Agencia_Principal/reglas/estandar-animacion-2d.md)**: Reglas de calidad estética, puertas de calidad pre-render y arquitectura auto-contenida.
* 🎨 **[Catálogo Compartido de Arte (shared-art)](video-studio/shared-art/)**: Rigs de personajes articulados, manos ilustrativas, partículas y matemáticas cinemáticas.
* 💻 **[Video Studio Web App](video-studio/README.md)**: Manual de la aplicación web, backend FastAPI y editor avanzado.

---

## 🏗️ Estructura del Repositorio

```text
.
├── README.md                           # Este archivo (Índice maestro y manual de IA)
├── docs/
│   └── GUIA_COMPLETA_PRODUCCION_2D.md  # Documentación técnica completa del pipeline 2D
├── pyrightconfig.json                  # Configuración de tipos Python (extraPaths para backend)
├── .vscode/settings.json               # Configuración del workspace para el IDE
├── video-studio/                       # Motor central de producción audiovisual
│   ├── projects/                       # 📁 Directorio canónico de proyectos 2D autónomos
│   │   ├── la-ciencia-del-helado/      # Producción modelo: Ciencia del Helado
│   │   └── fentanilo-la-llave-quimica/ # Producción modelo: Fentanilo y Neurobiología
│   ├── shared-art/                     # 🎨 Catálogo compartido de rigs, física y partículas
│   ├── scripts/                        # Scaffolding y utilidades CLI
│   │   └── crear_produccion_2d.py      # Generador de nuevos proyectos 2D autónomos
│   ├── backend/                        # API FastAPI, SQLite y persistencia (/api/v2/projects)
│   ├── frontend/                       # Dashboard React + Tailwind con visor de contact-sheets
│   └── remotion/                       # Motor Remotion 4.x con Chromium Headless Shell
├── Agencia_Principal/                  # Orquestación de agentes, habilidades y verificación local
│   ├── agentes/                        # Fichas de agentes especializados
│   ├── skills/                         # Catálogo de habilidades (animacion-2d-remotion, etc.)
│   └── scripts/agencia.py              # CLI de validación y control de la agencia
├── videoAssembler/                     # Editor web multipista complementario (timeline & FFmpeg)
└── VibeVoice/                          # Módulos de síntesis de voz y modelos ASR
```

---

## 🤖 Manual Operativo para Agentes de Inteligencia Artificial

> [!IMPORTANT]
> **Si eres un Agente de IA trabajando en este repositorio, lee esta sección antes de ejecutar comandos o buscar herramientas.**

### 1. Inventario Real de Herramientas (Anti-Alucinaciones)

Para evitar buscar herramientas inexistentes o fallar por rutas incorrectas:

| Herramienta | Ubicación Exacta | Estado / Modo de Uso |
| :--- | :--- | :--- |
| **Node / Remotion** | `video-studio/remotion/node_modules/` | Contiene `@remotion/bundler`, `@remotion/renderer` y `react`. Ejecutar scripts con `node`. |
| **Python Venv** | `video-studio/backend/.venv/bin/python` | Entorno virtual con `fastapi`, `edge-tts`, `numpy`, `uvicorn`. |
| **Scaffolding 2D** | `video-studio/scripts/crear_produccion_2d.py` | Generador oficial de proyectos autónomos. |
| **Validación Agencia** | `python3 Agencia_Principal/scripts/agencia.py validar` | Comprueba la integridad del sistema de agentes y habilidades. |
| **Compilador TS** | `video-studio/tsconfig.json` | Mapea paths limpios para `projects` y `shared-art`. Verificar con `tsc --noEmit`. |

* ❌ **NO BUSCAR**: Herramientas externas inventadas como Three.js, Blender, Lottie, convertidores de After Effects o paquetes físicos 2D externos. Todo se ilustra y anima con SVG nativo y Remotion.
* ❌ **NO USAR**: Las carpetas `video-studio/productions/` y `video-studio/remotion/src/projects/` son enlaces simbólicos de retrocompatibilidad. **Todos los proyectos nuevos y existentes residen en `video-studio/projects/<slug>/`**.

---

### 2. Protocolo de Creación de un Nuevo Video 2D

Sigue estos 4 pasos exactos:

#### Paso 1: Generar el Proyecto Autónomo
```bash
python3 video-studio/scripts/crear_produccion_2d.py \
  --id "mi-nuevo-video" \
  --titulo "Título del Video Explicativo" \
  --tema "Descripción conceptual y estética"
```

#### Paso 2: Generar Voces y Banda Sonora
Edita `video-studio/projects/mi-nuevo-video/storyboard.json` con los textos y escenas, y luego ejecuta:
```bash
python3 video-studio/projects/mi-nuevo-video/prepare.py
```
*Genera los archivos `.mp3` de voz sincronizados palabra por palabra, el `timeline.json` exacto a 30 FPS y la música procedural `public/score.wav`.*

#### Paso 3: Puerta Obligatoria de Control Visual (Contact Sheet)
**REGLA:** Nunca entregues un video sin generar e inspeccionar visualmente la hoja de contactos:
```bash
node video-studio/projects/mi-nuevo-video/render.mjs --stills
```
*Genera `renders/contact-sheet.jpg` con una cuadrícula 4x4 de todas las escenas para validar que no haya desbordamiento de textos ni desproporciones.*

#### Paso 4: Renderizado Final Multiformato
```bash
# Renderizar vertical 9:16 (Shorts/Reels)
node video-studio/projects/mi-nuevo-video/render.mjs

# Renderizar horizontal 16:9 (YouTube)
node video-studio/projects/mi-nuevo-video/render.mjs --horizontal

# Renderizar ambos formatos simultáneamente
node video-studio/projects/mi-nuevo-video/render.mjs --aspect=both
```

---

### 3. Reglas de Higiene y Calidad de Código

1. **Sin Basura en Git**: Las carpetas `renders/`, `.cache/`, `.remotion/` y `__pycache__/` están estrictamente ignoradas. No subas renders MP4 a Git.
2. **Tipado Estricto**: Todo código TypeScript debe pasar limpio:
   ```bash
   npx --prefix video-studio/remotion tsc -p ../tsconfig.json --noEmit
   ```
3. **Frontend Build**:
   ```bash
   npm --prefix video-studio/frontend run build
   ```
4. **Commits en Español**: Siguiendo la regla `commits-espanol`, todos los mensajes de Git deben ser claros y redactados en **español** (`feat:`, `fix:`, `chore:`, `docs:`).

---

## 🚀 Inicio Rápido de la Plataforma Web

Para iniciar los paneles de control web y la API:

```bash
cd video-studio
./start.sh
```

* **Frontend Dashboard**: `http://localhost:5173` (con pestaña dedicada **"Proyectos 2D"**).
* **Backend API Docs**: `http://localhost:8000/docs` (endpoints `/api/v2/projects`).
* **Editor Multipista videoAssembler**: `http://localhost:5174`.
