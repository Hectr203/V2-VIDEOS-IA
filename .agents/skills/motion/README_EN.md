# /motion — Claude Code animation skill

English | [中文](README.md)

A Claude Code skill that turns one reference image (or a single sentence) into a short animated video in **retro paper-collage style**.

Pipeline: reference image → keyframes via Nano Banana → image-to-video via Kling → optional upscale. Fully conversational; every credit-spending step asks for confirmation first.

![Demo](assets/demo-motion.gif)

▶️ [HD demo video](assets/demo-motion.mp4) · [Watch it live](https://imluna.pages.dev/skills/motion)

## Why retro collage

Photorealistic "AI cinematic" looks fake at a glance and is instantly forgettable. This skill ships a proven retro Motion Design recipe: saturated paper-grain backgrounds + black-and-white halftone cutouts + torn-paper labels with bold type + stop-motion jitter. Prompt skeletons for both keyframes and video are built in.

## Install

```bash
git clone https://github.com/LunaAI519/motion-skill.git ~/.claude/skills/motion
```

Restart Claude Code and type `/motion`.

**Prerequisites** (two MCP servers):

| MCP | Role | Notes |
|---|---|---|
| nanobanana (Gemini images) | Keyframe generation | Bring your own Gemini API key |
| higgsfield | Image-to-video + upscale | Kling default ≈ 7.5 credits per video |

## Usage

```
/motion
```

Then give it a reference image (drag into the terminal) plus one sentence describing the motion (e.g. "slow push-in, hair moving in the wind"). Default aspect ratio is 9:16. No reference image? Plain text works too — the first frame gets generated from your description.

Every intermediate output (keyframes, credit cost) is shown for approval before money is spent.

## Showcase

All generated with this skill, roughly 3 minutes from idea to clip.

| | |
|---|---|
| ![Mountain-city papercraft](showcase/chongqing-papercraft.gif) | ![P/E ratio](showcase/pe-ratio.gif) |
| **Mountain-city papercraft**: layered papercraft night scene, a cable car passing through buildings. [HD mp4](showcase/chongqing-papercraft.mp4) | **P/E ratio**: made for an explainer article, a scale weighing profit. [HD mp4](showcase/pe-ratio.mp4) |
| ![Site intro](showcase/hero.gif) | ![Moon keyframe](showcase/moon.jpg) |
| **Site intro**: the animated hero of [imluna.ai](https://imluna.ai). [HD mp4](showcase/hero.mp4) | **Moon**: a keyframe generated from text only, no reference image |

▶️ More: [SpaceX joins the Nasdaq-100](showcase/spacex.mp4)

## Copyright guardrails

Five built-in self-checks run before every generation: no real-person likenesses, no brand logos, no copyrighted characters, learn the recipe from references but never republish their frames, and royalty-free music only.

## Related

- [xsub](https://github.com/LunaAI519/xsub) — Chrome extension: auto Chinese subtitles for English videos on x.com
- [video-to-brain](https://github.com/LunaAI519/video-to-brain) — send a video to a Telegram bot, get structured AI notes in Obsidian
- More at [imluna.ai](https://imluna.ai)

## License

MIT © Luna ([imluna.ai](https://imluna.ai))
