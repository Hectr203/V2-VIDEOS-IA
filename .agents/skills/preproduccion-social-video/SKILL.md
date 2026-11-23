---
name: preproduccion-social-video
description: Flujo integral de preproducción audiovisual con enfoque de Social Media Manager (gestor de redes sociales). Cubre Ideación Guiada desde ideas simples, investigación activa en navegador/web de videos exitosos, análisis de mercado, evaluación de entretenimiento/viabilidad, ingeniería de ganchos 0-3s y estructuración del guion base sin generar el video final.
---

# Preproducción Audiovisual y Estrategia de Redes Sociales

Usar antes de pasar a producción audiovisual para validar ideas, investigar videos exitosos en internet con el navegador, analizar mercado y entretenimiento, diseñar ganchos de 3 capas y estructurar el guion base.

- **Guía completa:** `Agencia_Principal/skills/preproduccion-social-video/SKILL.md`
- **Evaluador narrativo principal (español):**
  `python3 Agencia_Principal/skills/estrategia-narrativa-ganchos-retencion/scripts/evaluar_guion.py --tema "<tema>" --gancho "<gancho>"`
- **Detector de videos outliers (múltiplo sobre mediana):**
  `python3 Agencia_Principal/skills/youtube-strategy-skills/skills/yt-viral/swipe.py <collected.json> --min 2.0`
- **Linter de título y portada:**
  `python3 Agencia_Principal/skills/youtube-strategy-skills/skills/yt-package/title.py --title "<título>" --thumb "<portada>"`
