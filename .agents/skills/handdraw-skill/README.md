# HandDraw Skill

Agent-native, deterministic whiteboard-animation rendering. A JSON animation DSL drives SVG and text animation through Remotion into MP4.

For Chinese idiom, history, and children's-story shorts that need distinct colored scenes, a frame-zero text cover, local Qwen3 multi-role narration, synchronized subtitles, and licensed-BGM mixing, use the companion project [narrated-handdrawn-story-video](https://github.com/ToBeWin/narrated-handdrawn-story-video).

Optional narration uses free Edge TTS and FFmpeg. It requires network access, but no API key, account, or paid API. Install it once with `python3 -m venv .venv && .venv/bin/pip install -r packages/audio/requirements.txt`.

## Quick start

```bash
npm install
npm run build
node scripts/check-environment.mjs
node scripts/handdraw.mjs validate examples/photosynthesis/project.json
node scripts/handdraw.mjs render examples/photosynthesis/project.json --output out/photosynthesis.mp4 --assets examples/photosynthesis/assets
```

Use the bundled [`SKILL.md`](SKILL.md) from a coding agent. The Agent writes a project DSL, validates it, renders the MP4, and inspects the result.

For OpenClaw and Hermes installation, see [agent installation](references/agent-installation.md).

## DSL constraints

- All times are seconds; output frames derive from `fps`.
- SVG assets must be path/line-oriented, local files, and rendered as inline SVG.
- Every object has an explicit timeline animation. Keep scenes at eight objects or fewer.
- Version 1 supports `draw`, `write`, `move`, `rotate`, `scale`, `fade`, and `highlight`.
