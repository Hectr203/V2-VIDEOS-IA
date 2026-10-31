# Asset pipeline — halftone cutouts

The Vox register uses **pre-baked halftone/duotone PNG cutouts**, never runtime
image filters. Baking offline keeps renders deterministic (a hard rule — see
SKILL.md "What NOT to do") and gives you the crisp ink-dot look that a CSS filter
can't. Two scripts in `scripts/` do the work.

## Why pre-bake (not runtime filters)

- **Determinism.** A HyperFrames render seeks and screenshots frame-by-frame; a
  runtime canvas filter can produce slightly different pixels per run. Baked PNGs
  are identical every time.
- **The look.** Real halftone means per-cell luminance → dot radius. That's a
  scan over the image, not a CSS `filter`.
- **Speed.** No per-frame processing during render.

## 1. Generate source objects — `gen_archival_objects.py`

Creates high-contrast B&W objects on a **pure white background** via OpenAI's
`gpt-image-1`. The white background is load-bearing: the next step thresholds on
it to build the cutout mask.

```bash
export OPENAI_API_KEY=sk-...
python scripts/gen_archival_objects.py --out gen
```

Edit the `JOBS` list for your own objects; keep the `STYLE` prompt tail
(`"...isolated on a pure white background, no text..."`) — that's what makes the
cutout clean. Generate several per need; **expect ~1 in 4 to read as an abstract
blob**, so cast the survivors.

> Needs an OpenAI API key and network. If you'd rather bring your own images,
> skip this step — any straight-on photo on a near-white background works as
> input to step 2.

## 2. Bake the halftone cutout — `halftone_objects.py`

Thresholds the white background into an alpha mask, then draws ink dots whose
radius tracks each cell's luminance (darker → bigger dot). Outputs a trimmed,
transparent `obj_<name>_ink.png`.

```bash
pip install pillow
python scripts/halftone_objects.py --in gen --out photos
# or a subset:
python scripts/halftone_objects.py --in gen --out photos --names typewriter rotary-phone
```

Drop the results into your project's `assets/photos/` and reference them from a
composition:

```html
<img class="arch" src="assets/photos/obj_typewriter_ink.png" alt="" />
```

Tuning knobs (top of the script):

| Const | Does |
|---|---|
| `INK` | dot color — matches `--ink` (`#161513`) |
| `SIZE` | output px on the longest side (before trim) |
| `CELL` | halftone cell size; smaller = finer dots |
| `rmax` | max dot radius as a fraction of `CELL` (`CELL * 0.62`) |
| the `238` in `point(lambda v: 0 if v > 238 else 255)` | background threshold — raise if your white is dingy |

## Portrait badges (same idea, circle-masked)

For talking-head badges, run a photo through the same luminance→dot logic with a
circle mask instead of a white-bg threshold, then colorize the ring per the
palette meaning (yellow ring for emphasis, cobalt for the new era). Verify the
crop centers the face **visually** — luminance baking is unforgiving of an
off-center crop.

## Texture = meaning

Reserve the archival halftone substrate for "old world" scenes; keep "new era"
scenes flat vector. The register shift (textured → flat) then reads as the
story's turn, not just decoration (SKILL.md research rule #4).
