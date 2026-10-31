# Capture your own style

**You don't need my Vox pack — you need the method.** This repo is one worked
example of a repeatable move: see a look you love, capture its *rules*, and turn
it into a pack an AI (or you) can build from on demand. Do this once and you stop
copying references shot-by-shot; you own the whole aesthetic.

Below is the 7-step method, with the Vox build as the running example. The output
is a `SKILL.md` shaped like this repo's — so an agent reads it and builds in your
style without you re-explaining it every time.

---

## 1. Pick a reference and name its register — in ONE sentence

Watch the thing. Then compress its whole visual world into a single sentence that
says what it's *made of*. This sentence governs every later choice.

- Vox → **"printed, not lit."** (ink on paper, not glow on black.)
- A synthwave title → "neon tube on wet asphalt at night."
- A Kurzgesagt explainer → "flat cut-paper shapes in a friendly cosmos."

If you can't say it in a sentence, you haven't found the register yet — keep
watching. Everything downstream serves this sentence.

## 2. Pull the palette — and give each color ONE job

Eyedrop 3–6 colors from the reference. Then assign each one a single **meaning**,
not just a slot. This discipline is what separates "intentional" from
"decorative" — it's the most copied-wrong part of any style.

Vox's five: paper = the canvas, ink = structure/voice, yellow = the ONE emphasis
marker, red = the old/cost/negation, cobalt = the new. Rule that falls out:
red and cobalt never share a beat except the "turn." Write your own version:
each hex, its job, and the rule about when two colors may/may not co-occur.

## 3. Name the type system — and the ONE emphasis device

Three faces at most: a **headline** face, a **label** face, an optional **accent**
(handwriting, mono, etc.). Then pick the *single* way you emphasize a word — and
forbid every other way.

Vox: Archivo Black headlines, Inter labels, Caveat scribbles; emphasis is the
**yellow highlighter swipe**, and you *never* color-change the text. Your pack
might emphasize with a box, an underline draw-on, a scale-punch — pick one and
make it the law.

## 4. Log the motion vocabulary — each move as a recipe

Re-watch and freeze on the transitions. For every recurring move, write a recipe:
what property animates, the ease, the duration, and the "tell" that makes it read
as *this* style. **6–10 named moves is a full pack.**

Vox examples: paper slap-in (`scale 1.15→1`, `back.out(1.15)`, settle crooked),
highlighter swipe (`scaleX 0→1`, `power2.out`), sheet-wipe (the only transition).
Note the *anti-tells* too — Vox forbids glow, blur transitions, and perfectly
straight settles. (Full format in `motion-vocabulary.md`.)

## 5. Decide the texture / depth system — the one unifying substrate

Most styles have a single substrate that unifies every frame. Name it and make it
ubiquitous. Vox: halftone dots + paper grain + hard offset shadows (no blur).
Synthwave: scanlines + chromatic bloom. Kurzgesagt: flat fills, no gradients.

Decide how depth is built (Vox: hard offset shadow, never a glow) and whether
texture *carries meaning* (Vox: archival texture = "old," flat vector = "new").

## 6. Write it as a DESIGN.md, then a SKILL.md

Now formalize. Draft a `DESIGN.md` — register sentence, palette table, type,
motion table, texture, structure rules, and a "what NOT to do" list (the anti-tells
from step 4 are gold here). Then distill it into a `SKILL.md` with a pushy
`description` that triggers on how people will ask for the look. Use this repo's
`SKILL.md` as the template — same section order, so an agent can build from yours
the same way it builds from mine.

Add a `brand-tokens.css` (step 2's palette + reusable classes) and a renderable
`assets/starter/` (copy this repo's and reskin it). That's a complete pack.

## 7. Dogfood it — and turn every failed draft into a law

Build one short piece in the new pack. It won't be right on draft one. Each thing
that breaks becomes a one-line **process law** at the bottom of the SKILL — the
laws in this repo's SKILL.md were each bought with a failed draft (wrong ease
still flashes; VO-first or the timeline fights you; pre-bake or renders drift).
Those laws are what make the *next* build land in 1–2 tries instead of 9.

---

## The shape you're producing

```
your-style-pack/
├── SKILL.md                 # register + palette + type + motion + laws (triggerable)
├── references/
│   └── motion-vocabulary.md # each move's full recipe
├── assets/
│   ├── brand-tokens.css     # palette (one job per color) + reusable classes
│   └── starter/             # a renderable one-scene project to copy
└── scripts/                 # any asset-gen your texture system needs
```

Ship it as a skills repo (`npx skills add <you>/your-style-pack`) exactly like
this one. Point an AI at any video whose look you love, run these 7 steps, and
you've minted a reusable style you'll never have to re-explain.
