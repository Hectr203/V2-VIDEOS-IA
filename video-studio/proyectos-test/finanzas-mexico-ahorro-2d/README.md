# Experimento 2D: Cómo Ahorrar Correctamente en México

Proyecto experimental en `video-studio/proyectos-test/finanzas-mexico-ahorro-2d/` para validar animación **2D en Remotion** aplicando `locomotion-templates` y las skills de diseño de `Agencia_Principal`.

## Estructura y Skills Aplicadas
- **Locomotion Templates:** Adaptación vertical (`1080x1920`, 30 fps) de patrones de `StepExplainer` (Regla 50/30/20), `BarChartReveal` (CETES vs Inflación), `BeforeAfter` (Gastos Hormiga) y `SaasHero`/`MetricCard`.
- **Arte Vectorial 2D:** Moneda MXN SVG con gradientes radiales/lineales y respiración orgánica, fondo editorial animado y subtítulos cinéticos.
- **Composición:** `src/Film.tsx` (5 escenas, 25s / 750 frames).

## Comandos
- Stills y hoja de contactos: `node render.mjs --stills`
- Borrador 720p: `node render.mjs --draft`
- Master 1080p: `node render.mjs`
