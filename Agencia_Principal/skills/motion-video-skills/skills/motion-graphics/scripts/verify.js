/* ════════════════════════════════════════════════════════════════════════
   VERIFY — measurements, not opinions
   Works on any piece exposing window.__seek / window.__duration, and ideally
   window.__times so measurement windows survive a retime.

     node verify.js                    everything
     node verify.js centering overflow just those
     SRC=hero.html node verify.js

   Requires: npm i playwright pngjs
   ════════════════════════════════════════════════════════════════════════ */

const { chromium } = require('playwright');
const { PNG } = require('pngjs');
const path = require('path');

const SRC = 'file://' + path.resolve(__dirname, process.env.SRC || 'video.html');
const W   = Number(process.env.W || 1080);
const H   = Number(process.env.H || 1080);

async function open(browser){
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  await page.goto(SRC);
  await page.evaluate(() => document.fonts.ready);
  /* A thrown exception while building the timeline leaves a half-built
     animation that still renders something plausible. Always surface it. */
  return { page, errors };
}

/* ── Is it actually janky? ────────────────────────────────────────────────
   Do this BEFORE touching the design when someone says it stutters. It is
   frequently not performance: a frame that holds motionless for two seconds
   reads as stuck at a flawless 60fps. */
async function fluidity(page){
  const dt = await page.evaluate(() => new Promise(res => {
    const out = []; let prev = performance.now(), n = 0;
    document.body.click();
    const tick = now => { out.push(now - prev); prev = now;
      if (++n < 600) requestAnimationFrame(tick); else res(out); };
    requestAnimationFrame(tick);
  }));
  const sorted = [...dt].sort((a, b) => a - b);
  const q = f => sorted[Math.floor(sorted.length * f)];
  const dropped = dt.filter(d => d > 20).length;
  console.log(`fluidity   median ${q(.5).toFixed(1)}ms · p95 ${q(.95).toFixed(1)}ms · `
            + `dropped ${dropped}/${dt.length}`);
  return { median: q(.5), p95: q(.95), dropped };
}

/* ── Is the composition centred? ──────────────────────────────────────────
   Scans the ink, not the boxes. Under 10px of imbalance in a 1080 frame is
   fine; 30–40px is what "it feels off" looks like as a number.
   `accent` is [r,g,b] of a colour to exclude, if a coloured mark would
   otherwise drag the measurement around. */
async function centering(page, times, accent){
  /* The background is sampled from a corner rather than assumed. Hardcoding
     "ink is dark" makes this function measure the whole background on a dark
     piece and report 0px off centre every time — a check that always passes is
     worse than one that fails, and this file is about not trusting checks. */
  await page.evaluate(x => window.__seek(x), times[0] ?? 0);
  const probe = PNG.sync.read(await page.screenshot());
  const bgLum = (probe.data[0] + probe.data[1] + probe.data[2]) / 3;
  const darkOnLight = bgLum > 128;
  console.log(`centering  (ink only, ${darkOnLight ? 'dark ink on light ground' : 'light ink on dark ground'})`);
  const out = [];
  for (const t of times){
    await page.evaluate(x => window.__seek(x), t);
    const im = PNG.sync.read(await page.screenshot());
    let top = 1e9, bot = -1;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++){
      const k = (y*W + x) * 4, r = im.data[k], g = im.data[k+1], b = im.data[k+2];
      const lum = (r + g + b) / 3;
      if (darkOnLight ? lum >= bgLum - 60 : lum <= bgLum + 60) continue;
      if (accent && Math.abs(r-accent[0]) < 60 && Math.abs(g-accent[1]) < 60 && Math.abs(b-accent[2]) < 60) continue;
      if (y < top) top = y;
      if (y > bot) bot = y;
    }
    const off = bot < 0 ? null : Math.round((top + bot) / 2 - H / 2);
    out.push({ t, off });
    console.log(off === null
      ? `           ${t.toFixed(2)}s   no ink — check the timestamp, not the piece`
      : `           ${t.toFixed(2)}s   ${off > 0 ? '+' : ''}${off}px off centre`);
  }
  return out;
}

/* ── Does anything leave the frame? ───────────────────────────────────────
   Give a window where the element is supposed to stay put. Sampling across an
   entrance or exit will report a huge overflow, correctly — things are meant
   to come from off-frame. That mistake is the single most common false alarm
   in this file's history. */
async function overflow(page, selector, t0, t1){
  let left = 0, right = 0, maxW = 0;
  for (let t = t0; t <= t1; t += 1/60){
    const r = await page.evaluate(([tt, sel]) => { window.__seek(tt);
      const b = document.querySelector(sel).getBoundingClientRect();
      return [b.left, b.right, b.width]; }, [t, selector]);
    left  = Math.max(left, -r[0]);
    right = Math.max(right, r[1] - W);
    maxW  = Math.max(maxW, r[2]);
  }
  console.log(`overflow   ${selector}   left ${left.toFixed(0)}px · right ${right.toFixed(0)}px · `
            + `widest ${maxW.toFixed(0)} of ${W}`);
  return { left, right, maxW };
}

/* ── Does it jump? ────────────────────────────────────────────────────────
   Compare the worst per-frame delta against the expected velocity at that
   moment. Motion is smooth; a discontinuity is a bookkeeping bug. */
async function continuity(page, selector, t0, t1){
  let prev = null, worst = 0, when = 0;
  for (let t = t0; t <= t1; t += 1/60){
    const x = await page.evaluate(([tt, sel]) => { window.__seek(tt);
      return document.querySelector(sel).getBoundingClientRect().left; }, [t, selector]);
    if (prev !== null && Math.abs(x - prev) > worst){ worst = Math.abs(x - prev); when = t; }
    prev = x;
  }
  console.log(`continuity ${selector}   worst step ${worst.toFixed(1)}px at ${when.toFixed(2)}s`
            + `   (${(worst*60).toFixed(0)} px/s — is that the intended speed?)`);
  return { worst, when };
}

/* ── Does the port match its reference? ───────────────────────────────────
   Two measurements, and the second one decides. Pixel counts explode from
   sub-pixel offsets — two animations of different absolute duration resolve
   their easing with slightly different precision and every edge antialiases
   differently. Geometry is the real claim.

   opts.dy    vertical offset the port applies deliberately (recentring)
   opts.scale time scale of the port (0.9 = port runs 10% faster)
   Both are compensated so the claim stays "same movement", not "same
   coordinates". */
async function against(browser, refPath, times, sel, opts = {}){
  const dy = opts.dy ?? 0, scale = opts.scale ?? 1;
  const ref = await browser.newPage({ viewport: { width: W, height: H } });
  await ref.goto('file://' + path.resolve(__dirname, refPath));
  await ref.evaluate(() => document.fonts.ready);
  /* Wait for the reference's animations to exist. A CSS-animated page often
     starts them in a requestAnimationFrame AFTER fonts.ready; without this the
     diff silently compares against a blank frame. */
  await ref.waitForFunction(() => document.getAnimations().length > 2, null, { timeout: 5000 });

  const vid = (await open(browser)).page;
  let worst = 0, where = '';
  for (const t of times){
    const A = await ref.evaluate(([tt, s]) => {
      const an = document.getAnimations(); an.forEach(x => x.pause());
      an.forEach(x => x.currentTime = tt * 1000);
      return [...document.querySelectorAll(s)].map(e => { const b = e.getBoundingClientRect();
        return [b.left, b.top, b.width, +getComputedStyle(e).opacity]; });
    }, [t, sel.ref]);
    const B = await vid.evaluate(([tt, s, k]) => {
      window.__seek(tt * k);
      return [...document.querySelectorAll(s)].map(e => { const b = e.getBoundingClientRect();
        return [b.left, b.top, b.width, +getComputedStyle(e).opacity]; });
    }, [t, sel.port, scale]);

    A.forEach((q, i) => {
      if (!B[i]) return;
      // Invisible things can be thousands of px apart and it means nothing.
      if (q[3] < .02 || B[i][3] < .02) return;
      const d = Math.max(Math.abs(B[i][0]-q[0]), Math.abs((B[i][1]-dy)-q[1]), Math.abs(B[i][2]-q[2]));
      if (d > worst){ worst = d; where = `${t.toFixed(2)}s, element ${i}`; }
    });
  }
  await ref.close(); await vid.close();
  console.log(`geometry   worst deviation ${worst.toFixed(2)}px (${where})`);
  return { worst, where };
}

/* ── Did the export actually capture motion? ──────────────────────────────
   The skill warns three times about Playwright's animations:'disabled' turning
   every frame into the end state. This is that warning as a check: sample a few
   instants and confirm the pixels differ. Cheap, and it catches the one bug that
   produces a perfectly valid MP4 of a still image. */
async function distinctFrames(page, dur, n = 5){
  const seen = new Set();
  for (let i = 0; i < n; i++){
    await page.evaluate(t => window.__seek(t), dur * (i + .5) / n);
    const buf = await page.screenshot();
    seen.add(require('crypto').createHash('md5').update(buf).digest('hex'));
  }
  const ok = seen.size === n;
  console.log(`frames     ${seen.size}/${n} distinct` + (ok ? '' : '  ← the timeline is not moving, or the capture is frozen'));
  return { distinct: seen.size, of: n, ok };
}

module.exports = { open, fluidity, centering, overflow, continuity, against, distinctFrames };

/* ── Standalone run ───────────────────────────────────────────────────────
   Edit the windows below for the piece at hand. Prefer deriving them from
   window.__times: hard-coded seconds go stale the first time you retime
   anything, and then report failures that are not there. */
if (require.main === module) (async () => {
  const browser = await chromium.launch();
  const { page, errors } = await open(browser);
  const T = await page.evaluate(() => window.__times || {});
  const dur = await page.evaluate(() => window.__duration);
  console.log(`${path.basename(SRC)}  ${W}×${H}  ${dur.toFixed(2)}s`);
  console.log('errors     ' + (errors.length ? errors.join(' | ') : 'none'));

  const want = process.argv.slice(2);
  const run = n => !want.length || want.includes(n);

  /* Sampling times. Publish scene MIDPOINTS in window.__times, not starts —
     a start lands on a half-built entrance and measures nothing useful. If a
     piece only publishes starts, this samples between consecutive ones.
     Filtering an arbitrary object by "is a number in range" also swallows
     geometry constants and measures them as timestamps, so only keys whose
     name looks temporal are considered. */
  const stamps = Object.entries(T)
    .filter(([k, v]) => typeof v === 'number' && /^(t|s\d|scene|placa|shot|end|out|in)/i.test(k))
    .map(([, v]) => v).filter(v => v > 0 && v < dur).sort((a, b) => a - b);
  const mids = stamps.length > 1
    ? stamps.slice(0, -1).map((v, i) => (v + stamps[i+1]) / 2)
    : [dur * .5];

  if (run('centering')) await centering(page, mids.slice(0, 6));
  if (run('fluidity'))  await fluidity(page);
  if (run('frames'))    await distinctFrames(page, dur);

  await browser.close();
})().catch(e => { console.error(e.message); process.exit(1); });
