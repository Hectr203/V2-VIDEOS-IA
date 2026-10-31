---
name: documentary-image-prompts
description: Break a documentary narration into a precise timed beat table and generate one VOXSTAGE archival paper-collage image prompt per beat. Use for documentary storyboards, visual beats, paper-collage frames, or shot-by-shot image prompts.
---

# Documentary Image Prompts

Read `references/style-boards.en.md` and `references/voxstage-visual-system.en.md` before writing prompts. Use `assets/mg-voxstage.webp` by default; switch to another supplied board only when the user explicitly names it. First understand the complete story, then build the beat table, then write prompts. Never expose private reasoning.

## 1. Parse the story

Read the entire script. Identify chronology, events, causality, emotional arc, recurring people, places, objects, visual themes, and transitions. Plan the film rather than illustrating sentences mechanically.

## 2. Build the beat table

Split narration into the smallest visual storytelling units. Each beat communicates one image idea.

- Calculate timecodes at 2.5 spoken words per second.
- Keep a beat to roughly 2–3 seconds or 5–8 words.
- Split long sentences at natural commas, conjunctions, or logical clauses; retain narration verbatim.
- Output beat number, start timecode, end timecode, and exact narration.
- Sanity-check: 30 seconds = 12–15 beats; 1 minute = 22–30; 2 minutes = 45–60; 3 minutes = 70–90; 5 minutes = 115–150.

## 3. Write image prompts

Produce one self-contained paragraph per beat. Do not merge, skip, or repeat beats. Return only the beat table and prompt blocks, without numbered prompts, titles, or explanations.

Choose the strongest documentary visual for the idea, not a literal word-by-word illustration: documents, maps, machines, artifacts, places, newspapers, portraits, evidence, financial records, government files, or a clear visual metaphor.

### Composition rules

- Let one subject fill roughly 70% of the composition; use at most 2–3 supporting elements.
- Preserve generous negative space and unmistakable hierarchy.
- Use a single 1–4 word verified archive label only when the beat contains a date, name, place, number, or organization; otherwise use no readable text.
- Include the complete style block and ending block from `references/style-block.en.md` in every prompt.

## Final check

Confirm one-to-one beat coverage, cumulative timecodes, one image idea per prompt, and complete VOXSTAGE style and ending blocks in every prompt.
