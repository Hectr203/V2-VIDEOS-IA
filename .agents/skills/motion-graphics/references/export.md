# Export

`scripts/export.js` renders every aspect ratio and works unchanged for any piece exposing `window.__seek` and `window.__duration`.

```sh
npm i playwright && npx playwright install chromium
node export.js            # 1:1, 4:5 and 9:16
node export.js 9x16       # one
FPS=30 CRF=20 node export.js
```

## Aspect ratios: change the canvas, never pad

Keep the width fixed (1080) and vary only the canvas **height**, read from a query parameter:

```js
const ALTO = Math.round(+new URLSearchParams(location.search).get('h') || 1080);
```

Padding a square with flat colour is the obvious shortcut and it is wrong whenever anything reaches the frame edge. A vignette arriving at the border at ~4.5% black meets flat background and leaves a visible seam. A taller canvas puts the gradient across the whole frame and the composition simply gets more room.

Everything that referenced the canvas centre has to follow — optical centering uses `ALTO/2`, and the fit calculation becomes `min(innerWidth/1080, innerHeight/ALTO)`. Then verify the centring is identical across formats; it should come out the same to within a few pixels.

| | Size | Where |
| --- | --- | --- |
| 1:1 | 1080×1080 | LinkedIn, Instagram feed, Facebook, X |
| 4:5 | 1080×1350 | Instagram and LinkedIn feed — more height on mobile |
| 9:16 | 1080×1920 | Reels, Stories, TikTok, Shorts |

A square composition centred in 9:16 leaves large empty margins. That is normal and correct — platform UI occupies those areas — and scaling the content up is not an option without a redesign, since it already fills the width.

## Encoder flags that decide whether the file works

```
-c:v libx264 -pix_fmt yuv420p -crf 17 -preset slow
-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -shortest -c:a aac -b:a 96k
-movflags +faststart
```

- **`yuv420p`** — x264 defaults to a chroma format that platforms and QuickTime will not decode. This is the single most common reason an exported file "does not work".
- **`+faststart`** — moves the index to the front. Without it, playback waits for the whole file to download; in a feed that decides whether anyone sees it.
- **Silent audio track** — some platforms reject video-only uploads outright. `anullsrc` plus `-shortest` costs nothing.
- **CRF 17** — visually lossless for flat graphics. A 24-second 1080×1080 piece lands around 3 MB.

60fps is worth it for fast motion with trails. 30fps roughly halves the file if that matters more.

## The Playwright trap

```js
await page.screenshot({ animations: 'disabled' });   // never
```

That option does not freeze anything. It **fast-forwards every animation to its end state**, so all N frames come out identical. The timeline is already paused; passing it is the bug.

## Checking the output

```sh
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,pix_fmt \
  -show_entries format=duration -of csv=p=0:nk=1 out.mp4
```

Confirm the dimensions, `yuv420p`, the frame rate, the duration against `window.__duration`, and that an audio stream exists. Cheap, and it catches a bad render before an upload does.

## Timing

Roughly 1400 frames per format for a 24-second piece at 60fps, about 60–90 seconds of capture each plus encoding. Run it in the background and do something else. If you change the animation mid-export, kill it and restart — half the frames will be from the old version and the seam is not obvious.
