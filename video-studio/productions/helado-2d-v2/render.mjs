import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import {execFileSync} from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const studio = path.resolve(here, '../..');
const remotion = path.join(studio, 'remotion');
const require = createRequire(path.join(remotion, 'package.json'));
const {bundle} = require('@remotion/bundler');
const {selectComposition, renderMedia, renderStill} = require('@remotion/renderer');

const timeline = JSON.parse(await fs.readFile(path.join(here, 'timeline.json'), 'utf8'));
const renders = path.join(here, 'renders');
await fs.mkdir(renders, {recursive: true});

const stills = process.argv.includes('--stills');
const draft = process.argv.includes('--draft');
const compositionId = 'helado-2d-v2';

console.log(`Compilando bundle Remotion para ${compositionId}...`);
const serveUrl = await bundle({entryPoint: path.join(remotion, 'src/index.ts'), publicDir: path.join(remotion, 'public')});
const chromiumOptions = {gl: 'angle'};
const composition = await selectComposition({serveUrl, id: compositionId, chromiumOptions});

if (stills) {
  console.log(`Generando stills de verificación...`);
  for (const scene of timeline.scenes) {
    const frame = scene.start + Math.floor(scene.frames * 0.67);
    await renderStill({
      serveUrl, composition, output: path.join(renders, `${scene.id}.png`),
      frame, imageFormat: 'png', scale: 2/3, chromiumOptions
    });
    console.log(`STILL ${scene.id} @${(frame / 30).toFixed(2)}s`);
  }
  console.log(`Todos los stills listos en: ${renders}`);
} else {
  const name = draft ? 'preview-720p.mp4' : 'helado-2d-v2.mp4';
  const partial = path.join(renders, `partial-${name}`);
  let progress = -1;
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
  const final = path.join(renders, name);
  await fs.rename(partial, final);
  if (!draft) {
    await fs.mkdir(path.join(studio, 'output'), {recursive: true});
    await fs.copyFile(final, path.join(studio, 'output', name));
  }
  console.log(`VERIFICADO ${final} (${probe.format.duration}s, video + audio)`);
}
