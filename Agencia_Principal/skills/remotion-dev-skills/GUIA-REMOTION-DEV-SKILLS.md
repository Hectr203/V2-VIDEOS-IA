# Suite de Habilidades Oficiales de Remotion (remotion-dev/skills)

Esta suite contiene las 12 habilidades oficiales de **Remotion** (`remotion-dev/skills`), desarrolladas y mantenidas por el equipo de Remotion para optimizar la construcción, animación, subtitulado, previsualización en Studio y renderizado de videos programáticos en React.

---

## 1. Catálogo de Habilidades Remotion Oficiales (12 Skills)

| Habilidad | Carpeta | Propósito Principal |
| :--- | :--- | :--- |
| **remotion-best-practices** | `skills/remotion-best-practices/SKILL.md` | Router maestro de buenas prácticas de Remotion; previsualización en Studio antes de renderizar y extracción de componentes hoja. |
| **remotion-markup** | `skills/remotion-markup/SKILL.md` | Estándares de JSX/CSS: `scale`/`translate`/`rotate` directos, `output: 'perceptual-scale'`, `Easing.bezier()` y `Easing.spring()`, evitación de CSS transitions y aislamiento de `useCurrentFrame()`. |
| **remotion-captions** | `skills/remotion-captions/SKILL.md` | Transcripción, sincronización y animación cinética de subtítulos con `@remotion/captions` y archivos SRT. |
| **remotion-studio** | `skills/remotion-studio/SKILL.md` | Flujo de trabajo y previsualización interactiva en Remotion Studio (`npx remotion studio --no-open`). |
| **remotion-render** | `skills/remotion-render/SKILL.md` | Exportación optimizada de video MP4/WebM, canales alfa transparentes, concurrencia, CRF y telemetría. |
| **remotion-create** | `skills/remotion-create/SKILL.md` | Creación y scaffolding de proyectos y composiciones con dimensiones y layouts correctos. |
| **remotion-interactivity** | `skills/remotion-interactivity/SKILL.md` | Estructuración de timelines y componentes con props editables e interactividad en Studio. |
| **remotion-maps** | `skills/remotion-maps/SKILL.md` | Mapas animados, rutas geográficas, integración con MapLibre, MapTiler, Cesium 3D y GeoJSON. |
| **remotion-multimedia** | `skills/remotion-multimedia/SKILL.md` | Manejo multimedia con Mediabunny: dimensiones exactas, duración de audio/video y recorte en navegador/Node. |
| **remotion-docs** | `skills/remotion-docs/SKILL.md` | Búsqueda y referencia directa a la documentación oficial de Remotion. |
| **remotion-saas** | `skills/remotion-saas/SKILL.md` | Arquitectura de renderizado en la nube, APIs y automatización masiva con Remotion. |
| **remotion-upgrade** | `skills/remotion-upgrade/SKILL.md` | Protocolo para actualización consistente de dependencias `@remotion/*` sin romper versiones. |

---

## 2. Reglas de Oro Técnicas para Videos en Remotion

1. **Aislamiento de `useCurrentFrame()` en componentes hoja:**
   - Mantener `useCurrentFrame()` en los componentes visuales más pequeños que lo requieran (títulos, capas de audio, overlays).
   - Nunca suscribir el contenedor raíz o la composición completa a `useCurrentFrame()`, para evitar re-renders innecesarios del árbol de componentes.

2. **Propiedades CSS Directas sobre `transform` complejo:**
   - Usar propiedades directas `scale`, `translate`, `rotate` en lugar de strings `transform: "scale(...) translate(...)"`.
   - Al animar escala o zoom, configurar obligatoriamente `{ output: 'perceptual-scale' }` en `interpolate()` para mantener aceleración perceptualmente constante.

3. **Cero animaciones CSS impuras:**
   - Totalmente prohibidas las clases de animación de Tailwind (`animate-*`) o transiciones CSS (`transition: all`), temporizadores `setTimeout` o `requestAnimationFrame`. Todo debe derivarse determinísticamente del frame (`f`).

4. **Curvas de Aceleración y Resortes:**
   - Usar `Easing.bezier()` y `Easing.spring()` para movimientos orgánicos en entradas, impactos y transiciones.

5. **Flujo de Previsualización en Studio:**
   - Abrir Remotion Studio (`npx remotion studio --no-open`) para inspección visual continua antes de disparar renders definitivos en disco.
