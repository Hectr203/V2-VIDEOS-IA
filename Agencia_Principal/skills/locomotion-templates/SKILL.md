---
name: locomotion-templates
description: Librería de 61 templates de animación en Remotion (React + TypeScript) organizados en 15 categorías con 6 variantes de estilo visual. Úsala para reutilizar, adaptar o combinar escenas de producto, SaaS, texto cinético, datos, redes sociales, branding, e-commerce, educación y más en producciones de video-studio.
---

# Locomotion Templates (Remotion)

## Objetivo y alcance
Proveer a la agencia y a sus agentes de Remotion una librería local de 61 composiciones modulares `.tsx` listas para copiar, parametrizar mediante props editables o adaptar a producciones en `video-studio` (tanto en `1080x1920` vertical como en `1920x1080` horizontal a 30 fps).

- Consulta la guía y catálogo completo en [`GUIA-LOCOMOTION-TEMPLATES.md`](GUIA-LOCOMOTION-TEMPLATES.md).
- Código fuente de los templates en `src/templates/<template-id>/Composition.tsx`.
- Sistema de variantes visuales en `src/lib/styles.ts` y `src/lib/useStyle.ts` (`getCompositionStyles`).

## Cuándo usar / cuándo no usar
- **Usar cuando:**
  - Se necesite acelerar la creación de escenas de producto, SaaS, métricas/datos, tipografía cinética, tarjetas sociales, comparativas (`before-after`), pasos (`step-explainer`), intros/outros o callouts de UI en Remotion.
  - Se busque una base probada con `spring()` e `interpolate()` deterministas para adaptarla al estilo visual del proyecto (`ui-ux-pro-max`, `impeccable`, `emilkowalski-skills`).
- **No usar como reemplazo de:**
  - Personajes vectoriales 2D articulados con cinemática inversa (usar `animacion-2d-remotion` y `character-animation-engine`).
  - La identidad de marca oficial de un canal cuando el proyecto exija su tarjeta o cierre canónico (por ejemplo, `BrandUnDatoMasCard` en `video-studio/assets/brand-private/BrandCard.tsx`).

## Entradas y requisitos
- Proyecto Remotion 4.x + React + TypeScript (como los generados en `video-studio/projects/<slug>/`).
- Selección de uno o más `template-id` del catálogo en `GUIA-LOCOMOTION-TEMPLATES.md`.
- Props editables del template elegido (títulos, colores, textos, métricas) y variante de estilo (`default`, `brutalist`, `rounded`, `minimal`, `glass`, `neo`).

## Procedimiento
1. **Consultar el catálogo:** Revisar `GUIA-LOCOMOTION-TEMPLATES.md` o `src/templates/index.ts` para identificar los templates más adecuados por categoría y duración base (1s a 5s).
2. **Leer el componente fuente:** Abrir `src/templates/<template-id>/Composition.tsx` junto con `src/lib/useStyle.ts` y `src/lib/styles.ts` si el template importa `getCompositionStyles`.
3. **Copiar y adaptar al proyecto destino:**
   - Copiar el archivo `Composition.tsx` (y `useStyle.ts` / `styles.ts` o sustituir `getCompositionStyles` por los tokens de diseño del proyecto).
   - **Adaptación de relación de aspecto:** Los templates base están pensados para `1920x1080` (30 fps). Al integrarlos en `1080x1920` (vertical), ajustar tamaños tipográficos, paddings, `gap` y disposición (`flexDirection`) para respetar márgenes seguros y evitar solapamiento con subtítulos cinéticos inferiores.
   - **Cumplimiento de estándares de la agencia:** Verificar propiedades directas y determinismo por frame (`useCurrentFrame()`), integrar paletas de `ui-ux-pro-max` / `impeccable`, e incorporar movimiento continuo de cámara o transiciones puente si la escena supera 3 segundos.
4. **Registrar o componer en `Film.tsx`:** Montar el componente adaptado dentro de una `<Sequence>` o escena de `src/Film.tsx` con sus props personalizadas.

## Entrega y validación
- Componente `.tsx` integrado y parametrizado dentro del proyecto de destino.
- Compilación TypeScript limpia (`tsc --noEmit`) y previsualización/stills verificados (`render.mjs --stills` o Remotion Studio) en el formato objetivo (`9:16` y/o `16:9`).

## Recursos, procedencia y mantenimiento
- **Procedencia:** Repositorio `https://github.com/Thedurancode/locomotion-templates.git` (Locomotion, Remotion 4.x + React 19 + TypeScript).
- **Archivos empaquetados localmente:**
  - `src/templates/` (61 composiciones en `.tsx`, más `index.ts`, `registry.ts` y `types.ts`).
  - `src/lib/` (`styles.ts`, `useStyle.ts`).
  - `remotion/` (configuración base de registro y render de referencia).
  - `README.md` y `package.json` originales como referencia técnica.
