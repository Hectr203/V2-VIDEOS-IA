# Animation DSL v1

```json
{
  "version": 1,
  "project": { "title": "Example", "width": 1920, "height": 1080, "fps": 30, "background": "#fffdf8" },
  "scenes": [{
    "id": "intro",
    "duration": 4,
    "objects": [{
      "id": "sun",
      "kind": "svg",
      "asset": "sun.svg",
      "x": 120, "y": 100, "width": 280, "height": 280,
      "animations": [{ "type": "draw", "start": 0, "duration": 2 }]
    }]
  }]
}
```

`kind` is `svg`, `text`, or `shape`. SVG objects need `asset`; text objects need `text`; shapes need `shape` (`card`, `pill`, `circle`, `line`, or `bar`) and can set `fill`, `stroke`, `strokeWidth`, `radius`, `label`, and `labelColor`. Coordinates are pixels in the project canvas. Animation `start`, `duration`, and optional `delay` use seconds. `move` accepts `x` and `y`; `rotate` and `scale` use `to` values.

Use shapes behind illustrations to create hierarchy rather than placing all elements directly on the paper background:

```json
{ "id": "panel", "kind": "shape", "shape": "card", "x": 180, "y": 190, "width": 500, "height": 380, "fill": "#ffffff", "stroke": "#dbeafe", "radius": 32, "animations": [{ "type": "fade", "start": 0, "duration": 0.4 }] }
```

Scenes can add a static camera framing and a soft scene transition:

```json
"camera": { "zoom": 1.04, "x": -20, "y": -10 },
"transition": { "type": "fade", "duration": 0.65 }
```

Supported types: `draw`, `write`, `move`, `rotate`, `scale`, `fade`, and `highlight`. `highlight` applies a warm emphasis glow.

## Free narration (Edge TTS)

Add optional narration. It uses the free `edge-tts` client and FFmpeg—no API key, account, or paid API is used. It does require network access to the Edge TTS service.

```json
"audio": { "narration": [
  { "text": "阳光照在绿叶上。", "start": 0.5, "voice": "zh-CN-XiaoxiaoNeural", "rate": "+0%" }
] }
```

`start` is seconds from video start. `voice` defaults to `zh-CN-XiaoxiaoNeural`; `rate` uses Edge TTS percentage syntax. Install the free client once with `python3 -m venv .venv && .venv/bin/pip install -r packages/audio/requirements.txt`.

## Narrative sketch mode

For portrait, story-driven hand-drawn videos, set `project.style` to `narrative-sketch`. It removes the business header and generic drawing hand, uses a quiet paper background and handwritten Chinese typography. Use a 9:16 canvas such as `1080 × 1920`, black line-art SVGs, generous negative space, and no more than three muted accent colors.

To make a scene caption follow an actual generated narration clip, set `syncWithNarration` on the text object. The renderer then adjusts that object's `write` animation from the synthesized audio duration, so changing voice or rate preserves timing:

```json
{ "id": "caption", "kind": "text", "syncWithNarration": 0, "text": "每月订阅，收入更可预测", "x": 380, "y": 780, "width": 1200, "height": 66, "animations": [{ "type": "write", "start": 0, "duration": 1 }] }
```
