# html-animation

**Motion graphics as code.** An agent skill for building frame-exact animated logos, kinetic typography and brand videos as a single HTML file, then exporting them to MP4 in every format social platforms ask for.

No After Effects. No timeline GUI. No plugins. The animation is code, so it is diffable, reviewable, re-renderable at any size — and, the part that matters most, *measurable*.

![demo](assets/demo.gif)

<p align="center"><sub>Made with the skill. One HTML file, no assets, exported to three aspect ratios from the same source. <a href="assets/demo.mp4">Full quality MP4</a>.</sub></p>

## Install

It is a folder of Markdown and scripts, so it drops into whichever directory your agent reads skills from.

```sh
# Claude Code
git clone https://github.com/acelera-agency/html-animation.git ~/.claude/skills/motion-graphics
# Codex
git clone https://github.com/acelera-agency/html-animation.git ~/.codex/skills/motion-graphics
# Cursor
git clone https://github.com/acelera-agency/html-animation.git ~/.cursor/skills/motion-graphics
```

Drop the `~/` for a project-local copy scoped to one repo. If your tool has no skill directory at all, point the agent straight at `SKILL.md` — it is written to be read cold and says which other file to open and when. Then ask for what you want animated.

> *"animate our wordmark for the launch reel — it's just the word Vértice, black on bone, tight sans. I want it to arrive with energy and brake hard. Square and vertical MP4."*

Nothing here is tied to a particular model or vendor. You need `ffmpeg` on your PATH and `npm i playwright` for the exporter; the animation itself has no dependencies at all.

## Why it exists

Getting an LLM to produce motion graphics that do not look like an LLM produced them turns out to be less about prompting than about a handful of things that stay invisible until they bite. This is the residue of building one film end to end and fixing everything that broke.

**"It feels janky" was zero dropped frames.** Median frame time 8.3 ms. The problem was scenes holding perfectly motionless for two seconds — a frozen frame reads as *stuck* at a flawless 60 fps.

**Two animations on one element silently break the whole film.** With `fill: 'both'` the later one wins from time zero, so something meant to appear at 14 s is on screen from the first frame. It presents as a content bug, which sends you looking in the wrong place entirely.

**`seek()` without pausing corrupts every exported frame.** The animation advances a few milliseconds before the screenshot lands. The video looks plausible, which is what makes it dangerous.

**Playwright's `animations: 'disabled'` does not freeze anything.** It fast-forwards to the end state and all 1,400 frames come out identical.

**An easing curve is not a simulation.** `ease-out` decelerates; a falling object accelerates.

**Centering the layout box leaves text sitting low**, because the box carries ascender and descender space nobody perceives. Measured before the fix: 28–41 px below centre in a 1080 frame. Nobody could name it; everybody felt it.

## The habit it is really about

Motion work invites eyeballing, and eyeballing lies. Because the timeline is seekable you can put the piece at t = 7.2 and read a `getBoundingClientRect()` — which turns "I don't like it" into a number. `scripts/verify.js` ships those measurements as functions.

And the corollary that saved the most time: **when a check suddenly fails, suspect the check.** Most alarms were the measurement's fault — a stale window, a timestamp that drifted after a retime, a comparison of elements invisible at that moment.

## Pick a motion language

The most common way a piece looks amateur is that different elements arrive in different ways. Choose one and hold to it. Which one is a **tone** decision, not a technical one.

| | Says | |
| --- | --- | --- |
| `speed` | urgency, sport, news | arrives fast with a directional smear and brakes |
| `pop` | playful, product, consumer | grows from nothing and overshoots |
| `wipe` | editorial, architectural | a hard edge uncovers it, nothing moves |
| `drift` | premium, calm, serious | barely moves, the fade does the work |
| `rise` | cinematic titles | comes up out of its own baseline |
| `focus` | photographic, dreamy | resolves from blurred |

In `assets/starter.html` this is one constant. Change it and the whole film changes tone.

## What is in here

```
SKILL.md              the workflow, the four failure modes, the measuring habit
scripts/timeline.js   the engine — paused WAAPI, tracks, motion languages, metrics
scripts/physics.js    projectile · bounce · topple · roll · departure
scripts/export.js     frame-by-frame capture → MP4, every aspect ratio
scripts/verify.js     measurements, and the traps in the measurements
references/           why each of the above is built the way it is
assets/starter.html   a complete working animation — copy this to begin
```

The agent drives all of that for you, but the scripts stand alone too.

```sh
npm i playwright

SRC=/abs/path/piece.html node scripts/export.js        # all three formats
SRC=/abs/path/piece.html node scripts/export.js 9x16   # one of them
SRC=/abs/path/piece.html node scripts/verify.js        # centring, fluidity, is it actually moving
```

A relative `SRC` resolves from `scripts/`, not from where you are standing, and the MP4s land next to the script.

Three flags decide whether a platform accepts your file. `yuv420p` or it will not decode, `+faststart` or playback waits for the whole download, and a silent audio track or some platforms reject a video-only upload. The exporter sets all three.

---

Built at [acelera.agency](https://acelera.agency) and open-sourced, because the interesting parts are the mistakes. If you make something with it we would like to see it.

[Website](https://acelera.agency) · [LinkedIn](https://www.linkedin.com/company/acelera-agency) · [contacto@acelera.agency](mailto:contacto@acelera.agency) · MIT
