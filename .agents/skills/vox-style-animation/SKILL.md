---
name: vox-style-animation
description: >
  Use when the user wants a Vox-style / editorial motion-graphics look — the
  "printed, not lit" register: cream-paper canvas, halftone dots, heavy ink
  type, a single yellow highlighter marker, kinetic captions, hand-drawn
  annotations, and paper slap-ins. Trigger on "Vox style", "Vox-style
  explainer", "editorial motion graphics", "editorial collage animation",
  "kinetic typography explainer", "halftone / paper / newsprint animation",
  "highlighter / marker text animation", "animated map or data reveal in the
  Vox look", or "make it look like a Vox video". Also use when someone wants to
  CAPTURE a style they saw somewhere into their own reusable pack — see
  references/capture-your-own-style.md. Builds on HyperFrames (renders video
  from HTML); install heygen-com/hyperframes first.
metadata: { "tags": "video, animation, motion-graphics, vox, editorial, hyperframes, style-pack, gsap" }
---

# Vox-Style Animation

A style pack for the **Vox editorial-collage** motion-graphics look, built on
[HyperFrames](https://github.com/heygen-com/hyperframes) (which renders video
from HTML). This skill gives you the palette, type system, motion vocabulary,
texture system, and hard-won process laws to reproduce the look — plus, in
`references/capture-your-own-style.md`, the **method for turning any style you
see into a pack of your own**.

> **Two promises.** (1) Here's the whole Vox look, ready to build with. (2)
> Here's how to do this yourself with *any* aesthetic — the capture method is
> the transferable skill, and it's the reason this repo exists.

## Prerequisites

This is a **HyperFrames** style pack, not a standalone renderer. Install
HyperFrames first, then this pack:

```bash
npx skills add heygen-com/hyperframes          # the framework + its skills
npx skills add <owner>/vox-style-animation      # this style pack
```

Render anything with `npx hyperframes render <project-dir>`. A ready-to-render
example lives in `assets/starter/` — copy it and change the copy.

## The register: "printed, not lit"

Most motion graphics are *lit* — glowing type, chrome gradients, halos on a
black void. Vox is **printed** — ink on cream paper, depth from hard offset
shadows and cut-out edges, texture from halftone dots and paper grain. Nothing
glows. Everything reads like a motion-collage assembled from printed material.

Name your register in one sentence before you build. Everything below serves
that sentence.

## Palette — 5 hues, each owns ONE meaning

Defined in `assets/brand-tokens.css`. The discipline (one job per color) is what
makes it read intentional instead of decorative.

| Color | Hex | Meaning | Where |
|---|---|---|---|
| Paper cream | `#f2ecdf` | The canvas / the page | Background of every scene |
| Ink black | `#161513` | Structure / the narrator's voice | Type, outlines, strokes |
| Vox yellow | `#ffd200` | Emphasis / the highlighter | The ONE key word per scene |
| Signal red | `#e5483f` | The old world / cost / friction / negation | Struck boxes, the collapse |
| Cobalt | `#2f5fe8` | The new capability / what replaces the old | New-era nodes, flow lines |

**Discipline check:** red and cobalt never share a beat — except the single
"turn" scene where old collides with new (that collision *is* the story).

## Type

- **Headline / kinetic:** Archivo Black — flat ink, no gradient, no glow. Scale
  and slam; don't shimmer. `line-height: 0.98`, uppercase.
- **Editorial caption / labels:** Inter 500/700.
- **Margin annotation:** Caveat for hand-note scribbles — sparingly (≤2 per piece).
- **Emphasis device:** a **yellow highlighter swipe** behind the word (a real
  `.hl-block` element, scaleX 0→1 from the left, 0.45s `power2.out`) or a **red
  strike-through**. Never color-change the text itself — the marker is the device.

## Texture & depth (the unifying system)

- **Paper grain** on every scene — pure-CSS 3-layer radial-gradient, no PNG.
- **Halftone dot fields** as section texture (CSS `radial-gradient` dot tiles at
  2 sizes). This replaces grids/crosshairs as the unifying texture.
- **Photos are pre-baked** halftone/duotone PNG cutouts — no runtime filters
  (see `references/asset-pipeline.md`).
- **Hard offset shadows:** `box-shadow: 10px 12px 0 rgba(22,21,19,.16)` — print
  depth, never a blur glow.
- **Camera never sleeps:** slow 2–3% scale drift on collage groups, paper
  elements rotate ±0.5°, dot fields pan.

## Motion vocabulary

The core moves (full recipes + the tuned defaults table in
`references/motion-vocabulary.md`):

| Move | One-line recipe |
|---|---|
| Paper slap-in | `scale 1.15→1`, `rotation ±2→settle ±0.4–0.8° crooked`, 0.5s `back.out(1.15)`, blur-in on hero |
| Highlighter swipe | yellow `.hl-block` behind the key word, `scaleX 0→1` from left, 0.45s `power2.out` |
| Strike-through | red bar `scaleX 0→1` through a word at −2.5° tilt, 0.55s `power3.out` |
| Sheet-wipe (the cut) | full-width paper sheet sweeps across at ~0.4s `power3.in` — the ONLY transition device |
| Node bloom | `scale 0→1 back.out(1.6)` + cobalt connector drawn via `stroke-dashoffset` |
| Count-up ticker | proxy-object tween writing `textContent`, `ease: none`, frame-snapped |
| Word-by-word reveal | words keyed to VO onsets, `y: 24, opacity 0`, 0.55–0.75s `expo.out` |

**Critical detail:** the highlighter and any pseudo-visual must be a **real DOM
element**, not a CSS `::before` — GSAP cannot tween pseudo-elements.

## Structure rules

- Build as sub-compositions `compositions/s1…sN.html`, each a self-contained
  `<template>` with its own scoped `<style>` and a paused GSAP timeline
  registered to `window.__timelines['<id>']`.
- Chain them from `index.html` with `data-composition-src` + `data-start` /
  `data-duration` (see `assets/starter/`).
- **Every timeline ends with a slot anchor:** `tl.to({}, { duration: SLOT }, 0)`
  — holds the composition open for its full slot even after motion settles.
- **One anchor metaphor** per piece, milked via callbacks (a badge recurs, boxes
  fold, nodes return).
- **Hold the outro** 4–6s: thesis line + quiet drift.

## Research-backed rules

Sourced from Vox's own motion team and explainer-motion literature (Estelle
Caswell / Vox, Joey Sendaydiego / Storybench, PremiumBeat, No Film School):

1. **12fps stutter on dot fields ONLY.** Apply `ease: "steps(duration × 12)"` to
   background dot-field pans and hand-drawn pen strokes — and nowhere else.
   Applied to hero type or big-image drift it reads robotic. Everything else
   uses smooth 0.5–0.75s soft-landing eases (`power3`/`expo.out`, `back.out ≤1.3`).
2. **Annotate the evidence.** At least one beat marks up real material with a
   red pen (a rough circle around a number, drawn steppy) — ON exhibits, not
   only on your own headlines.
3. **Editorial imperfection.** Cards settle at ±0.4–0.8° off-axis, never
   perfectly straight — over-polish reads as an advertisement, not editorial.
4. **Texture is a meaning carrier.** Archival halftone substrate on "old world"
   scenes; flat vector on "new" scenes, so a register shift reads as the story's
   turn.
5. **Motion explains, never decorates.** Every move carries meaning; the
   sheet-wipe is the only pure transition, and it's the same device every time.

## Process laws (each bought with a failed draft)

1. **Copy a working sibling's wiring** — never author composition structure from
   memory. Start from `assets/starter/`.
2. **Frame-verify every seam on BOTH sides of the cut** — renders don't error on
   blank paper; extract frames and look.
3. **Ease choice is a separate failure mode from structure** — a correct wipe
   with the wrong ease still flashes.
4. **VO-first, always** — the timeline is audio-locked. Build against provisional
   word-count timings, then re-time every boundary to the real VO's Whisper
   onsets. (See the worked example in `examples/how-it-works/`.)
5. **Same-property tweens must never overlap** — an entrance that ends where its
   drift begins, never both animating `y` at once (velocity stall).
6. **Gate renders on your patch scripts' exit codes** — `str.replace` no-ops
   silently; assert target-exists AND post-count.

## What NOT to do

- No chrome gradients, halo glows, or perspective grids — wrong register.
- No dark-mode scenes; the paper never goes black (a collapse darkens via red).
- No invented on-screen statistics — every number must exist in the narration.
- No runtime image processing or randomness; halftone is pre-baked, jitter uses
  deterministic hashes (renders must be reproducible).

## References

- **`references/capture-your-own-style.md`** — ⭐ the 7-step method to turn *any*
  style you see into your own pack. The headline promise of this repo.
- `references/motion-vocabulary.md` — every move's full recipe + the tuned
  defaults table.
- `references/asset-pipeline.md` — generating halftone/archival cutouts (the
  `scripts/`), and where runtime filters are banned.
- `references/overlay-pack.md` — transparent alpha overlays (lower-thirds,
  kinetic emphasis pops) to composite over existing footage in an NLE.

## Files

- `assets/brand-tokens.css` — the palette + reusable classes (`.card`, `.hl`,
  `.strike`, `.dot-field`, `.sheet-wipe`, `.node`, `.badge`).
- `assets/starter/` — a minimal, self-contained, **renderable** project. Copy it
  to start. `npx hyperframes render assets/starter -o out.mp4`.
- `scripts/` — `gen_archival_objects.py`, `halftone_objects.py` (asset pipeline).
- `../../examples/how-it-works/` — a full VO-locked worked example (this repo's
  own explainer, built with this pack).
