#!/usr/bin/env python3
"""
Generador y scaffolding estandarizado de proyectos de video 2D autónomos en Remotion.

Crea una carpeta única y auto-contenida por proyecto bajo:
    video-studio/projects/<nombre-del-proyecto>/

Estructura canónica generada:
    video-studio/projects/<slug>/
    ├── project.json          # Metadatos del proyecto (título, descripción, resolución, versión)
    ├── storyboard.json       # Guion pedagógico, capítulos, voces y temporalidad mínima
    ├── timeline.json         # Sincronización palabra por palabra con Edge TTS y marcas de tiempo
    ├── prepare.py            # Generación de locución TTS, banda sonora y sincronización
    ├── render.mjs            # Orquestador de renderizado Remotion (Full HD, borrador y stills)
    ├── src/
    │   ├── index.tsx         # Punto de entrada y Composition autónoma de Remotion
    │   ├── Film.tsx          # Montaje de secuencias, transiciones y subtítulos cinéticos
    │   ├── art.tsx           # Biblioteca vectorial SVG: personajes, rig IK, fondos y utilidades
    │   └── timeline.json     # Enlace para bundler
    ├── public/
    │   ├── UbuntuSans.ttf    # Tipografía empaquetada
    │   └── score.wav         # Banda sonora procedural (generada por prepare.py)
    └── renders/
        ├── contact-sheet.jpg # Mosaico visual de control de calidad de todas las escenas
        ├── stills/           # Capturas fotograma a fotograma para revisión
        ├── preview-720p.mp4  # Render rápido de previsualización
        └── master-1080p.mp4  # Master final Full HD (CRF 17)

Uso:
    python3 video-studio/scripts/crear_produccion_2d.py --id ia-control-futuro --titulo "IA sin control: el dilema del futuro"
"""

import argparse
import datetime
import json
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
STUDIO = HERE.parent
PROJECTS = STUDIO / "projects"
REMOTION = STUDIO / "remotion"

MESES_ES = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
]


def formatear_fecha_carpeta(dt: datetime.datetime | None = None) -> str:
    if dt is None:
        dt = datetime.datetime.now()
    return f"{dt.day} de {MESES_ES[dt.month - 1]} de {dt.year}"


def validar_id(identificador: str) -> str:
    if not re.match(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", identificador):
        raise ValueError(f"ID inválido: '{identificador}'. Use minúsculas y guiones (ej. 'ia-control-futuro').")
    return identificador


def generar_storyboard_plantilla(titulo: str, tema: str) -> dict:
    return {
        "title": titulo,
        "voice": "es-MX-JorgeNeural",
        "rate": "+15%",
        "scenes": [
            {
                "id": "hook",
                "chapter": "EL DILEMA",
                "palette": "purple",
                "text": f"¿Qué ocurre cuando creamos una tecnología más inteligente que nosotros… y perdemos el control?",
                "minSeconds": 4.5
            },
            {
                "id": "balance",
                "chapter": "PROMESA Y RIESGO",
                "palette": "teal",
                "text": "La inteligencia artificial promete curar enfermedades y multiplicar nuestra capacidad creadora.",
                "minSeconds": 4.0
            },
            {
                "id": "core_mechanism",
                "chapter": "EL MOTOR DE LA IA",
                "palette": "purple",
                "text": "En el fondo, son modelos matemáticos que aprenden a optimizar objetivos a gran velocidad.",
                "minSeconds": 4.2
            },
            {
                "id": "acceleration",
                "chapter": "CRECIMIENTO EXPONENCIAL",
                "palette": "purple",
                "text": "Cada iteración no es el doble de rápida: es órdenes de magnitud más potente.",
                "minSeconds": 3.8
            },
            {
                "id": "alignment_gap",
                "chapter": "EL DESALINEAMIENTO",
                "palette": "gold",
                "text": "El peligro real no es la maldad, sino darle un objetivo que cumpla a cualquier costo.",
                "minSeconds": 4.2
            },
            {
                "id": "consequence",
                "chapter": "EL IMPACTO INVISIBLE",
                "palette": "purple",
                "text": "Si optimiza una variable ignorando el bienestar humano, el resultado puede ser irreversible.",
                "minSeconds": 4.4
            },
            {
                "id": "action",
                "chapter": "ACTUAR HOY",
                "palette": "teal",
                "text": "La regulación y la seguridad deben avanzar más rápido que la propia aceleración tecnológica.",
                "minSeconds": 4.8
            }
        ],
        "editorialNotes": f"Producción 2D estandarizada sobre: {tema}. Arte vectorial SVG original con cinemática inversa y dinamismo pedagógico."
    }


def crear_proyecto(prod_id: str, titulo: str, tema: str = "", fecha: str = ""):
    validar_id(prod_id)
    carpeta_fecha = fecha.strip() or formatear_fecha_carpeta()
    fecha_dir = PROJECTS / carpeta_fecha
    fecha_dir.mkdir(parents=True, exist_ok=True)
    proj_dir = fecha_dir / prod_id
    src_dir = proj_dir / "src"
    public_dir = proj_dir / "public"
    renders_dir = proj_dir / "renders"
    stills_dir = renders_dir / "stills"

    if proj_dir.exists():
        print(f"Error: El proyecto '{prod_id}' ya existe en {proj_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Creando proyecto 2D auto-contenido '{prod_id}' en {proj_dir} (Fecha: {carpeta_fecha})...")
    proj_dir.mkdir(parents=True, exist_ok=True)
    src_dir.mkdir(parents=True, exist_ok=True)
    public_dir.mkdir(parents=True, exist_ok=True)
    renders_dir.mkdir(parents=True, exist_ok=True)
    stills_dir.mkdir(parents=True, exist_ok=True)

    # 1. Copiar tipografía si existe en el sistema o proyectos hermanos
    fuente_candidatos = list(PROJECTS.glob("*/*/public/UbuntuSans.ttf")) + list(PROJECTS.glob("*/public/UbuntuSans.ttf")) + [
        Path("/usr/share/fonts/truetype/ubuntu/UbuntuSans[wdth,wght].ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    ]
    for c in fuente_candidatos:
        if c.exists():
            shutil.copy2(c, public_dir / "UbuntuSans.ttf")
            break

    # 2. project.json con metadatos del proyecto
    project_metadata = {
        "id": prod_id,
        "title": titulo,
        "description": tema or titulo,
        "created_at": datetime.datetime.now().isoformat(),
        "type": "2d-animation",
        "fps": 30,
        "resolution": {
            "width": 1080,
            "height": 1920
        },
        "author": "VideoStudio Agent",
        "version": "1.0.0"
    }
    (proj_dir / "project.json").write_text(json.dumps(project_metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # 3. tsconfig.json local para resolución de tipos en IDE
    (proj_dir / "tsconfig.json").write_text('{\n  "extends": "../../tsconfig.json",\n  "include": ["src/**/*"]\n}\n', encoding="utf-8")

    # 4. storyboard.json
    storyboard = generar_storyboard_plantilla(titulo, tema or titulo)
    (proj_dir / "storyboard.json").write_text(json.dumps(storyboard, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # 5. prepare.py autónomo (guarda directo en public/ y src/)
    prepare_script = f'''"""Preparación de audio TTS y sincronización temporal para {prod_id}."""
import asyncio
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import edge_tts
import numpy as np

HERE = Path(__file__).resolve().parent
def find_studio(p: Path) -> Path:
    curr = p
    while curr != curr.parent:
        if (curr / "remotion/package.json").exists(): return curr
        curr = curr.parent
    return p.parents[1]

STUDIO = find_studio(HERE)
PUBLIC = HERE / "public"
SOURCE = HERE / "src"
ASSETS = STUDIO / "assets"
FPS = 30


def get_duration(path):
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path)], text=True))


async def generate_narration(scene, config, sem):
    target = PUBLIC / f"{{scene['id']}}.mp3"
    cache_dir = HERE / "audio_cache"
    cache_dir.mkdir(exist_ok=True)
    cache = cache_dir / f"{{scene['id']}}.json"
    key = hashlib.sha256(json.dumps([scene['text'], config.get('voice', 'es-MX-JorgeNeural'), config.get('rate', '+0%'), config.get('voice_provider', 'edge-tts'), config.get('applio_model', '')]).encode()).hexdigest()
    if target.exists() and cache.exists():
        data = json.loads(cache.read_text(encoding="utf-8"))
        if data.get('key') == key and target.stat().st_size > 1000:
            return data
    async with sem:
        for attempt in range(3):
            try:
                words = []
                partial = target.with_suffix('.partial.mp3')
                is_applio = config.get('voice_provider') == 'applio' or config.get('applio_model')
                base_voice = config.get('voice_base', 'es-CL-LorenzoNeural') if is_applio else config['voice']
                base_rate = config.get('rate_base', '+18%') if is_applio else config['rate']
                tts = edge_tts.Communicate(scene['text'], base_voice, rate=base_rate, boundary='WordBoundary')
                with partial.open('wb') as stream:
                    async for chunk in tts.stream():
                        ctype = chunk.get('type')
                        if ctype == 'audio':
                            cdata = chunk.get('data')
                            if cdata:
                                stream.write(cdata)
                        elif ctype == 'WordBoundary':
                            ctext = chunk.get('text') or ''
                            coffset = float(chunk.get('offset') or 0)
                            cduration = float(chunk.get('duration') or 0)
                            words.append({{'word': ctext, 'start': coffset / 1e7, 'end': (coffset + cduration) / 1e7}})
                seconds = get_duration(partial)
                if not words or seconds <= 0:
                    raise RuntimeError(f"No word timestamps/audio for {{scene['id']}}")
                partial.replace(target)
                if is_applio:
                    model_name = config.get('applio_model', 'Morgan_Freeman')
                    applio_dir = find_studio(HERE).parent / "Applio"
                    if applio_dir.exists():
                        model_dir = applio_dir / "logs" / model_name
                        pths = list(model_dir.glob("*.pth")) if model_dir.exists() else []
                        if not pths:
                            pths = list((applio_dir / "logs").glob(f"*{{model_name}}*/**/*.pth")) or list((applio_dir / "logs").glob("**/*.pth"))
                        indexes = list(model_dir.glob("*.index")) if model_dir.exists() else []
                        if not indexes:
                            indexes = list((applio_dir / "logs").glob(f"*{{model_name}}*/**/*.index"))
                        if pths:
                            converted = target.with_suffix('.converted.wav')
                            py_bin = str(applio_dir / ".venv" / "bin" / "python")
                            cmd = [
                                py_bin, "core.py", "infer",
                                "--input-path", str(target),
                                "--output-path", str(converted),
                                "--pth-path", str(pths[0]),
                                "--pitch", "0",
                                "--index-rate", "1.0",
                            ]
                            if indexes:
                                cmd.extend(["--index-path", str(indexes[0])])
                            env = os.environ.copy()
                            env["LD_LIBRARY_PATH"] = f"{{applio_dir}}/libs/usr/lib/x86_64-linux-gnu:{{env.get('LD_LIBRARY_PATH', '')}}"
                            res = subprocess.run(cmd, cwd=str(applio_dir), env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                            if res.returncode == 0 and converted.exists():
                                subprocess.run(["ffmpeg", "-y", "-i", str(converted), "-q:a", "0", str(target)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                                converted.unlink(missing_ok=True)
                                seconds = get_duration(target)
                data = {{'key': key, 'duration': seconds, 'words': words}}
                cache.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"Audio {{scene['id']}}: {{seconds:.2f}}s, {{len(words)}} palabras", flush=True)
                return data
            except Exception:
                if attempt == 2:
                    raise
                await asyncio.sleep(1 + attempt)
    raise RuntimeError(f"Fallo al sintetizar audio para la escena {{scene['id']}}")


def generate_procedural_score(scenes, total_seconds):
    sr = 32000
    count = math.ceil(total_seconds * sr)
    audio = np.zeros((count, 2), dtype=np.float64)

    def add_signal(sig, at, gain=1.0, pan=0.0):
        start = int(at * sr)
        if start < 0 or start >= count:
            return
        chunk = sig[:count - start] * gain
        audio[start:start + len(chunk), 0] += chunk * math.sqrt((1 - pan) / 2)
        audio[start:start + len(chunk), 1] += chunk * math.sqrt((1 + pan) / 2)

    notes = [[220, 261.63, 329.63, 440], [174.61, 220, 261.63, 349.23], [196, 261.63, 329.63, 392], [196, 246.94, 293.66, 392]]
    for beat in range(math.ceil(total_seconds / 0.375)):
        at = beat * 0.375
        note = notes[(beat // 16) % 4][beat % 4]
        t = np.arange(int(sr * 1.5)) / sr
        env = (1 - np.exp(-t * 45)) * np.exp(-t * 4.5)
        sig = (np.sin(2 * np.pi * note * t) + 0.22 * np.sin(2 * np.pi * note * 2 * t)) * env
        add_signal(sig, at, 0.015, math.sin(beat) * 0.4)

    max_val = np.max(np.abs(audio))
    if max_val > 0.95:
        audio = audio / max_val * 0.95
    pcm = (audio * 32767).astype(np.int16)
    score_path = PUBLIC / "score.wav"
    import wave
    with wave.open(str(score_path), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(sr)
        wav.writeframes(pcm.tobytes())
    print(f"Banda sonora guardada en: {{score_path}}")


async def main():
    storyboard = json.loads((HERE / "storyboard.json").read_text(encoding="utf-8"))
    sem = asyncio.Semaphore(2)
    tasks = [generate_narration(sc, storyboard, sem) for sc in storyboard["scenes"]]
    narrations = await asyncio.gather(*tasks)

    timeline_scenes = []
    current_frame = 0
    for sc, nar in zip(storyboard["scenes"], narrations):
        raw_min = sc.get("minSeconds", 2.0)
        min_sec = float(raw_min) if isinstance(raw_min, (int, float, str)) else 2.0
        raw_dur = nar.get("duration", 0.0) if nar else 0.0
        nar_dur = float(raw_dur) if isinstance(raw_dur, (int, float, str)) else 0.0
        dur = max(min_sec, nar_dur + 0.3) if nar else min_sec
        frames = math.ceil(dur * FPS)
        timeline_scenes.append({{
            **sc,
            "start": current_frame,
            "frames": frames,
            "words": nar.get("words", []) if nar else [],
            "audio": f"{{sc['id']}}.mp3"
        }})
        current_frame += frames

    timeline_data = {{
        "title": storyboard["title"],
        "fps": FPS,
        "durationInFrames": current_frame,
        "scenes": timeline_scenes
    }}

    timeline_json = json.dumps(timeline_data, ensure_ascii=False, indent=2) + "\\n"
    (HERE / "timeline.json").write_text(timeline_json, encoding="utf-8")
    (SOURCE / "timeline.json").write_text(timeline_json, encoding="utf-8")
    generate_procedural_score(timeline_scenes, current_frame / FPS)
    print(f"Timeline completado: {{current_frame}} frames ({{current_frame / FPS:.2f}}s)")
    if storyboard.get("voice_provider") == "elevenlabs":
        try:
            import urllib.request
            key = ""
            env_path = find_studio(HERE) / "backend/.env"
            if env_path.exists():
                for line in env_path.read_text(encoding="utf-8").splitlines():
                    if line.startswith("ELEVENLABS_API_KEY="):
                        key = line.split("=", 1)[1].strip().strip("\"'")
                        break
            if key:
                req = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={{"xi-api-key": key}})
                with urllib.request.urlopen(req, timeout=15) as resp:
                    sub = json.loads(resp.read().decode())
                    rem = sub.get("character_limit", 10000) - sub.get("character_count", 0)
                    print(f"\\n💳 Créditos ElevenLabs: {{rem:,}} restantes (usados: {{sub.get('character_count', 0):,}} / límite: {{sub.get('character_limit', 10000):,}})")
        except Exception:
            pass


if __name__ == "__main__":
    asyncio.run(main())
'''
    (proj_dir / "prepare.py").write_text(prepare_script, encoding="utf-8")

    # 5. render.mjs autónomo multi-aspecto (9:16 y 16:9)
    render_script = f'''import {{createRequire}} from 'node:module';
import {{fileURLToPath}} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import {{execFileSync, execSync}} from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
function findStudio(dir) {{
  let curr = dir;
  while (curr !== path.dirname(curr)) {{
    if (fsSync.existsSync(path.join(curr, 'remotion/package.json'))) return curr;
    curr = path.dirname(curr);
  }}
  return path.resolve(dir, '../..');
}}
const studio = findStudio(here);
const remotion = path.join(studio, 'remotion');
const require = createRequire(path.join(remotion, 'package.json'));
const {{bundle}} = require('@remotion/bundler');
const {{selectComposition, renderMedia, renderStill}} = require('@remotion/renderer');

const timeline = JSON.parse(await fs.readFile(path.join(here, 'timeline.json'), 'utf8'));
const renders = path.join(here, 'renders');
const stillsDir = path.join(renders, 'stills');
await fs.mkdir(stillsDir, {{recursive: true}});

const stills = process.argv.includes('--stills');
const draft = process.argv.includes('--draft');
const horizontal = process.argv.includes('--horizontal') || process.argv.includes('--aspect=horizontal');
const bothAspects = process.argv.includes('--both') || process.argv.includes('--aspect=both');
const baseId = '{prod_id}';

console.log(`[Proyecto: ${{baseId}}] Compilando bundle Remotion autónomo...`);
const serveUrl = await bundle({{
  entryPoint: path.join(here, 'src/index.tsx'),
  publicDir: path.join(here, 'public'),
  webpackOverride: (config) => {{
    config.resolve.modules = [
      path.join(remotion, 'node_modules'),
      'node_modules'
    ];
    return config;
  }}
}});

const chromiumOptions = {{gl: 'angle'}};

if (stills) {{
  const composition = await selectComposition({{serveUrl, id: baseId, chromiumOptions}});
  console.log(`Generando stills de verificación para ${{timeline.scenes.length}} escenas...`);
  for (const scene of timeline.scenes) {{
    const frame = scene.start + Math.floor(scene.frames * 0.67);
    const stillPath = path.join(stillsDir, `${{scene.id}}.png`);
    await renderStill({{
      serveUrl, composition, output: stillPath,
      frame, imageFormat: 'png', scale: 2/3, chromiumOptions
    }});
    console.log(`  ✓ STILL ${{scene.id}} @${{(frame / 30).toFixed(2)}}s`);
  }}
  const contactSheet = path.join(renders, 'contact-sheet.jpg');
  try {{
    execSync(`ffmpeg -v error -y -pattern_type glob -i '${{stillsDir}}/*.png' -vf 'scale=240:-1,tile=4x4:padding=6:margin=6' -frames:v 1 '${{contactSheet}}'`);
    console.log(`[OK] Mosaico de control generado en: ${{contactSheet}}`);
  }} catch (err) {{
    console.warn(`No se pudo generar contact-sheet.jpg: ${{err.message}}`);
  }}
}} else {{
  const targets = [];
  if (bothAspects) {{
    targets.push({{ id: baseId, name: draft ? 'preview-720p.mp4' : 'master-1080p.mp4', label: '9:16 Vertical' }});
    targets.push({{ id: `${{baseId}}-16x9`, name: draft ? 'preview-16x9-720p.mp4' : 'master-16x9-1080p.mp4', label: '16:9 Horizontal' }});
  }} else if (horizontal) {{
    targets.push({{ id: `${{baseId}}-16x9`, name: draft ? 'preview-16x9-720p.mp4' : 'master-16x9-1080p.mp4', label: '16:9 Horizontal' }});
  }} else {{
    targets.push({{ id: baseId, name: draft ? 'preview-720p.mp4' : 'master-1080p.mp4', label: '9:16 Vertical' }});
  }}

  for (const target of targets) {{
    console.log(`\\nRenderizando ${{target.name}} [${{target.label}}] (${{draft ? '720p Borrador' : '1080p Master'}})...`);
    const composition = await selectComposition({{serveUrl, id: target.id, chromiumOptions}});
    const final = path.join(renders, target.name);
    const partial = path.join(renders, `partial-${{target.name}}`);
    let progress = -1;

    await renderMedia({{
      serveUrl, composition, outputLocation: partial, codec: 'h264', crf: draft ? 23 : 17,
      pixelFormat: 'yuv420p', audioCodec: 'aac', audioBitrate: '192k',
      scale: draft ? 2/3 : 1, concurrency: 4, chromiumOptions,
      onProgress: ({{progress: p}}) => {{
        const n = Math.floor(p * 20) * 5;
        if (n !== progress) {{ progress = n; console.log(`RENDER [${{target.label}}] ${{n}}%`); }}
      }}
    }});

    const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', partial], {{encoding: 'utf8'}}));
    await fs.rename(partial, final);
    console.log(`[ÉXITO] Video guardado en: ${{final}}`);
    console.log(`Duración: ${{probe.format.duration}}s | Tamaño: ${{(Number(probe.format.size) / 1024 / 1024).toFixed(1)}} MB | Resolución: ${{probe.streams[0].width}}x${{probe.streams[0].height}}`);
  }}
}}
'''
    (proj_dir / "render.mjs").write_text(render_script, encoding="utf-8")

    # 6. src/index.tsx (Entrypoint autónomo con 9:16 y 16:9)
    component_name = "".join(p.capitalize() for p in prod_id.split("-")) + "Film"
    index_tsx = f'''import React from 'react';
import {{ registerRoot, Composition }} from 'remotion';
import {{ {component_name}, timeline }} from './Film';

export const ProjectRoot: React.FC = () => {{
  return (
    <>
      <Composition
        id="{prod_id}"
        component={{{component_name}}}
        durationInFrames={{timeline.durationInFrames}}
        fps={{30}}
        width={{1080}}
        height={{1920}}
        defaultProps={{{{ aspectRatio: '9:16' as const }}}}
      />
      <Composition
        id="{prod_id}-16x9"
        component={{{component_name}}}
        durationInFrames={{timeline.durationInFrames}}
        fps={{30}}
        width={{1920}}
        height={{1080}}
        defaultProps={{{{ aspectRatio: '16:9' as const }}}}
      />
    </>
  );
}};

registerRoot(ProjectRoot);
'''
    (src_dir / "index.tsx").write_text(index_tsx, encoding="utf-8")

    # 7. src/art.tsx (Rigging, vectores y componentes reutilizables)
    art_content = '''import React from 'react';

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const wave = (f: number, speed = 0.06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
export const seeded = (n: number) => { const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; return a - Math.floor(a); };
type Point = { x: number; y: number };

export const ArtDefs = () => (
  <defs>
    <radialGradient id="bg-purple" cx="42%" cy="34%" r="80%">
      <stop stopColor="#6342a4"/>
      <stop offset=".5" stopColor="#34205f"/>
      <stop offset="1" stopColor="#160e35"/>
    </radialGradient>
    <radialGradient id="bg-teal" cx="48%" cy="30%" r="80%">
      <stop stopColor="#2caead"/>
      <stop offset=".55" stopColor="#116476"/>
      <stop offset="1" stopColor="#112c52"/>
    </radialGradient>
    <radialGradient id="bg-gold" cx="50%" cy="45%" r="65%">
      <stop stopColor="#fffab0"/>
      <stop offset=".42" stopColor="#ffe35f"/>
      <stop offset="1" stopColor="#f4a72c"/>
    </radialGradient>
    <linearGradient id="skin" x1="0" x2="1" y2=".5">
      <stop stopColor="#e9a05d"/>
      <stop offset=".5" stopColor="#c97943"/>
      <stop offset="1" stopColor="#b55b38"/>
    </linearGradient>
    <linearGradient id="cyan" x1="0" x2="1" y2="1">
      <stop stopColor="#85f9ee"/>
      <stop offset=".5" stopColor="#31d1e5"/>
      <stop offset="1" stopColor="#1a9cca"/>
    </linearGradient>
    <radialGradient id="aura">
      <stop stopColor="#65f4ef" stopOpacity=".55"/>
      <stop offset=".55" stopColor="#65f4ef" stopOpacity=".15"/>
      <stop offset="1" stopColor="#65f4ef" stopOpacity="0"/>
    </radialGradient>
    <pattern id="dust" width="83" height="83" patternUnits="userSpaceOnUse">
      <circle cx="8" cy="12" r=".8" fill="white" opacity=".12"/>
      <circle cx="41" cy="62" r=".7" fill="white" opacity=".09"/>
    </pattern>
  </defs>
);

export function Backdrop({ palette, f }: { palette: string; f: number }) {
  return (
    <g>
      <rect width="720" height="1280" fill={`url(#bg-${palette})`} />
      <rect width="720" height="1280" fill="url(#dust)" />
    </g>
  );
}

export function Label({ x, y, text, color = '#effdff', size = 23 }: { x: number; y: number; text: string; color?: string; size?: number }) {
  const w = text.length * size * 0.54 + 30;
  return (
    <g transform={`translate(${x} ${y})`}>
      <rect x={-w / 2} y={-size - 7} width={w} height={size + 20} rx="10" fill="#1b173a" opacity=".85"/>
      <text textAnchor="middle" fill={color} fontSize={size} fontWeight="750">{text}</text>
    </g>
  );
}

export function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx = b.x - a.x, dy = b.y - a.y;
  const d = clamp(Math.hypot(dx, dy), 1, l1 + l2 - 0.01);
  const angle = Math.atan2(dy, dx) + bend * Math.acos(clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1));
  return { x: a.x + Math.cos(angle) * l1, y: a.y + Math.sin(angle) * l1 };
}
'''
    (src_dir / "art.tsx").write_text(art_content, encoding="utf-8")

    # 8. src/Film.tsx
    film_content = f'''import React, {{useEffect, useState}} from 'react';
import {{AbsoluteFill, Audio, Sequence, cancelRender, continueRender, delayRender, staticFile, useCurrentFrame}} from 'remotion';
import timelineData from './timeline.json';
import {{ArtDefs, Backdrop, Label, ease, mix, clamp}} from './art';

export const timeline = timelineData;
type Scene = typeof timeline.scenes[number];

const getAsset = (file: string) => staticFile(file.split('/').pop() || file);

function Captions({{scene, f}}: {{scene: Scene; f: number}}) {{
  const time = f / 30;
  const words = scene.words || [];
  if (!words.length) return null;
  let current = words.findIndex(w => time >= w.start && time < w.end);
  if (current < 0) current = Math.max(0, words.findIndex(w => w.start > time) - 1);
  if (time >= words[words.length - 1].end) current = words.length - 1;

  const groups: {{word: string; start: number; end: number}}[][] = [];
  for (const word of words) {{
    const last = groups[groups.length - 1];
    if (!last || last.length >= 5 || last.map(w => w.word).join(' ').length + word.word.length > 30) {{
      groups.push([word]);
    }} else {{
      last.push(word);
    }}
  }}
  const active = words[current];
  const group = groups.find(g => g.includes(active)) || groups[0];
  const pop = ease((time - group[0].start) * 12);

  return (
    <div style={{{{
      position: 'absolute', left: 48, top: 174, width: 624, textAlign: 'center',
      fontSize: 35, lineHeight: 1.32, fontWeight: 750, letterSpacing: -0.6,
      transform: 'translateY(' + mix(6, 0, pop) + 'px)', color: '#fff8f1',
      textShadow: '0 3px 15px rgba(20,10,42,0.4)'
    }}}}>
      {{group.map((w, i) => (
        <span key={{w.start + '-' + i}} style={{{{
          display: 'inline-block', padding: '2px 7px', margin: '1px 0', borderRadius: 8,
          background: w === active ? 'rgba(25,18,52,0.66)' : 'transparent',
          color: w === active ? '#fff8bb' : '#fff9ef',
          opacity: time >= w.start ? 1 : 0.58
        }}}}>{{w.word}} </span>
      ))}}
    </div>
  );
}}

function Shot({{scene, index}}: {{scene: Scene; index: number}}) {{
  const f = useCurrentFrame();
  const camera = 1 + ease(f / scene.frames) * 0.018;
  return (
    <AbsoluteFill style={{{{background: scene.palette === 'gold' ? '#f7bc45' : scene.palette === 'teal' ? '#12576a' : '#2c1a50'}}}}>
      <svg width="720" height="1280" viewBox="0 0 720 1280" style={{{{position: 'absolute', inset: 0, overflow: 'hidden'}}}}>
        <ArtDefs />
        <Backdrop palette={{scene.palette}} f={{f}} />
        <g transform={{'translate(360 730) scale(' + camera + ') translate(-360 -730)'}}>
          <Label x={{360}} y={{700}} text={{scene.chapter}} size={{26}} />
        </g>
        <g fill="#d0bee7" opacity="0.7" fontSize="16" fontWeight="700" letterSpacing="2.2">
          <text x="48" y="75">{prod_id.upper()}</text>
          <text x="672" y="75" textAnchor="end">{{String(index + 1).padStart(2, '0')}} / {{timeline.scenes.length}}</text>
        </g>
        <rect x="48" y="1213" width="624" height="3" rx="2" fill="#ae92d7" opacity="0.2" />
        <rect x="48" y="1213" width={{624 * clamp((scene.start + f) / timeline.durationInFrames)}} height="3" rx="2" fill="#c5b5ea" opacity="0.6" />
      </svg>
      <Captions scene={{scene}} f={{f}} />
    </AbsoluteFill>
  );
}}

export const {component_name}: React.FC<{{aspectRatio?: '9:16' | '16:9'}}> = ({{aspectRatio = '9:16'}}) => {{
  const isHorizontal = aspectRatio === '16:9';
  const [handle] = useState(() => delayRender('Cargando tipografía'));
  useEffect(() => {{
    const font = new FontFace('StudioSans', `url(${{getAsset('UbuntuSans.ttf')}})`, {{weight: '100 900'}});
    font.load().then(loaded => {{ document.fonts.add(loaded); continueRender(handle); }}).catch(cancelRender);
  }}, [handle]);

  return (
    <AbsoluteFill style={{{{background: '#21153b', fontFamily: 'StudioSans, sans-serif'}}}}>
      {{isHorizontal ? (
        <div style={{{{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'radial-gradient(ellipse at center, #2e1a54 0%, #110924 100%)'
        }}}}>
          <div style={{{{
            position: 'relative',
            width: 720,
            height: 1280,
            transform: 'scale(0.84375)',
            boxShadow: '0 0 120px rgba(0,0,0,0.7)',
            borderRadius: 24,
            overflow: 'hidden'
          }}}}>
            {{timeline.scenes.map((scene, i) => (
              <Sequence key={{scene.id}} from={{scene.start}} durationInFrames={{scene.frames}}>
                <Shot scene={{scene}} index={{i}} />
                <Audio src={{getAsset(scene.audio)}} volume={{0.95}} />
              </Sequence>
            ))}}
          </div>
        </div>
      ) : (
        <div style={{{{position: 'absolute', width: 720, height: 1280, transform: 'scale(1.5)', transformOrigin: 'top left'}}}}>
          {{timeline.scenes.map((scene, i) => (
            <Sequence key={{scene.id}} from={{scene.start}} durationInFrames={{scene.frames}}>
              <Shot scene={{scene}} index={{i}} />
              <Audio src={{getAsset(scene.audio)}} volume={{0.95}} />
            </Sequence>
          ))}}
        </div>
      )}}
      <Audio src={{getAsset('score.wav')}} volume={{0.8}} />
    </AbsoluteFill>
  );
}};
'''
    (src_dir / "Film.tsx").write_text(film_content, encoding="utf-8")

    # 9. timeline.json inicial
    dummy_timeline = {
        "title": titulo,
        "fps": 30,
        "durationInFrames": 300,
        "scenes": [
            {
                "id": "hook",
                "chapter": "INTRO",
                "palette": "purple",
                "text": "Introducción",
                "start": 0,
                "frames": 300,
                "words": [{"word": "Introducción", "start": 0.0, "end": 1.0}],
                "audio": "hook.mp3"
            }
        ]
    }
    (proj_dir / "timeline.json").write_text(json.dumps(dummy_timeline, indent=2) + "\n", encoding="utf-8")
    (src_dir / "timeline.json").write_text(json.dumps(dummy_timeline, indent=2) + "\n", encoding="utf-8")

    # 10. Registrar script directo en remotion/package.json
    registrar_en_package_json(prod_id, carpeta_fecha)

    print(f"\n[OK] Proyecto 2D '{prod_id}' creado exitosamente en:")
    print(f"     {proj_dir}")
    print("\nFlujo canónico de desarrollo:")
    print(f"1. Editar guion y capítulos en: video-studio/projects/{carpeta_fecha}/{prod_id}/storyboard.json")
    print(f"2. Generar voces y música:      python3 \"video-studio/projects/{carpeta_fecha}/{prod_id}/prepare.py\"")
    print(f"3. Ilustrar biblioteca en:      video-studio/projects/{carpeta_fecha}/{prod_id}/src/art.tsx")
    print(f"4. Generar hoja de contactos:   node \"video-studio/projects/{carpeta_fecha}/{prod_id}/render.mjs\" --stills")
    print(f"5. Revisar renders/contact-sheet.jpg y renderizar: node \"video-studio/projects/{carpeta_fecha}/{prod_id}/render.mjs\"")


def registrar_en_package_json(prod_id: str, carpeta_fecha: str):
    pkg_path = REMOTION / "package.json"
    if not pkg_path.exists():
        return
    try:
        pkg = json.loads(pkg_path.read_text(encoding="utf-8"))
        pkg["scripts"][f"render:{prod_id}"] = f'node "../projects/{carpeta_fecha}/{prod_id}/render.mjs"'
        pkg_path.write_text(json.dumps(pkg, indent=2) + "\n", encoding="utf-8")
        print(f"Registrado script 'npm run render:{prod_id}' en remotion/package.json")
    except Exception as e:
        print(f"Advertencia al actualizar package.json: {e}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", required=True, help="Identificador slug (ej. 'ia-control-futuro')")
    parser.add_argument("--titulo", required=True, help="Título del video")
    parser.add_argument("--tema", default="", help="Descripción del tema o tesis")
    parser.add_argument("--fecha", default="", help="Carpeta de fecha personalizada (ej. '25 de octubre de 2026'). Por defecto fecha actual.")
    args = parser.parse_args()
    crear_proyecto(args.id, args.titulo, args.tema, args.fecha)


if __name__ == "__main__":
    main()
