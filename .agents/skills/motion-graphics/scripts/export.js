/* ════════════════════════════════════════════════════════════════════════
   EXPORTER — HTML timeline → MP4, one file per aspect ratio
   Works unchanged for any piece that exposes window.__seek(seconds) and
   window.__duration, and that reads its canvas height from ?h=<px>.

     node export.js                 all formats
     node export.js 9x16            just one
     FPS=30 CRF=20 node export.js

   Requires: npm i playwright   ·   ffmpeg on PATH
   ════════════════════════════════════════════════════════════════════════ */

const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const SRC  = process.env.SRC || 'video.html';
const NAME = process.env.NAME || path.basename(SRC, '.html');
const W    = Number(process.env.W || 1080);
const FPS  = Number(process.env.FPS || 60);
const CRF  = Number(process.env.CRF || 17);

const FORMATS = {
  '1x1':  { h: 1080, where: 'LinkedIn, Instagram feed, Facebook, X' },
  '4x5':  { h: 1350, where: 'Instagram and LinkedIn feed — taller on mobile' },
  '9x16': { h: 1920, where: 'Reels, Stories, TikTok, Shorts' },
};

const asked = process.argv.slice(2).filter(a => FORMATS[a]);
const list  = asked.length ? asked : Object.keys(FORMATS);

const run = (cmd, args) => new Promise((res, rej) => {
  const p = spawn(cmd, args, { stdio: ['ignore', 'ignore', 'inherit'] });
  p.on('close', c => c === 0 ? res() : rej(new Error(`${cmd} exited ${c}`)));
});

(async () => {
  const browser = await chromium.launch();

  for (const key of list){
    const F   = FORMATS[key];
    const TMP = path.join(__dirname, `.frames-${key}`);
    const OUT = path.join(__dirname, `${NAME}-${key}.mp4`);
    fs.rmSync(TMP, { recursive: true, force: true });
    fs.mkdirSync(TMP);

    const page = await browser.newPage({
      viewport: { width: W, height: F.h },
      deviceScaleFactor: 1
    });
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));

    await page.goto(`file://${path.resolve(__dirname, SRC)}?h=${F.h}`);
    await page.evaluate(() => document.fonts.ready);
    if (errors.length) throw new Error(`${key}\n${errors.join('\n')}`);

    const dur   = await page.evaluate(() => window.__duration);
    const total = Math.ceil(dur * FPS);
    console.log(`\n${key}  ${W}×${F.h}  ·  ${dur.toFixed(2)}s  ·  ${total} frames  ·  ${F.where}`);

    for (let i = 0; i < total; i++){
      await page.evaluate(t => window.__seek(t), i / FPS);
      await page.screenshot({ path: path.join(TMP, `f${String(i).padStart(5, '0')}.png`) });
      /* Never pass animations:'disabled' here. In Playwright that does not
         freeze anything — it fast-forwards every animation to its end state,
         and all N frames come out identical. The timeline is already paused. */
      if (i % 120 === 0) process.stdout.write(`\r  ${i}/${total}`);
    }
    process.stdout.write(`\r  ${total}/${total}  encoding…\n`);
    if (errors.length) console.warn('  page warnings:', errors);
    await page.close();

    await run('ffmpeg', [
      '-y',
      '-framerate', String(FPS), '-i', path.join(TMP, 'f%05d.png'),
      // Silent audio track: some platforms reject video-only uploads outright.
      '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
      '-shortest',
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',        // without this, platforms and QuickTime refuse to decode
      '-crf', String(CRF), '-preset', 'slow',
      '-c:a', 'aac', '-b:a', '96k',
      '-movflags', '+faststart',    // without this, playback waits for the full download
      OUT
    ]);

    fs.rmSync(TMP, { recursive: true, force: true });
    console.log(`  ${path.basename(OUT)} — ${(fs.statSync(OUT).size / 1048576).toFixed(1)} MB`);
  }

  await browser.close();
})().catch(e => { console.error(e.message); process.exit(1); });
