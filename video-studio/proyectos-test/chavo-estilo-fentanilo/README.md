# El Chavo del 8 — Estilo Fentanilo

Rig vectorial de **El Chavo del 8** dibujado en el estilo artístico del proyecto _Fentanilo: La Llave Química_ —
gradientes cálidos de piel, cinemática inversa (IK) para extremidades, formas orgánicas redondeadas
y animación procedimental sutil.

## Estilo Visual

| Elemento             | Fentanilo (original)  | Chavo (adaptación)            |
| -------------------- | --------------------- | ----------------------------- |
| Piel                 | `#ce804a` → `#e9a05d` | `#fad7bd` → `#c48a6a`         |
| Cabello              | Gradiente oscuro      | `#2a1e14` → `#0f0b08`         |
| Extremidades IK      | Hombro → codo → mano  | Mismo sistema articulado       |
| Sombra               | `feDropShadow`        | Mismo filtro                   |
| Ropa                 | Camisa verde gradiente | Rayas café/crema + tirantes    |
| Fondo                | Radial gradiente       | Radial dorado vecindad         |

## Archivos

- **`src/art.tsx`** — Componentes React/SVG: `Chavo`, `Backdrop`, `ArtDefs`, `ChavoFace`, `Label`, `Spark`
- **`preview.html`** — Visor interactivo a 60fps (controles de pose y emoción)
- **`src/index.ts`** — Reexportaciones

## Poses disponibles

- `idle` — De pie, brazos relajados con balanceo natural
- `seated` — Sentado con el carrito de juguete, junto al barril
- `barrel_peek` — Asomado en el barril
- `eso_eso` — Expresión "¡Eso, eso, eso!" con efecto de impacto

## Emociones

`neutral` · `talk` · `smile` · `crying` · `scared` · `determined`

## Cómo usar

```bash
# Abrir el visor interactivo
open preview.html
```

## Comparación: Estilo Original vs Estilo Fentanilo

El rig original en `el-chavo-del-8/` usa contornos gruesos planos con fill sólido.
Esta versión usa el mismo sistema de gradientes lineales/radiales, filtros de sombra
y cinemática inversa que el proyecto Fentanilo, dando un look más orgánico y premium.
