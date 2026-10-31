# The timeline engine

## Why paused WAAPI and not something else

| Approach | Why not |
| --- | --- |
| CSS animations | Run on wall-clock time. You cannot ask for frame 847. |
| GSAP / anime.js | Seekable, but a dependency, and you still hand-roll the export. |
| After Effects / Rive | Not code. Not diffable, not scriptable, not re-renderable from a prompt. |
| Screen recording | Non-deterministic. Drops frames, varies by machine, cannot re-render at another size. |

Paused WAAPI gives seekability with zero dependencies, and — the part people underrate — it makes the animation *queryable*. You can put the piece at t=7.2 and read a `getBoundingClientRect()`. Every verification technique in `verify.md` depends on that.

## Absolute time

`tl()` takes keyframes in absolute seconds and converts them to `delay` + `duration` + fractional offsets. That means `seek(t)` is `currentTime = t` for every animation, with no bookkeeping.

Because `fill: 'both'` is set, an element holds its first keyframe before its delay and its last one after. So a single animation genuinely describes the element's whole life.

## The four failure modes, in depth

### 1. Two animations, one property

```js
beat(el, tIn, null);          // entrance, fill:both
tl(el, [exit keyframes]);     // exit, fill:both      ← collides
```

Both fill backwards. The later-created animation has higher composite order, so *its* first keyframe applies from time zero. If that keyframe says `opacity: 1`, the element is on screen for the entire piece.

The symptom is confusing because it presents as a *content* bug — the closing logo visible behind scene two — rather than an animation bug. If you see something from a later scene bleeding into an earlier one, count the animations on that element before anything else.

Same rule applies to a travelling element: one element, one animation, all its moves in one list. That is what `Track` is for.

Different properties on the same element are fine — a `z-index` animation alongside a `transform` animation does not collide.

### 2. seek() without pause

```js
function seek(s){ A.forEach(a => a.currentTime = s * 1000); }   // wrong
```

If a preview loop is running, the animations are *playing*. You set the time, control returns to the browser, several milliseconds elapse, and the screenshot captures a slightly later moment. In a preview that is invisible. In an export it silently offsets every single frame, and the video looks fine — which is what makes it dangerous.

Pause first, and cancel the preview loop the first time an external seek arrives, or it will fire mid-export and start playback again.

### 3. Non-monotonic keyframes

Chaining moves by hand ("this one at t+0.3, then that one at t+0.5") eventually schedules something before the previous move finished. WAAPI throws `Offsets must be monotonically non-decreasing` for the *whole animation*, naming nothing.

`Track.push` clamps with `Math.max(t, last)`. Times in your script become intentions: too early degrades to "immediately after".

This bites twice. The second time is when you assemble a track out of several sequences — a shared camera built from per-scene windows, say. If one scene runs longer than planned its window overlaps the next, and the assembled list is out of order. Clamp there too:

```js
bk.push({ t: Math.max(prev, Math.min(prev + .45, next.t0 - .01)), ... });
```

### 4. Measuring after animating

`fill: 'both'` applies immediately, so once the animations exist every rect includes a transform. Anything you measure then is wrong.

Fixed order: **build DOM → optically centre → measure targets → create animations.** If a later stage needs a measurement, take it in the measuring stage and keep it.

## Porting CSS keyframes faithfully

If you are reproducing an existing CSS animation, port it *literally*, including the parts that look like oversights. Three details that changed the result when they were "cleaned up":

**A keyframe that omits a property is not the same as one that repeats it.** In

```css
0%   { opacity:0; transform: translateX(-1.45em) scaleX(1.55); }
28%  { opacity:1; }                       /* no transform */
68%  { transform: translateX(.055em) scaleX(.955); }
```

the transform interpolates 0% → 68% in one stretch. Adding a transform at 28% changes the trajectory. `tl()` preserves omissions — just leave the property out of that step.

**`em` resolves against the element the animation is on, not the visual size of the thing.** A camera on a wrapper that never sets `font-size` gets the document's 16px, so `translateX(.10em)` is 1.6px — not 16.7px as it would be inside a 167px headline. Reproducing the "intended" value moved the scene 15px.

**Ancestors count.** If the original had the mark nested *inside* the element the camera scales, it is scaled too. Reproduce the containment or replicate the transform on its layer.

Every one of these was found by a pixel diff, not by looking.

## Camera and shared tracks

The camera goes on the full-canvas scene element, not on the text block. Two reasons:

- Its centre is the canvas centre, so any other full-canvas layer can reuse the *identical* transform string and stay locked to the type. Put it on the text block and a left-aligned scene scales about its own centre, which no other layer can match.
- Scenes are `inset: 0`, so this works at any canvas height.

Because the content inside a scene is optically shifted by `dy`, scaling about the canvas centre displaces it by `(1-s)·dy`. The `cameraKeyframes` helper cancels that with a `translateY` term, so the push happens about the content's own centre without moving the transform origin. With dy = 31px and a 3% scale that is ~0.9px — small, and exactly the kind of thing a pixel diff catches and an eye does not.

## Layering

The recurring mark belongs **behind** the text (`z-index` below the scenes). When it moves between lines it has to cross the line in between; in front that reads as a strikethrough — a rendering bug — while behind, the letters cut through it and it reads as passing underneath.

If some moment genuinely needs it in front (covering something up), animate `z-index` — it interpolates discretely, which is what you want:

```js
tl(overlay, [
  { t: 0,        zIndex: '0', ease: 'linear' },
  { t: cover - .01, zIndex: '0', ease: 'linear' },
  { t: cover,    zIndex: '2' }
]);
```

Keep it below any full-canvas overlay such as a vignette, or it will render on top of the grade.

## Deriving times instead of hard-coding them

Scenes whose length depends on a sequence of moves should publish their end time rather than have it guessed:

```js
let t = arrive(start, targets[0]);
targets.slice(1).forEach(g => { t = hop(t + .16, g); });
const sceneOut = t + .3;                 // the scene is as long as the moves need
```

Hard-coded times made a five-item list end after three items, because the moves grew and the scene did not. Derive downstream times from `sceneOut`.

The counterweight: scenes that are structurally alike should *be* alike. A scene twice as long as its neighbours reads as a mistake even when its content earns the time. Same shape, same duration, same gap — then the piece feels composed rather than assembled.

Expose the derived times for the verification scripts:

```js
window.__times = { ...T, sceneOut, end };
```

Verification scripts that hard-code timestamps go stale the first time you retime anything, and then report failures that are not there.
