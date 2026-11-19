# Experimento 3D: Cómo Ahorrar Correctamente en México

Proyecto experimental en `video-studio/proyectos-test/finanzas-mexico-ahorro-3d/` para validar animación **3D en Remotion** usando perspectiva espacial determinista (`perspective`, `preserve-3d`, `rotateX`, `rotateY`, `translateZ`) sin dependencias externas no instaladas.

## Estructura y Skills Aplicadas
- **Perspectiva 3D en Remotion:** Escenario con piso en perspectiva (`rotateX(68deg)`), moneda MXN volumétrica multicapa en eje Z, tarjetas 3D apiladas (`react-bits` / `TiltCard`), pilares 3D extruidos (Inflación vs CETES) y tarjeta *flip* 3D (`rotateY(180deg)`).
- **Composición:** `src/Film.tsx` (5 escenas, 25s / 750 frames a 30 fps, `1080x1920`).

## Comandos
- Stills y hoja de contactos: `node render.mjs --stills`
- Borrador 720p: `node render.mjs --draft`
- Master 1080p: `node render.mjs`
