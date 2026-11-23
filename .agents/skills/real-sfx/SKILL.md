---
name: real-sfx
description: Analiza videos renderizados o listas de cues para detectar momentos visuales que requieren sonido y colocar efectos reales de la librería local (video-studio/assets/sfx + uisfx CC0) en el fotograma exacto, respetando la voz y la música con auto-ducking y autocrítica acústica.
---

# Real SFX (Sincronización Frame-a-Frame con Efectos Reales)

- **Guía completa:** `Agencia_Principal/skills/audio-pro-skills/real-sfx/SKILL.md`
- **Verificación rápida:** `cd Agencia_Principal/skills/audio-pro-skills/real-sfx && python3 scripts/setup.py check`
- **Flujo típico:** `look.py` → `find_moments.py` / `from_cues.py` → `mix.py --voice-safe --duck` → `critique.py` → `levels.py`
