---
name: animacion-2d-remotion
description: Diseño y animación vectorial 2D en Remotion y SVG con cinemática inversa, dinámicas de personajes, transiciones, física y tipografía cinética.
---

# Animación Vectorial 2D en Remotion

## Objetivo y alcance
Definir los patrones técnicos y matemáticos para construir animaciones vectoriales de grado profesional en React + Remotion usando únicamente SVG, sin assets rasterizados ni bibliotecas pesadas de animación física externa. Diseñado para videos explicativos verticales (1080×1920) u horizontales (1920×1080).

## Cuándo usar / cuándo no usar
- **Usar cuando:** Se requiera explicar conceptos complejos (médicos, científicos, tecnológicos, IA, económicos) con personajes articulados, metáforas mecánicas o diagramas biológicos en alta fidelidad.
- **No usar cuando:** Se requiera captura de pantalla de software real, metraje de acción real o renderizado 3D poligonal (Three.js/Blender).

## Entradas y requisitos
- Entorno Remotion configurado (`@remotion/cli`, `remotion`, `react`, `react-dom`).
- TypeScript estricto con JSX habilitado.
- Fuentes vectoriales importadas vía `@remotion/bundler` o tipografía de sistema/web font empaquetada.

---

## 1. Biblioteca Matemática Base (`art.tsx`)

Toda composición vectorial debe implementar las siguientes funciones deterministas libres de estado para calcular interpolaciones basadas en el número de frame (`f: number`):

```typescript
// Clamp: Delimita el valor entre un rango mínimo y máximo
export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));

// Ease: Interpolación cúbica smoothstep (3t^2 - 2t^3)
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };

// Mix: Interpolación lineal (lerp)
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;

// Wave: Oscilación sinusoidal con velocidad, amplitud y desfase
export const wave = (f: number, speed = .06, amount = 1, phase = 0) => 
  Math.sin(f * speed + phase) * amount;

// Seeded: Pseudo-aleatoriedad determinista a partir de un entero
export const seeded = (n: number) => { 
  const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; 
  return a - Math.floor(a); 
};
```

---

## 2. Cinemática Inversa para Rigging de Personajes (IK)

Para articular brazos y piernas de dos segmentos de forma natural sin romper las articulaciones (codos/rodillas), usar la resolución trigonométrica de cinemática inversa en 2D:

```typescript
type Point = { x: number; y: number };

export function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx = b.x - a.x, dy = b.y - a.y;
  const d = clamp(Math.hypot(dx, dy), 1, l1 + l2 - 0.01);
  const angle = Math.atan2(dy, dx) + bend * Math.acos(clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1));
  return {
    x: a.x + Math.cos(angle) * l1,
    y: a.y + Math.sin(angle) * l1
  };
}
```

### Reglas para el Personaje Articulado:
1. **Respiración**: Aplicar un factor de escala vertical continuo al torso:
   `scale(1, 1 + wave(f, 0.075, 0.009))`
2. **Parpadeo estocástico**: Ojos con parpadeo suave cada ~130 frames:
   `const blink = f % 133 > 125 ? clamp(Math.abs(f % 133 - 129) / 4) : 1;`
3. **Física del Cabello con Retardo (Trailing Phase)**: Los mechones deben oscilar con un desfase temporal respecto al movimiento de la cabeza (`f - 8` o `f - 6`).
4. **Poses emocionales**: Definir estados claros: `idle`, `pain`, `float`, `relief`, `faint`, adaptando cejas, boca y orientación de extremidades.

---

## 3. Elementos Anatómicos y Metáforas Visuales Complejas

### A. Neuronas y Redes de Impulsos:
- Axones curvados con SVG Bézier cúbica (`C` y `S`).
- Pulsos de acción que viajan por el axón calculados por fase modular:
  `const phase = ((f * 1.6 + i * 17) % 110) / 110;`
  `cx={mix(startX, endX, phase)} opacity={Math.sin(phase * Math.PI)}`

### B. Receptores, Cerraduras y Moléculas (o Procesos de IA):
- Formas geométricas con gradientes radiales (`url(#bg-...)` o `url(#aura)`).
- Luces y auras que reaccionan a la activación:
  `<circle r="180" fill="url(#aura)" opacity={activation} />`

### C. Órganos Biológicos Reactivos:
- Pulmones y corazón con volumen reactivo al ritmo de respiración:
  `const breath = stopped ? 0 : Math.sin(f * 0.065 * (1 - slow * 0.65)) * 0.037 * (1 - slow);`
- Trazo electrocardiográfico (ECG) o de pulso que se aplana progresivamente cuando el ritmo decae.

---

## 4. Subtítulos Cinéticos Sincronizados

Para evitar saltos de línea bruscos o desbordamiento de palabras en español:
1. Agrupar palabras de forma greedy con límite de caracteres (~30-35 caracteres por grupo).
2. Resaltar la palabra actual con fondo translúcido y color de acento.
3. Aplicar una pequeña animación de rebote (`translateY` con `ease`) al entrar cada grupo de palabras.

```typescript
export function Captions({scene, f}: {scene: Scene; f: number}) {
  const time = f / 30;
  const words = scene.words;
  let current = words.findIndex(w => time >= w.start && time < w.end);
  if (current < 0) current = Math.max(0, words.findIndex(w => w.start > time) - 1);
  if (time >= words[words.length - 1].end) current = words.length - 1;

  const groups: {word: string; start: number; end: number}[][] = [];
  for (const word of words) {
    const last = groups[groups.length - 1];
    if (!last || last.length >= 5 || last.map(w => w.word).join(' ').length + word.word.length > 30) {
      groups.push([word]);
    } else {
      last.push(word);
    }
  }
  const active = words[current];
  const group = groups.find(g => g.includes(active)) || groups[0];
  const pop = ease((time - group[0].start) * 12);

  return (
    <div style={{
      position: 'absolute', left: 48, top: 174, width: 624, textAlign: 'center',
      fontSize: 35, lineHeight: 1.32, fontWeight: 750, letterSpacing: -0.6,
      transform: `translateY(${mix(6, 0, pop)}px)`, color: '#fff8f1'
    }}>
      {group.map((w, i) => (
        <span key={`${w.start}-${i}`} style={{
          display: 'inline-block', padding: '2px 7px', margin: '1px 0', borderRadius: 8,
          background: w === active ? 'rgba(25,18,52,0.66)' : 'transparent',
          color: w === active ? '#fff8bb' : '#fff9ef',
          opacity: time >= w.start ? 1 : 0.58
        }}>{w.word} </span>
      ))}
    </div>
  );
}
```

---

## 5. Dinámica de Cámara y Transición entre Escenas

1. **Movimiento sutil de cámara**: Toda escena debe tener un zoom continuo imperceptible para evitar estatismo:
   `const camera = 1 + ease(f / scene.frames) * 0.018;`
   `<g transform={'translate(360 730) scale(' + camera + ') translate(-360 -730)'}>`
2. **Fundido suave (Cross-fade / Cut)**:
   `const fade = scene.id === 'rescue' ? 1 : ease((scene.frames - f) / 7);`

---

## Entrega y validación
- El archivo `art.tsx` contiene los componentes modulares y el archivo `Film.tsx` realiza la composición y montaje secuencial.
- Validar siempre con TypeScript (`tsc --noEmit`).
