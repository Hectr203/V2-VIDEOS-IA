# Installing HandDraw Skill in Other Agents

The renderer is portable: it needs Node.js 20+, FFmpeg, Python 3 with `edge-tts`, and network access for free Edge TTS. Run `node scripts/check-environment.mjs` after installation. The Hermes installer reuses an existing `edge-tts` installation or creates an isolated `.venv`; it does not modify a system-managed Python environment.

## OpenClaw

From this project root, run:

```bash
bash scripts/install-openclaw.sh
```

This calls OpenClaw's local-skill installer with the complete project directory. Start a new OpenClaw agent session, then ask it to use `handdraw-skill`.

## Hermes

From this project root, run:

```bash
bash scripts/install-hermes.sh
```

The installer copies the source, installs the Node/Python runtime dependencies, and places the skill in `~/.hermes/skills/video/handdraw-skill`. Start a new Hermes session and invoke `/handdraw-skill` or request a hand-drawn explainer video in natural language.

## Updating installed copies

OpenClaw and Hermes install local copies. After changing this project, refresh both installed copies with:

```bash
bash scripts/sync-agent-installs.sh
```
