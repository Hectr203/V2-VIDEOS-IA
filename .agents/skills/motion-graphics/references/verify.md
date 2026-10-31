# Verify by measuring

The whole point of a seekable timeline is that you can interrogate any moment. Use it. Before claiming something is fixed, write six lines that check it and print a number.

All of these assume the page exposes `window.__seek(seconds)` and `window.__duration`, and — for anything time-relative — `window.__times`.

## The harness

```js
const { chromium } = require('playwright');
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1080, height: 1080 } });
const errs = []; p.on('pageerror', e => errs.push(String(e)));
await p.goto('file:///.../video.html');
await p.evaluate(() => document.fonts.ready);
// then: await p.evaluate(t => window.__seek(t), 7.2);
```

Always collect `pageerror`. A thrown exception while building the timeline leaves a half-built animation that still renders something plausible.

## Frame times — is it actually janky?

```js
const dt = await p.evaluate(() => new Promise(res => {
  const out = []; let prev = performance.now(), n = 0;
  document.body.click();                       // restart playback
  const tick = now => { out.push(now - prev); prev = now;
    if (++n < 600) requestAnimationFrame(tick); else res(out); };
  requestAnimationFrame(tick);
}));
```

Report median, p95, and the count over 20ms. Do this **before** touching the design when someone says it feels janky. On a real piece the answer was 8.3ms median and zero dropped frames — the problem was that scenes had no camera and held frozen. Redesigning motion because of an imagined performance problem wastes a lot of time.

## Composition — is it centred?

Find the ink bounding box by scanning pixels, and report the top and bottom margins.

```js
const im = PNG.sync.read(await p.screenshot());
let top = 1e9, bot = -1;
for (let y = 0; y < H; y++) for (let x = 0; x < 1080; x++){
  const k = (y*1080 + x) * 4;
  const dark   = (im.data[k] + im.data[k+1] + im.data[k+2]) / 3 < 170;
  const accent = im.data[k] - im.data[k+2] > 60;      // exclude the accent colour
  if (dark && !accent){ if (y < top) top = y; if (y > bot) bot = y; }
}
```

Under 10px of imbalance in a 1080 frame is fine. 28–41px is what "it feels off" looks like as a number.

## Overflow — does anything leave the frame?

Sample the element's rect across the window where it should stay put, and report the worst excursion past 0 and past the canvas width. Also report the maximum width: a smear that grows to 859px in a 1080 frame is going to clip even if it happens to stay inside on this particular line.

## Continuity — does it jump?

```js
let prev = null, worst = 0, when = 0;
for (let t = t0; t <= t1; t += 1/60){
  const x = await p.evaluate(tt => { window.__seek(tt);
    return document.getElementById('thing').getBoundingClientRect().left; }, t);
  if (prev !== null && Math.abs(x - prev) > worst){ worst = Math.abs(x - prev); when = t; }
  prev = x;
}
```

Compare the worst jump against the expected velocity at that moment. Anything much larger is a bookkeeping bug, not motion.

## Reproducing a reference exactly

If you are porting an existing animation, diff it. Note that a CSS-animated reference is also seekable:

```js
await ref.evaluate(t => {
  const a = document.getAnimations();
  a.forEach(x => x.pause());
  a.forEach(x => x.currentTime = t * 1000);
}, t);
```

Then compare two ways, and let the second one decide:

**Pixels** — count differing pixels with a small per-channel tolerance (8/255 covers antialiasing noise). This is a coarse net that catches anything structural.

**Geometry** — compare `getBoundingClientRect()` element by element at matching instants and report the worst deviation in px. *This is the real claim.* Pixel counts explode from sub-pixel offsets: on one comparison the geometry agreed to 0.38px while the pixel count sat at 0.4%, purely because two animations with different absolute durations resolve their easing curves with slightly different precision and every edge antialiases differently. Judging by pixels alone would have sent you hunting a bug that did not exist.

Two things the geometric check needs:

- **Skip anything invisible.** An element parked off-screen at `opacity: 0` in both files can be thousands of pixels apart and it means nothing. Reading a 2771px "deviation" from an invisible bar is a memorable way to learn this.
- **Compensate deliberate differences.** If the port is optically recentred by 31px or runs at 90% speed, apply that shift and that time scale in the comparison. The claim is "same movement", not "same coordinates".

Expect residual sub-pixel differences from integer rounding: `offsetWidth` returns integers where `getBoundingClientRect()` is fractional, which is worth ~0.2px on its own.

## The trap: suspect the check first

When a check that used to pass suddenly fails, **suspect the check**. In practice the large majority of alarms were the measurement's fault:

| What it looked like | What it was |
| --- | --- |
| The recurring mark flies 1256px off frame | Measurement window written for the old timing; it was sampling the entrance, which is *supposed* to start off-frame |
| Scene 1 has no text at all | Fixed timestamp in the audit script; after a retime it landed after the text had left |
| The URL scene is empty | Same — by that timestamp the mark had already covered the word, which is the intended behaviour |
| The port broke, 4.7% difference | Race in the harness: the reference starts its animations in a `requestAnimationFrame` *after* `fonts.ready`, so `getAnimations()` returned an empty list and the diff compared against a blank frame |

Confirm the failure independently before you "fix" working code. Two habits prevent most of it:

- Derive measurement windows from `window.__times` instead of hard-coding seconds.
- Wait for the thing you are about to measure: `await page.waitForFunction(() => document.getAnimations().length > 5)`.

## Contact sheets

For anything about rhythm, render a strip of frames and look at it as one image:

```js
for (let i = 0; i < n; i++){
  await p.evaluate(t => window.__seek(t), t0 + i * step);
  await p.screenshot({ path: `f${i}.png`, clip: { x, y, width, height } });
}
```

Then tile them with PIL and label each with its timestamp. A 30-frame sheet across the whole piece catches structural problems — overlapping scenes, a beat that never fires, an accent parked in the wrong place — faster than watching it.

Two cautions: crop generously or you will diagnose a problem that is only your crop (a rule "vanishing" because the camera pushed it past the clip edge), and remember `getBoundingClientRect()` on a block element returns the *container* width, scaled by any active camera — measure the tokens if you want the text width.
