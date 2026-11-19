import fsSync from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import { execSync } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
function findStudio(dir) {
  let curr = dir;
  while (curr !== path.dirname(curr)) {
    if (fsSync.existsSync(path.join(curr, 'remotion/package.json'))) return curr;
    curr = path.dirname(curr);
  }
  return path.resolve(dir, '../..');
}
const studio = findStudio(here);
const remotion = path.join(studio, 'remotion');
const require = createRequire(path.join(remotion, 'package.json'));
const { bundle } = require('@remotion/bundler');
const { selectComposition, renderMedia, renderStill } = require('@remotion/renderer');

const timeline = JSON.parse(await fs.readFile(path.join(here, 'timeline.json'), 'utf8'));
const renders = path.join(here, 'renders');
const stillsDir = path.join(renders, 'stills');
await fs.mkdir(stillsDir, { recursive: true });

const stills = process.argv.includes('--stills');
const draft = process.argv.includes('--draft');
const baseId = timeline.id;

console.log(`[Proyecto Test: ${baseId}] Compilando bundle Remotion...`);
const serveUrl = await bundle({
  entryPoint: path.join(here, 'src/index.tsx'),
  webpackOverride: (config) => {
    config.resolve.modules = [
      path.join(remotion, 'node_modules'),
      'node_modules',
    ];
    return config;
  },
});

const chromiumOptions = { gl: 'angle' };
const composition = await selectComposition({ serveUrl, id: baseId, chromiumOptions });

if (stills) {
  console.log(`Generando stills de verificación para ${timeline.scenes.length} escenas...`);
  for (const scene of timeline.scenes) {
    const frame = scene.start + Math.floor(scene.frames * 0.6);
    const stillPath = path.join(stillsDir, `${scene.id}.png`);
    await renderStill({
      serveUrl,
      composition,
      output: stillPath,
      frame,
      imageFormat: 'png',
      scale: 0.5,
      chromiumOptions,
    });
    console.log(`  ✓ STILL ${scene.id} @${(frame / 30).toFixed(2)}s`);
  }
  const contactSheet = path.join(renders, 'contact-sheet.jpg');
  execSync(`ffmpeg -v error -y -pattern_type glob -i '${stillsDir}/*.png' -vf 'scale=270:-1,tile=5x1:padding=6:margin=6' -frames:v 1 '${contactSheet}'`);
  console.log(`[OK] Contact sheet: ${contactSheet}`);
} else {
  const outName = draft ? 'preview-720p.mp4' : 'master-1080p.mp4';
  const outPath = path.join(renders, outName);
  console.log(`Renderizando ${outPath} (${draft ? '720p borrador' : '1080p master'})...`);
  await renderMedia({
    composition,
    serveUrl,
    codec: 'h264',
    outputLocation: outPath,
    crf: draft ? 23 : 18,
    scale: draft ? 2 / 3 : 1,
    chromiumOptions,
  });
  console.log(`[OK] Video generado: ${outPath}`);
}
