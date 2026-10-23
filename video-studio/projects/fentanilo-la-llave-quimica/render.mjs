import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import {execFileSync, execSync} from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const studio = path.resolve(here, '../..');
const remotion = path.join(studio, 'remotion');
const require = createRequire(path.join(remotion, 'package.json'));
const {bundle} = require('@remotion/bundler');
const {selectComposition, renderMedia, renderStill} = require('@remotion/renderer');

const timeline = JSON.parse(await fs.readFile(path.join(here, 'timeline.json'), 'utf8'));
const renders = path.join(here, 'renders');
const stillsDir = path.join(renders, 'stills');
await fs.mkdir(stillsDir, {recursive: true});

const stills = process.argv.includes('--stills');
const draft = process.argv.includes('--draft');
const compositionId = 'fentanilo-la-llave-quimica';

console.log(`[Proyecto: ${compositionId}] Compilando bundle Remotion autónomo...`);
const serveUrl = await bundle({
  entryPoint: path.join(here, 'src/index.tsx'),
  publicDir: path.join(here, 'public'),
  webpackOverride: (config) => {
    config.resolve.modules = [
      path.join(remotion, 'node_modules'),
      'node_modules'
    ];
    return config;
  }
});

const chromiumOptions = {gl: 'angle'};
const composition = await selectComposition({serveUrl, id: compositionId, chromiumOptions});

if (stills) {
  console.log(`Generando stills de verificación para ${timeline.scenes.length} escenas...`);
  for (const scene of timeline.scenes) {
    const frame = scene.start + Math.floor(scene.frames * 0.67);
    const stillPath = path.join(stillsDir, `${scene.id}.png`);
    await renderStill({
      serveUrl, composition, output: stillPath,
      frame, imageFormat: 'png', scale: 2/3, chromiumOptions
    });
    console.log(`  ✓ STILL ${scene.id} @${(frame / 30).toFixed(2)}s`);
  }
  const contactSheet = path.join(renders, 'contact-sheet.jpg');
  try {
    execSync(`ffmpeg -v error -y -pattern_type glob -i '${stillsDir}/*.png' -vf 'scale=240:-1,tile=4x4:padding=6:margin=6' -frames:v 1 '${contactSheet}'`);
    console.log(`[OK] Mosaico de control generado en: ${contactSheet}`);
  } catch (err) {
    console.warn(`No se pudo generar contact-sheet.jpg: ${err.message}`);
  }
} else {
  const name = draft ? 'preview-720p.mp4' : 'master-1080p.mp4';
  const final = path.join(renders, name);
  const partial = path.join(renders, `partial-${name}`);
  let progress = -1;

  console.log(`Renderizando ${name} (${draft ? '720p Borrador' : '1080p Master'})...`);
  await renderMedia({
    serveUrl, composition, outputLocation: partial, codec: 'h264', crf: draft ? 23 : 17,
    pixelFormat: 'yuv420p', audioCodec: 'aac', audioBitrate: '192k',
    scale: draft ? 2/3 : 1, concurrency: 4, chromiumOptions,
    onProgress: ({progress: p}) => {
      const n = Math.floor(p * 20) * 5;
      if (n !== progress) { progress = n; console.log(`RENDER ${n}%`); }
    }
  });

  const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', partial], {encoding: 'utf8'}));
  await fs.rename(partial, final);
  console.log(`\n[ÉXITO] Video guardado en: ${final}`);
  console.log(`Duración: ${probe.format.duration}s | Tamaño: ${(Number(probe.format.size) / 1024 / 1024).toFixed(1)} MB`);
}
