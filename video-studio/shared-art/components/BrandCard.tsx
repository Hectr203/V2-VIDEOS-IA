import React from 'react';

// Utilidades matemáticas y cinemáticas estándar
const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
const easeInOut = (n: number) => { const t = clamp(n); return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t; };
const mix = (a: number, b: number, p: number) => a + (b - a) * p;
const wave = (f: number, speed = 0.06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
const spring = (t: number) => t <= 0 ? 0 : 1 - Math.exp(-6 * t) * Math.cos(8 * t);

const PRESS_FRAME = 48;

/**
 * Logotipo vectorial canónico oficial de "Un Dato Más"
 * Basado con exactitud en assets/brand-private/logo.png:
 * - Libro abierto: lomo/cubierta verde lima (#d7f36b), páginas interiores crema marfil (#fff8e7).
 * - Estrella superior de 4 puntas (#d7f36b) con respiración y rotación sutil.
 * - 4 destellos orbitales con balance exacto (2 crema superiores, 2 lima laterales).
 * Diseñado con geometría limpia, sin artefactos ni distorsiones.
 */
export function BrandLogoMark({f, build = 1}: {f: number; build?: number}) {
  const page = spring((build * 40 - 6) / 20);
  const cover = ease((build * 40 - 10) / 18);
  const star = spring((build * 40 - 20) / 16);

  return (
    <g>
      {/* Cubierta exterior / lomo del libro en verde lima (#d7f36b) */}
      <g transform={`scale(${cover})`}>
        <path
          d="M -150 -70 Q -145 -78 -135 -74 L -115 -66 L -125 26 Q -50 24 -4 86 Q 0 94 4 86 Q 50 24 125 26 L 115 -66 L 135 -74 Q 145 -78 150 -70 L 162 50 Q 164 58 155 56 Q 62 27 7 96 Q 0 106 -7 96 Q -62 27 -155 56 Q -164 58 -162 50 Z"
          fill="#d7f36b"
        />
        <path
          d="M -135 62 Q -68 47 -15 92 Q -78 64 -137 81 Z M 135 62 Q 68 47 15 92 Q 78 64 137 81 Z"
          fill="#d7f36b"
          opacity="0.9"
        />
      </g>

      {/* Páginas interiores abiertas en crema suave (#fff8e7) */}
      <g transform={`scale(${page} 1)`}>
        <path
          d="M -115 -90 Q -48 -88 -5 -24 V 86 Q -57 16 -125 19 Z M 115 -90 Q 48 -88 5 -24 V 86 Q 57 16 125 19 Z"
          fill="#fff8e7"
        />
      </g>

      {/* Estrella superior de 4 puntas en verde lima con respiración */}
      <g transform={`translate(0 -130) rotate(${mix(-60, 0, clamp(star)) + wave(f, 0.03, 3)}) scale(${star * (0.96 + wave(f, 0.05, 0.04))})`}>
        <path
          d="M 0 -48 Q 5 -7 42 0 Q 5 7 0 52 Q -5 7 -42 0 Q -5 -7 0 -48 Z"
          fill="#d7f36b"
        />
      </g>

      {/* 4 destellos orbitales (2 crema arriba, 2 lima abajo) idénticos a logo.png */}
      <circle cx="-58" cy="-140" r="5.5" fill="#fff8e7" opacity={clamp(star)}/>
      <circle cx="58" cy="-135" r="5.5" fill="#fff8e7" opacity={clamp(star)}/>
      <circle cx="-52" cy="-95" r="5" fill="#d7f36b" opacity={clamp(star)}/>
      <circle cx="52" cy="-90" r="5" fill="#d7f36b" opacity={clamp(star)}/>
    </g>
  );
}

/**
 * Escudo circular oficial con diseño estético UI/UX Pro Max:
 * - Acabado de iluminación perimetral limpia
 * - Sin halos marrones sucios ni múltiples anillos concéntricos
 * - Profundidad de sombra suave y contraste nítido
 */
export function BrandEmblemCircle({f, scale = 1}: {f: number; scale?: number}) {
  const plate = spring(f / 18);
  const floating = wave(f, 0.035, 4);

  return (
    <g transform={`translate(0 ${floating}) scale(${scale})`}>
      {/* Resplandor suave perimetral verde lima (sin halos sucios) */}
      <defs>
        <radialGradient id="emblem-glow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#d7f36b" stopOpacity="0.15"/>
          <stop offset="70%" stopColor="#d7f36b" stopOpacity="0.04"/>
          <stop offset="100%" stopColor="#d7f36b" stopOpacity="0"/>
        </radialGradient>
      </defs>
      <circle r="160" fill="url(#emblem-glow)"/>

      {/* Onda de energía limpia al inicio */}
      {f > 35 && f < 95 && (
        <circle
          r={128 + ((f - 35) / 60) * 32}
          fill="none"
          stroke="#d7f36b"
          strokeWidth="1.5"
          opacity={Math.max(0, 1 - (f - 35) / 60) * 0.4}
        />
      )}

      {/* Placa circular principal: Púrpura profundo (#24122d) con borde pulido en lima */}
      <g transform={`scale(${plate})`}>
        {/* Sombra de elevación */}
        <circle r="126" fill="#140a1a" opacity="0.4" transform="translate(0 8)"/>

        {/* Disco de fondo */}
        <circle
          r="124"
          fill="#25132d"
          stroke="#d7f36b"
          strokeWidth="2.5"
          strokeOpacity="0.8"
        />

        {/* Anillo interior sutil */}
        <circle
          r="114"
          fill="none"
          stroke="#d7f36b"
          strokeWidth="1"
          strokeOpacity="0.2"
          strokeDasharray="4 4"
        />

        {/* Logotipo centrado */}
        <g transform="translate(0 20) scale(0.72)">
          <BrandLogoMark f={f} build={clamp(f / 35)}/>
        </g>
      </g>
    </g>
  );
}

/**
 * Cursor táctil estilizado que interactúa con el botón
 */
function FingerCursor({x, y, press}: {x: number; y: number; press: number}) {
  return (
    <g transform={`translate(${x} ${y}) rotate(-18) scale(${1 - press * 0.1})`}>
      <path
        d="M -7 -46 Q -7 -56 0 -56 Q 7 -56 7 -46 V -10 Q 15 -16 22 -9 Q 29 -14 33 -5 Q 40 -8 42 1 V 22 Q 42 46 18 50 H -4 Q -22 48 -27 31 L -34 8 Q -36 -1 -27 -1 Q -20 -1 -16 8 L -7 15 Z"
        fill="#fff8e7"
        stroke="#24122d"
        strokeWidth="3"
        strokeLinejoin="round"
      />
      <path d="M 7 -10 V 8 M 22 -9 V 10 M 33 -5 V 12" stroke="#24122d" strokeWidth="2" strokeLinecap="round" opacity="0.4"/>
    </g>
  );
}

/**
 * Tarjeta Canónica Reutilizable de Cierre Oficial "Un Dato Más"
 * Rediseñada según los estándares de UI/UX Pro Max:
 * - Sin cintas/tapes skeuomórficas sucias
 * - Borde degradado iluminado y sombra de cristal (Glassmorphism sutil)
 * - Botón "SEGUIR / SIGUIENDO ✓" con tipografía limpia, sin colisión de checkmarks
 * - Espaciado superior/medio (Y: 520) para total aislamiento de subtítulos inferiores
 */
export function BrandUnDatoMasCard({
  f,
  x = 360,
  y = 520,
  scale = 1
}: {
  f: number;
  x?: number;
  y?: number;
  scale?: number;
}) {
  const cardSpring = spring(f / 20);
  const press = clamp(1 - Math.abs(f - PRESS_FRAME) / 5);
  const done = f > PRESS_FRAME + 2;
  const btnScale = 1 - press * 0.08 + (done ? wave(clamp((f - PRESS_FRAME - 2) / 14) * Math.PI, 1, 0.04) : 0);
  const ripple = clamp((f - PRESS_FRAME) / 24);
  const cursorIn = easeInOut((f - 30) / 20);
  const cursorOut = ease((f - PRESS_FRAME - 14) / 18);

  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      <defs>
        {/* Gradiente de borde iluminado premium */}
        <linearGradient id="card-border-gradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#d7f36b" stopOpacity="0.95"/>
          <stop offset="45%" stopColor="#d7f36b" stopOpacity="0.4"/>
          <stop offset="100%" stopColor="#84cc16" stopOpacity="0.2"/>
        </linearGradient>

        {/* Gradiente de fondo oscuro de alta fidelidad */}
        <linearGradient id="card-bg-gradient" x1="0" y1="0" x2="0.3" y2="1">
          <stop offset="0%" stopColor="#281433"/>
          <stop offset="50%" stopColor="#210f2b"/>
          <stop offset="100%" stopColor="#17091e"/>
        </linearGradient>

        {/* Sombra de botón */}
        <filter id="btn-shadow" x="-20%" y="-20%" width="140%" height="150%">
          <feDropShadow dx="0" dy="6" stdDeviation="8" floodColor="#000000" floodOpacity="0.35"/>
        </filter>
      </defs>

      <g transform={`scale(${cardSpring})`}>
        {/* Sombra de elevación de la tarjeta */}
        <rect
          x="-245" y="-315" width="490" height="630" rx="36"
          fill="#0a030e" opacity="0.5" filter="blur(16px)"
        />

        {/* Contenedor principal con acabado de borde biselado */}
        <rect
          x="-240" y="-310" width="480" height="620" rx="32"
          fill="url(#card-bg-gradient)"
          stroke="url(#card-border-gradient)"
          strokeWidth="2.5"
        />

        {/* Delicadas órbitas celestiales de fondo (fieles al banner oficial) */}
        <g stroke="#d7f36b" strokeWidth="1" opacity="0.14" fill="none">
          <ellipse cx="-110" cy="-160" rx="150" ry="75" strokeDasharray="4 6"/>
          <ellipse cx="130" cy="160" rx="170" ry="85" strokeDasharray="4 6"/>
          <circle cx="150" cy="-190" r="3.5" fill="#d7f36b" opacity="0.4"/>
          <circle cx="-150" cy="180" r="3" fill="#fff8e7" opacity="0.4"/>
          <circle cx="-180" cy="-120" r="2" fill="#d7f36b" opacity="0.3"/>
        </g>

        {/* Emblema circular con el logo exacto */}
        <g transform="translate(0 -90)">
          <BrandEmblemCircle f={f} scale={1.05}/>
        </g>

        {/* Bloque Tipográfico Oficial de Banner */}
        <g transform="translate(0 110)">
          {/* "UN DATO" en crema (#fff8e7) + "MAS" en verde lima (#d7f36b) */}
          <text textAnchor="middle" fontSize="38" fontWeight="900" letterSpacing="2.5">
            <tspan fill="#fff8e7">UN DATO </tspan>
            <tspan fill="#d7f36b">MAS</tspan>
          </text>

          {/* Subtítulo oficial: "CURIOSIDADES QUE SORPRENDEN" con badge translúcido */}
          <g transform="translate(0 28)">
            <rect
              x="-150" y="-14" width="300" height="26" rx="13"
              fill="#d7f36b" fillOpacity="0.08"
              stroke="#d7f36b" strokeOpacity="0.2" strokeWidth="1"
            />
            <text x="0" y="4" fill="#fff8e7" fontSize="11" fontWeight="800" textAnchor="middle" letterSpacing="3.5" opacity="0.9">
              CURIOSIDADES QUE SORPRENDEN
            </text>
          </g>
        </g>

        {/* Botón interactivo de seguimiento optimizado con UI/UX Pro Max */}
        <g transform={`translate(0 220) scale(${btnScale})`} filter="url(#btn-shadow)">
          {/* Píldora del botón con verde lima (#d7f36b) de alto impacto */}
          <rect
            x="-135" y="-28" width="270" height="56" rx="28"
            fill="#d7f36b"
            stroke="#ffffff"
            strokeWidth="1.5"
            strokeOpacity="0.4"
          />

          {/* Estado Interactivo: SEGUIR vs SIGUIENDO ✓ sin ninguna colisión tipográfica */}
          {done ? (
            <g transform="translate(0 0)">
              {/* Icono Checkmark verde/berenjena perfectamente posicionado a la izquierda */}
              <g transform="translate(-62 0)">
                <circle cx="0" cy="0" r="13" fill="#24122d"/>
                <path
                  d="M -5 0 L -1 4 L 6 -4"
                  stroke="#d7f36b"
                  strokeWidth="2.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  fill="none"
                />
              </g>
              {/* Texto SIGUIENDO limpio y centrado a la derecha del icono */}
              <text
                x="14" y="6"
                textAnchor="middle"
                fill="#24122d"
                fontSize="17"
                fontWeight="900"
                letterSpacing="1.4"
              >
                SIGUIENDO
              </text>
            </g>
          ) : (
            <g transform="translate(0 0)">
              {/* Icono + a la izquierda */}
              <g transform="translate(-54 0)">
                <circle cx="0" cy="0" r="12" fill="#24122d" fillOpacity="0.15"/>
                <path
                  d="M 0 -6 V 6 M -6 0 H 6"
                  stroke="#24122d"
                  strokeWidth="2.8"
                  strokeLinecap="round"
                />
              </g>
              {/* Texto SEGUIR */}
              <text
                x="12" y="6"
                textAnchor="middle"
                fill="#24122d"
                fontSize="18"
                fontWeight="900"
                letterSpacing="1.8"
              >
                SEGUIR
              </text>
            </g>
          )}

          {/* Onda expansiva limpia al presionar */}
          {ripple > 0 && ripple < 1 && (
            <circle
              cx="0" cy="0"
              r={30 + ripple * 110}
              fill="none"
              stroke="#d7f36b"
              strokeWidth={3 * (1 - ripple)}
              opacity={1 - ripple}
            />
          )}
        </g>

        {/* Cursor táctil animado */}
        {f > 25 && cursorOut < 1 && (
          <g opacity={1 - cursorOut}>
            <FingerCursor
              x={mix(170, 45, cursorIn) + cursorOut * 60}
              y={mix(320, 235, cursorIn) + cursorOut * 70}
              press={press}
            />
          </g>
        )}
      </g>
    </g>
  );
}
