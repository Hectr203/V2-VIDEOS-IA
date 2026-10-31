# Vox-style motion vocabulary

The full recipes for every move, plus the tuned default settings to start from.
These values are the arrival state after many drafts — **start here; don't
re-derive them.** All examples assume a GSAP `paused` timeline `tl` and a scoped
selector helper `const sel = (q) => `[data-composition-id="<id>"] ${q}``.

## Tuned defaults (start every scene from these)

| Situation | Setting |
|---|---|
| Text / label entrance | 0.55–0.75s, `expo.out` or `power3.out`, `y: 36–50 → 0` |
| Card / box slap-in | 0.5–0.6s, `back.out(1.15)` max (never 1.5+), settle ±0.4–0.8° crooked |
| Big image / cutout arrival | 0.7s `power3.out`, then blend DIRECTLY into its drift (the drift tween starts exactly where the entrance ends — same-property tweens never overlap) |
| Hero lockup (1–2 per piece) | add `filter: blur(14px) → blur(0px)` to the entrance |
| Ambient drift (dots, scale-breathe, rings, scraps) | smooth `ease: 'none'` — EXCEPT background dot fields |
| Background dot-field pan | `ease: 'steps(' + Math.round(SLOT * 12) + ')'` — the 12fps "Vox stutter" lives ONLY here |
| Hand-drawn pen strokes | `stroke-dashoffset` draw with `steps(6–7)` — steppiness IS pen physics |
| Highlighter swipe | `scaleX 0→1` from left, 0.45s `power2.out` |
| Scene seam | split sheet-wipe: outgoing sheet starts at `SLOT − 0.2`; incoming cover exits `power2.in` 0.4s |

## The moves

### Paper slap-in
The signature entrance. Element arrives oversized and slightly rotated, settles
flat (or a hair crooked). Hero lockups add a blur-in.

```js
tl.fromTo(sel('.hero'),
  { scale: 1.18, opacity: 0, rotation: -1.2, filter: 'blur(14px)' },
  { scale: 1, opacity: 1, rotation: 0, filter: 'blur(0px)', duration: 0.55, ease: 'power3.out' }, START);
```
Cards settle crooked instead of flat: end at `rotation: 0.6` (not 0). The hard
offset shadow can "land" one frame after the card for extra print weight.

### Highlighter swipe
The one emphasis device. A **real** yellow element behind the key word (never a
`::before` — GSAP can't tween pseudo-elements), wiped in from the left.

```html
<span class="hl">BIG<span class="hl-block"></span></span>
```
```js
tl.to(sel('.hl-block'), { scaleX: 1, duration: 0.45, ease: 'power2.out' }, START);
```
`.hl-block` starts `transform: scaleX(0); transform-origin: left center;`. Use it
on exactly ONE word per scene. Never color-change the text.

### Strike-through (negation)
Red bar sweeps through a word/box at a slight tilt. The strike carries ALL
negation — never print the word "NOT"/"NO" next to it.

```js
tl.to(sel('.strike'), { scaleX: 1, duration: 0.55, ease: 'power3.out' }, START);
```
`.strike` starts `transform: rotate(-2.5deg) scaleX(0); transform-origin: left;`.

### Sheet-wipe (the cut)
The **only** transition device. A full-width paper sheet sweeps across the frame
to cover a cut, then the next scene slaps in underneath. Same device every time.

```js
// outgoing scene, near its slot end:
tl.to(sel('.sheet-wipe'), { x: '230%', duration: 0.4, ease: 'power3.in' }, SLOT - 0.2);
```
The sheet starts off-frame left (`translateX(-115%)`), has ink borders on both
edges, and sits at a high `z-index`. The incoming scene's `data-start` lands
mid-sweep so the seam is covered on both sides.

### Node bloom (new era)
Cobalt nodes pop in and connect. Pair the bloom with a drawn connector line.

```js
tl.fromTo(sel('.node'), { scale: 0 }, { scale: 1, duration: 0.5, ease: 'back.out(1.6)' }, START);
tl.fromTo(sel('.wire'), { strokeDashoffset: LEN }, { strokeDashoffset: 0, duration: 0.5, ease: 'power2.inOut' }, START + 0.1);
```
Set the SVG path's `stroke-dasharray` to its length so `strokeDashoffset`
animates a draw-on.

### Count-up ticker
Numbers count via a proxy object writing `textContent`, frame-snapped so the
render is deterministic.

```js
const o = { v: 0 };
tl.to(o, { v: 240, duration: 1.2, ease: 'none',
  onUpdate: () => { el.textContent = Math.round(o.v); } }, START);
```

### Word-by-word reveal (VO-locked)
Each word is a `.w` span; reveal it at the VO onset for that word.

```js
tl.fromTo(sel('.w'), { y: 24, opacity: 0 },
  { y: 0, opacity: 1, duration: 0.6, ease: 'expo.out', stagger: 0.08 }, START);
```
When you have real VO, replace the stagger with per-word `START` values taken
from Whisper word onsets (`examples/how-it-works/` shows the full pattern).

### Camera-never-sleeps drift
Every scene has slow ambient motion so nothing feels frozen.

```js
tl.fromTo(sel('.type-stage'), { scale: 1.0 }, { scale: 1.03, duration: SLOT, ease: 'none' }, 0);
tl.to(sel('.dots-tl'), { backgroundPosition: '18px 18px', duration: SLOT,
  ease: 'steps(' + Math.round(SLOT * 12) + ')' }, 0);   // stutter lives HERE only
```

## The slot anchor (required on every timeline)

End every composition's timeline with a zero-effect tween that holds the slot
open for its full duration, even after motion settles:

```js
tl.to({}, { duration: SLOT }, 0);
window.__timelines['<id>'] = tl;
```
Without it, a composition can collapse to the length of its last real tween.
