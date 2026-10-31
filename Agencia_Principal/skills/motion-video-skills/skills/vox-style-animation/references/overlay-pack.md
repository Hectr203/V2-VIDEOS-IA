# Vox-style alpha overlays

Transparent kinetic-type overlays — lower-third "cards" and kinetic-emphasis "pops" — that
composite **over existing footage** (a talking-head cut, screen-rec, or b-roll) in an NLE.
This is a companion pattern to the full HyperFrames scene starter. Read the main `SKILL.md`
first; this doc only covers what's different about building **alpha** parts.

Palette vocabulary used throughout: paper cream `#f2ecdf`, ink `#161513`, vox-yellow
`#ffd200`, signal-red `#e5483f`, cobalt `#2f5fe8`.

---

## 1. What an alpha overlay is (and when to use it)

An alpha overlay is a HyperFrames composition rendered with a **transparent background** so
only the graphic pixels are opaque. You drop the rendered file onto a track **above** your
locked cut in Resolve / Premiere and it composites straight over the picture — no green
screen, no keying.

Use an alpha overlay when:
- The footage is the hero and the motion graphic is annotation (lower-thirds, callouts,
  emphasis words punched over a face).
- You've already locked the edit and just want a graphics pass on top.
- You want each graphic to be an independent, re-timeable clip in the NLE.

Use a **full HyperFrames scene** instead when the graphic *is* the frame — a cold-open, a
title card on a paper background, a data scene with no underlying footage. The tell: a full
scene paints a background (`background: #f2ecdf`); an overlay never does.

---

## 2. Rendering with transparency

The stock HyperFrames CLI produces alpha when you ask for a codec that carries an alpha
channel. Three options:

```bash
# WebM (VP9 + alpha) — smallest
npx hyperframes render <project> --format webm -o renders/card-01.webm

# MOV — request a codec with alpha (ProRes 4444 / 4444-XQ carry yuva)
npx hyperframes render <project> --format mov -o renders/card-01.mov

# PNG sequence — lossless alpha, import as an image sequence in the NLE
npx hyperframes render <project> --format png-sequence -o renders/card-01/
```

For Resolve, transcode WebM to ProRes 4444 so the alpha survives:

```bash
ffmpeg -y -c:v libvpx-vp9 -i card-01.webm \
  -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le card-01-prores.mov
```

`yuva444p10le` is the alpha-carrying pixel format — the `a` is the alpha plane. If you export
a flat MP4 (`yuv420p`) you lose transparency and get a black box.

---

## 3. The two building blocks

### A. Lower-third "card"

A cream card that slides up from the bottom-left: ink border + hard offset shadow, a red
kicker, a yellow band that swipes in behind the headline, and the headline itself revealed
**per character** in Archivo Black.

```html
<div class="card">
  <div class="kicker">SECTION LABEL</div>
  <div class="headline">
    <span class="band"></span>
    <span class="hl"><span class="ch">H</span><span class="ch">e</span>…</span>
  </div>
</div>
```

Key styling — note there is **no background on the root**, only on `.card`:

```css
[data-composition-id="card-01"] { position:absolute; inset:0; overflow:hidden; background:transparent; }
[data-composition-id="card-01"] .card {
  position:absolute; left:90px; bottom:90px; max-width:1100px;
  background:#f2ecdf; border:6px solid #161513;
  box-shadow:12px 14px 0 rgba(22,21,19,0.28);   /* hard, offset — no blur */
  padding:26px 44px 30px; opacity:0;
}
[data-composition-id="card-01"] .kicker { color:#e5483f; letter-spacing:0.2em; }  /* signal-red */
[data-composition-id="card-01"] .band  {                                          /* vox-yellow swipe */
  position:absolute; z-index:0; inset:8% -0.12em -2% -0.12em;
  background:#ffd200; transform:scaleX(0); transform-origin:left center;
}
[data-composition-id="card-01"] .ch { display:inline-block; opacity:0; }
```

The motion recipe (anime.js, ms offsets):

```js
tl.add(S('.card'), { translateY:[150,0], opacity:[0,1], duration:450, ease:'out(3)' }, 0);
tl.add(S('.band'), { scaleX:[0,1],                     duration:420, ease:'out(3)' }, 420);
tl.add(S('.ch'),   { opacity:[0,1], translateY:[14,0], duration:300, ease:'out(2)',
                     delay: anime.stagger(14) }, 300);          // per-char reveal, 14ms apart
tl.add(S('.card'), { translateY:[0,160], opacity:[1,0], duration:400, ease:'in(2)' }, ms_out);
```

Beat order: **card slides in → yellow band swipes → characters cascade → card drops out.**
`ms_out` is `(duration − 0.45) * 1000` so the exit lands just before the clip ends.

### B. Kinetic "emph" pop

A short (~1.9s) burst of yellow-boxed words, tilted a couple degrees, that scale + pop up in
a stagger. Use it to punch a phrase over the talent's shoulder.

```html
<div class="pop">
  <span class="wd">NONE</span> <span class="wd">OF</span> <span class="wd">THIS</span> …
</div>
```

```css
[data-composition-id="emph-0071"] { position:absolute; inset:0; overflow:hidden; background:transparent; }
[data-composition-id="emph-0071"] .pop {
  position:absolute; left:100px; top:110px; transform:rotate(-2deg); transform-origin:left top;
  font-family:'Archivo Black',sans-serif; font-size:52px; color:#161513;
}
[data-composition-id="emph-0071"] .wd {
  display:inline-block; opacity:0;
  background:#ffd200; border:5px solid #161513;
  box-shadow:8px 9px 0 rgba(22,21,19,0.28); padding:2px 16px 4px;
}
```

```js
tl.add(S('.wd'), { opacity:[0,1], scale:[0.4,1], translateY:[18,0],
                   duration:300, ease:'out(4)', delay:anime.stagger(70) }, 60);   // pop in
tl.add(S('.wd'), { opacity:[1,0], scale:[1,0.85],
                   duration:260, ease:'in(2)', delay:anime.stagger(30) }, ms_out); // pop out
```

A generator can emit both blocks from a cue list where each cue is
`{ id, type: "card"|"emph", kicker?, text, dur_s }`: wrap each letter in `<span class="ch">`
for cards, each word in `<span class="wd">` for pops.

---

## 4. The anime.js + GSAP proxy-timeline `driver` (seek-safe playback)

The motion is authored in **anime.js v4** (nicer stagger API), but the HyperFrames renderer
seeks a **GSAP** timeline once per frame and screenshots. anime.js speaks milliseconds with a
`duration` + `seek(ms)`; GSAP speaks seconds. The renderer drives timelines through its GSAP
proxy and ignores plain duck-typed `seek()` facades, so what you register on
`window.__timelines[id]` must be a *real* GSAP timeline.

The bridge: a real GSAP tween animates a scalar `t` on a `driver` object from `0` to `DUR`
(seconds), and that property's **setter** seeks the anime timeline. Property application
survives a `seek()` scrub (unlike `onUpdate` callbacks, which can be skipped when the renderer
jumps frames), so it's frame-accurate.

```js
const tl = anime.createTimeline({ autoplay: false });   // author motion here
const DUR = 4.0;
const S = (q) => `[data-composition-id="card-01"] ${q}`;

const _reg = () => {
  const driver = { _t: 0 };
  Object.defineProperty(driver, 't', {
    get() { return this._t; },
    set(v) { this._t = v; tl.seek(Math.max(0, Math.min(v, DUR)) * 1000); }, // sec → ms
  });
  const gtl = gsap.timeline({ paused: true });
  gtl.to(driver, { t: DUR, duration: DUR, ease: 'none' }, 0);  // real GSAP tween
  window.__timelines = window.__timelines || {};
  window.__timelines['card-01'] = gtl;   // renderer finds THIS
};
// … tl.add(...) beats …
_reg();
```

The renderer reads `gtl.duration()` once for the frame count, then calls `gtl.seek(t)` per
frame; each seek advances `driver.t`, whose setter scrubs the anime timeline to the matching
ms. `ease:'none'` on the GSAP tween keeps the mapping linear — all easing lives inside the
anime beats.

---

## 5. Transparent-background requirements

This is the one rule that separates an overlay from a full scene:

- The root `[data-composition-id]` and `.stage` must be `background: transparent`. **Never**
  fill the body or stage with paper cream — that cream is the *card's* fill, not the frame's.
- Only interior elements (`.card`, `.wd`, `.band`) carry color.
- Keep `overflow: hidden` on the root so a card sliding in from off-screen doesn't spill.
- The full-scene starter does the opposite: it paints `background: #f2ecdf` so the whole
  frame is opaque paper. If you copy a starter and forget to strip that fill, your "overlay"
  renders as an opaque cream rectangle that hides the footage underneath.

Sanity check before rendering: search the composition for `background:` — every hit should be
on an inner element, never on the root or `body`.

---

## 6. Placing & timing over a cut

Each composition renders to its **own** alpha clip (`card-01.webm`, `emph-0071.webm`, …) with
its own short duration (cards ~4s, pops ~1.9s). To render them one at a time, mount a single
comp under a root anchored to that comp's duration (`tl.to({}, { duration: dur })` — the child
carries the motion), render it, then restore the full index.

In the NLE:

1. Put each rendered ProRes/WebM clip on a video track **above** the master cut.
2. Slide each clip so **frame 0 lands on the word it annotates**. The built-in slide-in / hold
   / drop-out means you place the clip's start, not keyframes.
3. Cards live bottom-left (`left:90px; bottom:90px`); pops live upper-left
   (`left:100px; top:110px`) — pre-positioned to sit clear of a centered talking head. Nudge
   per shot if the subject drifts.
4. Overlap freely: a pop and a card can share screen time on different tracks; each is
   self-contained, so ordering in the NLE is just stacking, not compositing math.

Because every part is an independent alpha clip, re-timing the cut never means re-rendering
graphics — you just slide the overlays to match.
