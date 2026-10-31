# Craft: type, motion, and the recurring element

## Optical centering

Centering the layout box leaves text sitting low, because the box carries ascender and descender space that nobody perceives. Centre the **ink**: cap top of the first line to baseline of the last.

`MG.opticalCenter()` does this with real font metrics from canvas `measureText`:

```js
const m = mctx.measureText('H');
baseline = (lineHeight - (m.fontBoundingBoxAscent + m.fontBoundingBoxDescent)) / 2 + m.fontBoundingBoxAscent;
cap      = m.actualBoundingBoxAscent;
```

Measured on a real piece before the fix, scenes sat 28–41px below centre in a 1080 frame. Nobody could name it; everybody felt it.

**Whether a rule or underline counts** depends on its role:

- Fixed part of the lockup (under a logo, under a URL) → include it. Otherwise the composition is bottom-heavy by half the rule's overhang.
- A highlight that moves from line to line → exclude it. Include it and the framing shifts depending on where the highlight happens to be parked.

## Type that fills its measure

Short lines in a big frame look like a mistake. Two checks worth doing numerically:

**Does the text fill the measure?** Sum the token widths, not the `.line` box — a block element reports the container width, and if a camera scale is active you will read that scaled. At one point three lines of 84px type left 413px of empty frame; at 112px the first line filled 756 of 880 and the scene stopped looking broken.

**Is the hierarchy right?** If a small supporting line ends up the *widest* element on screen, the hierarchy is inverted and it reads as unbalanced no matter what else you do. Shorten it or enlarge the headline until the primary line is clearly the widest.

## Leading, spacing, and where a rule fits

**Uniform leading, sized so a highlight fits in any gap.** Giving extra margin only to the underlined line makes that line breathe differently from the rest — someone will say "the underlined text takes up more space" without knowing why. The gap should be identical whether the rule is there or not: the rule lives in the gap, it does not create it.

**Word gaps are margin, not text nodes.** An inline-block containing only a space collapses to zero and the words come out glued together. Use `margin-right` on the token, zero it before punctuation, and zero it on the last token of a line — otherwise a trailing margin shifts centred lines off-centre.

Strip that last margin in JS rather than with `:last-child`, because with grouped targets (`*{two words}`) the last token of the *group* is also `:last-child` of its wrapper and would eat the space before the next word.

## Choosing a motion language

Pick one way things arrive and one way they leave, and hold to it across the whole piece. Mixing them is the most common reason work looks amateur, and it is invisible while you build scene by scene.

The choice is about tone. Six that cover most briefs, all in `MG.ENTER` / `MG.EXIT`:

**`speed`** — arrives fast with a directional smear and brakes hard. Urgency, sport, news, anything about being quick. Loud; wears out on long pieces.

**`pop`** — grows from nothing and overshoots. Playful, consumer, product. Reads friendly, reads cheap if overdone.

**`wipe`** — a hard edge uncovers it and nothing moves. Editorial, architectural, confident. The most restrained option that still has energy, and the best default when the type itself is the point.

**`drift`** — barely moves; the fade does the work. Premium, calm, serious. Needs slower timings all round or it looks like nothing happened.

**`rise`** — comes up out of its own baseline behind a mask. Cinematic titles. Requires `overflow: hidden` on a wrapper per line.

**`focus`** — resolves from blurred. Photographic, dreamy. Expensive to render; check the frame rate before committing.

Two levers change the feel more than the language does:

**Stagger unit.** Per-letter is energetic and becomes exhausting past a few words. Per-word is the middle. Per-line is calm and is usually right for sentences. The same `pop` staggered per-letter and per-line are two different pieces.

**Duration ratio.** An entrance that is 60% of the hold reads as busy; 25% reads as composed.

### Directional smear

If the language is `speed`, the blur has to be directional — `filter: blur()` is isotropic and wrong for linear motion. Offset copies in a shadow list give the direction, and shadow lists interpolate between keyframes so it animates for free.

`MG.trail(size, k, {dx, dy, colour})` takes a direction and a colour. Both matter: the trail belongs *behind* the motion, so it flips when the object does, and a hardcoded dark trail is invisible on a dark background.

There is a better and costlier option: render several subframes per output frame and average them in ffmpeg with `tmix`. That is true motion blur in every direction at once, at N× the capture time. Worth it for a hero piece.

### What holds regardless of language

**Arrivals decelerate, departures accelerate.** Matching curves makes everything rubbery.

```js
brake  = cubic-bezier(.12,.85,.25,1)     // arrivals
launch = cubic-bezier(.55,0,.9,.35)      // departures
breath = cubic-bezier(.45,0,.55,1)       // anything continuous
```

**Chained ease-outs read as stop-start.** Every segment decelerates to zero and the next starts fast. For anything continuous, ease-in-out.

**For large type, scale the exit down.** Exit distance is proportional to font size, so at 112px the default sweep crosses half the screen and collides with the next scene. A factor around 0.55 keeps the language at a fraction of the distance.

**Nothing should ever be perfectly still.** A frame that holds motionless for two seconds reads as *stuck*. This is easy to misdiagnose: on a real piece the complaint was "it feels janky", and the measurement showed **zero dropped frames** at a median of 8.3ms. It was not performance. It was that scenes had no camera, so between entrance and exit the image was frozen.

Every scene gets a slow push: settle over ~1.5s, then keep drifting to about 1.007 by the time it leaves. At 1.014 people report things "levitating".

**Overlap, but not too much.** Scenes overlap — the outgoing text is still leaving as the next arrives — and that is what makes it flow. But when the two are at very different type sizes, a big smear draws over the small type underneath and reads as a mistake. The right gap is not a constant: it depends on the exit duration plus the stagger. Widen it until the frame actually clears, and check by rendering the transition rather than by arithmetic.

### On dark backgrounds

Three things break quietly:

- A trail with a hardcoded dark colour simply does not exist. Pass `{colour:'255,255,255'}`.
- Large flat dark areas band. A static grain layer at around 5% opacity fixes it.
- Two stacked vignette gradients draw the edge of the ellipse, very visible in 9:16. Use one.

## A recurring element as the spine

One element that persists across every scene is the cheapest way to make a sequence feel composed rather than assembled. The form is open — a rule under the key word, a dot, a cursor, a shape that reframes each card, a mask edge that wipes between them. What follows uses a travelling rule as the worked example because the geometry is easy to talk about, but the principles transfer.

Treat it as a character, not a graphic. Some things that make that work:

**Constant thickness.** Draw it 100px wide and resolve the real width with `scaleX`, so the thickness never changes wherever it goes.

**Rotate on its axis.** `transform-origin: center`, not `left`. A rectangle tilted two degrees reads as a head turning; it is the cheapest expressive lever available and the single thing that turns a bar into a character.

**Ask for tilt in pixels, not degrees.** A 300px bar and a 78px bar must lean the *same amount visually*; with a fixed angle the short one is imperceptible.

```js
const tilt = px => Math.min(8, Math.atan2(px, width / 2) * 180 / Math.PI);
```

**Stretch by edges, not from the centre**, when the targets share an edge. Left-aligned lines all start at the same x and differ only in where they end. Stretching from the centre pushes both ends, so reaching a long item also grows leftward — off the frame. Interpolate the left and right edges independently and let the travelling edge carry the stretch.

**Weight on landing.** Overshoot, stretch on the way, rebound twice, settle. Squash and stretch, but on the X axis only — thickening the bar is cartoon vocabulary and clashes with a speed-based language.

**An idle vocabulary** for when it waits: breathe, twitch, look (tilt and hold), nod, yawn, shiver. Draw them from a shuffled deck rather than sampling independently, so no two waits look the same and none is only breathing. End long waits with a slow settle — contract slightly, tilt, sink — so the next move reads as waking up.

**Seed the randomness.** With `Math.random()` the preview and the export are different films, and so is every re-render.

**Stop when the scene stops.** Once the piece has landed its final beat, it should be still. Idle gestures during the closing frame read as noise exactly when attention should be on the payoff. "Still" here still includes the camera's global drift — that is fine, it moves everything together.

## Two things that look right and are not

**An element that crosses text reads as a rendering bug**, even when the copy explicitly calls for a strikethrough — and even when the strike is typographically well placed at a third of cap height above the baseline. It also contradicts the rule that keeps it behind the type. If a line needs negating, let the gesture do it — park under the word and shake.

**An element that flies past a line without stopping reads as a blink.** Either stop on it — three deliberate stops down a three-line block reads as following the reading — or make the transit short and let the letters cut through it. What does not work is a fast pass at full size across a line it never lands on.

## When the words are the problem

If you are writing copy too and two rounds of alternatives all feel wrong, stop generating options. The words are usually fine; the *slot* has no defined job. Ask what that beat is for — name the problem, answer the objection, show proof, make the promise — and the line tends to write itself.

A defensive beat (security, guarantees, risk) dropped into the middle of a persuasive sequence will feel wrong no matter how well phrased, because it interrupts the momentum. That is a structural problem, not a wording one.

And when someone says a section is "too slow", scale its whole sequence by a factor rather than trimming one hold. The internal rhythm is usually right; there is just too much of it.
