# Physics: when to integrate instead of ease

## The rule

An easing curve is a *shape*, not a simulation. `ease-out` decelerates; a falling object accelerates. For anything thrown, dropped, bounced or toppled, integrate the motion at a fixed `dt` and emit the sampled points as keyframes with `linear` easing between them. The sampling carries the curve.

The same applies to departures. Something pulling away — a vehicle, a launch — starts slow and builds, which is `x = ½at²`; `ease-out` does the exact opposite and `ease-in` only approximates it. Integrate with a constant acceleration and a speed cap, and scale the motion trail by `v/vmax` so the smear grows with the speed — the trail sits *behind* the motion, so flip its offsets with the direction. Which direction is not free either: if the object came to rest in some orientation, it now has a facing, and driving the other way reads as reversing. Mirror the whole departure off a single `dir` so it stays consistent. Add the two beats that sell it: a weight-transfer squat before moving, and a couple of rocking oscillations that go nowhere before it grips.

```js
const dt = 1/240;                 // finer than the frame rate: bounces are brief
let x = x0, y = y0, vx = v0x, vy = v0y, t = 0;
const pts = [];
while (t < limit){
  t += dt;
  vy += g * dt;  y += vy * dt;  x += vx * dt;
  pts.push({ t: t0 + t, x, y });
}
tl(el, pts.map(p => ({
  t: p.t,
  transform: `translate(${p.x.toFixed(2)}px, ${p.y.toFixed(2)}px)`,
  ease: 'linear'
})));
```

Around 120 keyframes for a second of motion is fine. Values that work as a starting point for a hand-sized object in a 1080 frame: `g ≈ 4400 px/s²`, launch `vy ≈ -1150 px/s`, restitution `≈ 0.46`.

## Boxes and discs are different solvers

`PHYS.drop()` models a **rectangle** — corner contact, and a topple that ends with a face lying flat. `PHYS.roll()` models anything **round** — the contact height is the radius at any angle, so there is no topple: it bounces, then rolls, then friction stops it.

Running a disc through the box solver produces something that rises and falls with every rotation, because the solver thinks the contact height changes as it spins. It looks wrong and the cause is not obvious from the animation.

For the disc, the impact also couples spin to the surface through a tangential impulse. That is what makes a coin read as a coin rather than as a bouncing ball with a texture on it.

## How many bounces

`stop` — the vertical speed below which bouncing ends — is a **directorial** control, not an implementation detail. It is the knob that decides "bounces twice" against "bounces five times", which is usually the thing the brief actually specifies. Default 90 px/s; raise it for fewer bounces.

## Contact with rotation

If the object spins, the axis-aligned bottom is not what touches the floor. For a box of half-extents `a` (x) and `b` (y) rotated by θ, the centre rests at

```
h(θ) = a·|sin θ| + b·|cos θ|
```

above the floor. Use that for the contact test and a corner touches first, which is what actually happens.

## Coming to rest — the part that goes wrong

A tumbling object that stops bouncing is usually left tilted, resting on a corner. From there it topples: it pivots about that corner under gravity until a face lies flat.

Do **not** tween the angle to upright. It is not a fall — a fall accelerates — and it looks exactly as artificial as it is. Keep integrating:

```
τ = -g · (horizontal lever arm of the contact corner)
α = τ / I,   I = (4/3)(a² + b²)   for a rectangle about its corner
```

While pivoting, the centre also **drops** (a corner rest is higher than a face rest) and **shifts horizontally** as it swings about the fixed corner. Those two are what make it read as real; a pure rotation reads as a tween no matter how well eased.

### Bug 1: the pivot jumps when the contact corner changes

Track the contact corner from the signs of sine and cosine:

```js
u = a · sign(sin θ)      v = b · sign(cos θ)
cx = pivotX - (u·cos θ - v·sin θ)
cy = floor   - (u·sin θ + v·cos θ)
```

This description is continuous through the tipping point — where the same corner stays down and the object simply passes from one face's basin to the next — and only changes at multiples of 90°, when a face slaps flat and the pivot genuinely moves to the other corner. Re-anchor the pivot from the current centre at that instant and the position stays continuous.

Describing it instead with 90° "frames" that swap the half-extents makes the centre jump the width of the box at the tipping point. Measured: **44.67px between consecutive frames**, and it was not obvious in playback.

Related: deriving the pivot side from `Math.sign(θ)` alone flips it at θ = 0, jumping the centre by the full box width. Carry the side as state.

### Bug 2: it never comes to rest

A box has **four** stable orientations, not one. If the simulation only models "upright", an object that tips past its balance point rotates toward lying down and then oscillates forever, because there is no rest state there to catch it.

For a box taller than it is wide, lying down is the *lower* energy state — so a spinning letter will essentially always end up fallen, never standing. That is correct physics, and worth telling whoever asked, because they may expect it to land neatly upright.

The honest lever on the outcome is the **throw**, not the landing. Changing the initial spin changes where it comes to rest; clamping the final angle is just a tween wearing a costume. If a particular resting pose is required, either tune the launch until physics produces it, or say plainly that it will not.

## Physics and format interact

If any part of the geometry derives from the canvas height — a floor at `ALTO - 200`, a launch from the top of frame — then each aspect ratio simulates a different fall and each MP4 ends at a different time. Every file looks fine on its own, which is what makes it hard to catch.

Derive physics geometry from fixed canvas coordinates, or accept the divergence deliberately and check that `window.__duration` matches across formats.

## Verify a simulation numerically

Two checks catch nearly everything:

**Continuity.** Sample the element's position at the target frame rate and report the largest jump between consecutive frames. Real motion is smooth; a discontinuity means a bookkeeping bug. Compare the worst jump against the expected velocity: 108 px/s at 60fps should show 1.8px per frame, and a 9.67px jump was a sign flip.

**Rest.** Confirm it actually stops, and where. A hardcoded settle keyframe that used a fixed X while the simulation ended somewhere else made a letter slide sideways to reach an invented point — it read as teleporting.

Also check it rests *on* the surface: measure the object's bottom against the surface's top and expect them equal, not approximately equal.
