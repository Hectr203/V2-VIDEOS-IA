---
name: editorial-paper-collage-animation
description: Generate a 10-second self-assembling animation prompt from a supplied final frame, using the VOXSTAGE archival paper-collage visual system. Use for paper-collage animation, investigative documentary collage, locked-frame animation, or animating a reference image.
---

# Editorial Paper-Collage Animation

Treat the supplied image as the only final-frame composition. Read `references/style-boards.en.md` and `references/voxstage-visual-system.en.md`. Use `assets/mg-voxstage.webp` by default; switch to another supplied board only when the user explicitly names it. Generate one 10-second prompt in which the collage assembles from an empty background during the first seven seconds and matches the reference at exactly 7 seconds. Never redesign, reposition, scale, crop, replace, or reinterpret any element.

## Fixed visual language

Use hand-cut paper, aged newsprint, archival documents, halftone photos, torn edges, masking-tape fragments, pushpins, typewritten labels, rubber stamps, red investigation string, retro paper grain, visible paper thickness, and soft layered shadows. Treat every object as a physical paper cut-out lying on a tabletop.

Use stop-motion timing: update every two frames, slightly stepped easing, 2–3 frame holds, tiny settling bounces, paper drag, and friction. Forbid smooth CGI interpolation.

## Camera and lighting

Use one continuous locked-off shot. Keep the camera static by default; only when the user explicitly asks for a dynamic VOXSTAGE version, allow no more than an approximately 2% slow overall drift. Forbid zooms, pans, tilts, rolls, orbits, push-ins, pull-backs, tracking, handheld shake, rack focus, reframing, lens breathing, cuts, transitions, morphs, and time jumps.

Maintain soft, constant editorial tabletop lighting with paper-layer shadows, print texture, thickness, archive grain, and natural ambient occlusion.

## Timeline

### 0–7 seconds: assembly

Start with only the fixed paper/map background, stains, grain, corkboard, timeline, and background textures. All story elements begin absent, then arrive back to front:

1. Background scraps settle.
2. Large paper shapes slide in with real friction.
3. Main cut-outs enter and settle with a tiny bounce.
4. Supporting cut-outs drop or pin into place.
5. Tape presses down.
6. Typewritten labels slide in.
7. Rubber stamps strike.
8. Pushpins click into place.
9. Red string pulls naturally between pins.
10. Marker underlines, circles, and arrows draw last.

Move each object once only. Once settled, it never moves again. At exactly 7 seconds, the image must match the supplied reference perfectly.

### 7–10 seconds: hold the finished frame

Do not alter the composition. Permit only minimal tactile life: a tiny paper-corner lift, paper breathing, halftone flicker, print-grain shimmer, one soft string-tension twitch, and subtle shadow breathing. Never change position, scale, rotation, layering, perspective, or composition; add or remove nothing.

## Physics and sound

Use rigid card-stock physics: tiny edge lift, gentle settling, and minimal corner curl only. Forbid elastic, liquid, cloth, and digital deformation.

Use no music, narration, dialogue, or voices. Use only quiet close-up paper ASMR: sliding paper, card movement, tape pressure, muted stamp hits, pushpin clicks, red-string pull, tabletop handling, and soft archive-room ambience.

## Output

Return one complete English video-generation prompt. State that the reference image is the exact final frame, frame matching occurs at second 7, seconds 7–10 preserve only minimal tactile life, and all camera, physics, and composition prohibitions must be honored.
