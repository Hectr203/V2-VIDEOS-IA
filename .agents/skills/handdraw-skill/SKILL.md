---
name: handdraw-skill
description: Create deterministic hand-drawn, whiteboard, educational, and explainer MP4 animations from a JSON Animation DSL. Use when a user asks to make or edit a hand-drawn video, whiteboard animation, animated SVG explainer, or programmatic animation video.
---

# HandDraw Skill

Create an editable animation project, validate the DSL, render it, and verify the MP4. Use the portable `scripts/handdraw.mjs` CLI from this skill root.

## Workflow

1. Convert the request into short scenes with one visual concept each.
2. Create `project.json` from the schema in [references/dsl.md](references/dsl.md). Use seconds for all timing.
3. Use only local, path-oriented SVG assets. Put them in an `assets/` folder next to the project. Do not use raster images or text-to-video models.
4. Keep each scene at eight objects or fewer. Give every visible object an explicit animation.
5. Run `node scripts/check-environment.mjs` once on a new machine. Fix every missing dependency.
6. Run `node scripts/handdraw.mjs validate <project.json>` and fix every error.
6. When narration is requested, add `audio.narration` clips as described in [references/dsl.md](references/dsl.md). Use the free Edge TTS provider by default; it needs network access but no API key, account, or paid API.
8. Render with `node scripts/handdraw.mjs render <project.json> --output <video.mp4> --assets <assets-dir>`.
9. Confirm the MP4 exists and contains both video and audio streams when narration was requested.

## Animation choices

- Use `draw` for SVG line art.
- Use `write` for text; it is a deterministic reveal, not true handwriting stroke order.
- Use `move`, `rotate`, and `scale` sparingly to direct attention.
- Use `fade` for entrances and exits.
- Prefer 3–8 second scenes; avoid simultaneous unrelated motion.

## Constraints

- Do not edit renderer implementation just to accommodate an invalid DSL; correct the project first.
- Do not rely on external URLs for assets.
- Preserve the requested aspect ratio, duration, and language.
- If no duration is requested, target 30 seconds and state the assumption in the project title or handoff.
