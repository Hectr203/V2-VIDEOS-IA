---
name: remotion-continuous-motion
description: Design and implement continuous, frame-deterministic motion in Remotion, including camera moves, shared-element transitions, kinetic typography, atmosphere, and blur. Use when authoring or fixing Remotion motion and transitions.
---

# Remotion Continuous Motion

## Core rules

1. Derive every visual state from `useCurrentFrame()`, `useVideoConfig()`, and immutable props. The same frame must render the same pixels regardless of render order or concurrency.
2. Keep editorial time in seconds and animation time in frames. Convert using the actual composition fps; never hardcode `30` inside a component when `useVideoConfig()` is available.
3. For every scene boundary, specify a continuous transition and its `durationInFrames`, easing, direction, and visual anchor. No abrupt static scene changes.
4. Prefer a shared canvas/camera layer when the subject can travel between scenes. Keep the shared element mounted across the boundary and interpolate its bounding box, scale, rotation, color, or SVG path.
5. Use `interpolate()` with sorted frame ranges and explicit extrapolation. Use `Easing.inOut(Easing.cubic)` for camera movement; use restrained springs for object entrances and impact beats.
6. Compute total composition duration after overlaps. Captions, SFX, and scene props use the same timeline origin and fps.
7. CSS animations, CSS transitions, timers, `requestAnimationFrame`, `Date.now()`, mutable animation state, and unseeded randomness are forbidden in final offline renders.
8. Preserve legibility and source art style. Motion blur is limited to fast movement and must not soften small text or pixel-art edges.

## Implementation sequence

1. Read the approved storyboard and scene ledger; flag any missing `poseOut → bridge → poseIn` before coding.
2. Implement camera and shared-element trajectories first, then scene art, typography, atmosphere, and secondary motion.
3. Keep animation components small and parameterized (`from`, `to`, `durationInFrames`, `seed`, `anchorId`).
4. Render boundary frames and transition midpoints before a full review render.
5. Check the installed Remotion version and lockfile. Any `@remotion/*` package must use a compatible, aligned version; do not assume a package is installed because current documentation includes it.

## Standard motion values

- Title entrance: 8–14 frames; translate 8–20 px; scale 0.96–1.0.
- Word emphasis: 4–7 frames; restrained scale/position; keep line wrapping stable.
- Scene bridge: 15–24 frames as a starting range; do not use a generic fade as the only continuity device.
- Camera travel: 24–75 frames with acceleration/deceleration ramps.
- Ambient movement: low amplitude, seeded and slow enough not to distract.

Adjust these defaults to measured reference timing and speech rhythm.

## Example camera interpolation

```tsx
const progress = interpolate(frame, [from, to], [0, 1], {
  easing: Easing.inOut(Easing.cubic),
  extrapolateLeft: 'clamp',
  extrapolateRight: 'clamp',
});
const x = interpolate(progress, [0, 1], [cameraIn.x, cameraOut.x]);
const scale = interpolate(progress, [0, 1], [cameraIn.scale, cameraOut.scale]);
```

## Completion gate

Do not call motion complete until the transition ledger covers every scene boundary, boundary/midpoint frames are reviewed, timing survives the final fps and dimensions, and the complete output has been watched once at normal speed.
