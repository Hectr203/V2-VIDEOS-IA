import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';

// 1. Escena 1: Silueta humana con cerebro brillante y ondas electromagnéticas
export const Scene1HookRig: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const pulse = Math.sin(frame * 0.12) * 6;
  const brainGlow = interpolate(Math.sin(frame * 0.15), [-1, 1], [0.3, 0.9]);
  const waveRadius = (frame * 3) % 180 + 50;
  const waveOpacity = interpolate(waveRadius, [50, 230], [0.8, 0], { extrapolateRight: 'clamp' });

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%" style={{ overflow: 'visible' }}>
      <defs>
        <radialGradient id="brainPulse" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#22d3ee" stopOpacity={brainGlow} />
          <stop offset="100%" stopColor="#0284c7" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Ondas cerebrales */}
      <circle cx="400" cy="360" r={waveRadius} fill="none" stroke="#38bdf8" strokeWidth="4" opacity={waveOpacity} />
      <circle cx="400" cy="360" r={(waveRadius + 80) % 180 + 50} fill="none" stroke="#22d3ee" strokeWidth="3" opacity={waveOpacity * 0.8} />

      {/* Silueta de Cabeza / Rostro humano de perfil */}
      <g transform={`scale(${1 + pulse * 0.005})`} transform-origin="400 450">
        <path
          d="M 330 650 L 330 520 C 330 520 280 500 270 420 C 260 350 280 290 330 240 C 380 190 460 190 510 230 C 560 270 580 340 570 420 C 560 480 520 520 500 530 L 500 650 Z"
          fill="#1e293b"
          stroke="#38bdf8"
          strokeWidth="8"
          strokeLinejoin="round"
        />

        {/* Resplandor del Cerebro */}
        <circle cx="420" cy="340" r="130" fill="url(#brainPulse)" />

        {/* Circunvoluciones del Cerebro dibujadas a mano */}
        <path
          d="M 360 340 Q 380 300 420 310 Q 460 300 480 330 Q 500 370 470 400 Q 440 430 400 420 Q 360 410 350 370 Z"
          fill="#0ea5e9"
          fillOpacity="0.4"
          stroke="#e0f2fe"
          strokeWidth="6"
          strokeLinecap="round"
        />
        <path
          d="M 390 330 Q 420 350 440 330 M 370 370 Q 410 380 440 360 Q 460 380 430 400"
          fill="none"
          stroke="#ffffff"
          strokeWidth="5"
          strokeLinecap="round"
        />

        {/* Partículas flotantes de placer/estímulo */}
        {[0, 1, 2, 3, 4].map((i) => {
          const y = 340 + Math.sin(frame * 0.1 + i * 1.3) * 60;
          const x = 420 + Math.cos(frame * 0.12 + i * 1.5) * 70;
          return <circle key={i} cx={x} cy={y} r={5 + (i % 3) * 2} fill="#fde047" />;
        })}
      </g>
    </svg>
  );
};

// 2. Escena 2 y 3: Personaje con Balanza Basculante (Dolor vs Placer)
export const Scene2BalanzaRig: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Animación de resorte basculante
  const tilt = interpolate(Math.sin(frame * 0.08), [-1, 1], [-18, 18]);
  const leftPanY = -tilt * 4.5;
  const rightPanY = tilt * 4.5;

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Base de la Balanza */}
      <path d="M 380 620 L 420 620 L 405 320 L 395 320 Z" fill="#475569" stroke="#0f172a" strokeWidth="6" />
      <path d="M 320 650 L 480 650 L 450 620 L 350 620 Z" fill="#334155" stroke="#0f172a" strokeWidth="6" />
      <circle cx="400" cy="320" r="16" fill="#f59e0b" stroke="#0f172a" strokeWidth="5" />

      {/* Viga basculante que rota dinámicamente */}
      <g transform={`rotate(${tilt}, 400, 320)`}>
        <rect x="180" y="314" width="440" height="12" rx="6" fill="#f59e0b" stroke="#0f172a" strokeWidth="5" />

        {/* Gancho izquierdo */}
        <circle cx="200" cy="320" r="8" fill="#d97706" />
        {/* Gancho derecho */}
        <circle cx="600" cy="320" r="8" fill="#d97706" />
      </g>

      {/* Platillo Izquierdo (DOLOR) */}
      <g transform={`translate(0, ${leftPanY})`}>
        <line x1="200" y1="320" x2="150" y2="440" stroke="#94a3b8" strokeWidth="4" strokeDasharray="6,4" />
        <line x1="200" y1="320" x2="250" y2="440" stroke="#94a3b8" strokeWidth="4" strokeDasharray="6,4" />
        <path d="M 130 440 Q 200 480 270 440 Z" fill="#ef4444" stroke="#7f1d1d" strokeWidth="6" />
        {/* Rayo de dolor */}
        <path d="M 195 380 L 185 410 L 205 410 L 195 435" stroke="#fef08a" strokeWidth="5" fill="none" strokeLinecap="round" />
        <text x="200" y="520" textAnchor="middle" fill="#fca5a5" fontFamily="Impact, sans-serif" fontSize="36">DOLOR</text>
      </g>

      {/* Platillo Derecho (PLACER) */}
      <g transform={`translate(0, ${rightPanY})`}>
        <line x1="600" y1="320" x2="550" y2="440" stroke="#94a3b8" strokeWidth="4" strokeDasharray="6,4" />
        <line x1="600" y1="320" x2="650" y2="440" stroke="#94a3b8" strokeWidth="4" strokeDasharray="6,4" />
        <path d="M 530 440 Q 600 480 670 440 Z" fill="#10b981" stroke="#064e3b" strokeWidth="6" />
        {/* Cara sonriente / dopamina */}
        <circle cx="600" cy="405" r="22" fill="#fde047" stroke="#854d0e" strokeWidth="4" />
        <circle cx="593" cy="400" r="3" fill="#854d0e" />
        <circle cx="607" cy="400" r="3" fill="#854d0e" />
        <path d="M 592 413 Q 600 422 608 413" stroke="#854d0e" strokeWidth="3" fill="none" />
        <text x="600" y="520" textAnchor="middle" fill="#6ee7b7" fontFamily="Impact, sans-serif" fontSize="36">PLACER</text>
      </g>
    </svg>
  );
};

// 3. Escena 4 y 6: Llave entrando en la Cerradura Neuronal
export const Scene4LockAndKeyRig: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // La llave viaja hacia la derecha y luego rota dentro del ojo de la cerradura
  const keyX = interpolate(frame, [0, 25], [140, 360], { extrapolateRight: 'clamp' });
  const keyRotate = interpolate(frame, [25, 45], [0, -90], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const burstScale = interpolate(frame, [35, 55], [0, 1.4], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
  const burstOpacity = interpolate(frame, [35, 55], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Destello de activación al encajar */}
      {frame >= 35 && (
        <circle cx="480" cy="400" r={burstScale * 120} fill="none" stroke="#38bdf8" strokeWidth="8" opacity={burstOpacity} />
      )}

      {/* Cerradura / Receptor Neuronal (Forma orgánica celular) */}
      <g transform="translate(480, 400)">
        {/* Membrana biológica */}
        <path
          d="M -10 -150 C 90 -160 160 -90 170 0 C 160 90 90 160 -10 150 C -40 140 -80 110 -80 0 C -80 -110 -40 -140 -10 -150 Z"
          fill="#312e81"
          stroke="#6366f1"
          strokeWidth="10"
        />
        {/* Hueco de la cerradura exacto */}
        <circle cx="0" cy="-25" r="28" fill="#0f172a" stroke="#818cf8" strokeWidth="5" />
        <path d="M -16 -10 L 16 -10 L 24 50 L -24 50 Z" fill="#0f172a" stroke="#818cf8" strokeWidth="5" />
      </g>

      {/* Llave Química Móvil (Rigged Key) */}
      <g transform={`translate(${keyX}, 400) rotate(${keyRotate})`}>
        {/* Cabeza de la llave */}
        <circle cx="-100" cy="0" r="45" fill="#f59e0b" stroke="#78350f" strokeWidth="8" />
        <circle cx="-100" cy="0" r="20" fill="#0f172a" stroke="#78350f" strokeWidth="6" />

        {/* Eje de la llave */}
        <rect x="-55" y="-12" width="120" height="24" rx="6" fill="#fbbf24" stroke="#78350f" strokeWidth="7" />

        {/* Dientes de la llave (dientes moleculares) */}
        <rect x="25" y="12" width="18" height="26" fill="#fbbf24" stroke="#78350f" strokeWidth="6" />
        <rect x="50" y="12" width="16" height="36" fill="#fbbf24" stroke="#78350f" strokeWidth="6" />
      </g>
    </svg>
  );
};

// 4. Escena 12: Taza de café con vapor animado ondulante
export const Scene12CoffeeRig: React.FC = () => {
  const frame = useCurrentFrame();

  const wave1 = Math.sin(frame * 0.1) * 15;
  const wave2 = Math.cos(frame * 0.08) * 18;
  const wave3 = Math.sin(frame * 0.12 + 1) * 14;

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Taza */}
      <g transform="translate(400, 520)">
        {/* Plato base */}
        <ellipse cx="0" cy="90" rx="190" ry="32" fill="#334155" stroke="#0f172a" strokeWidth="8" />
        {/* Asa de la taza */}
        <path d="M 120 -20 C 190 -20 190 70 120 70" fill="none" stroke="#f59e0b" strokeWidth="22" strokeLinecap="round" />
        {/* Cuerpo taza */}
        <path d="M -130 -40 L -100 80 C -100 80 0 100 100 80 L 130 -40 Z" fill="#d97706" stroke="#0f172a" strokeWidth="9" />
        {/* Interior con café caliente */}
        <ellipse cx="0" cy="-40" rx="130" ry="25" fill="#451a03" stroke="#0f172a" strokeWidth="8" />
        <ellipse cx="0" cy="-40" rx="100" ry="18" fill="#78350f" />
      </g>

      {/* Líneas de Vapor Ondulantes estilo Cartoon/Doodle */}
      <g stroke="#ffffff" strokeWidth="8" fill="none" strokeLinecap="round" opacity="0.85">
        <path d={`M 360 440 Q ${340 + wave1} 360 370 280 T ${350 + wave2} 180`} />
        <path d={`M 400 440 Q ${420 + wave2} 340 390 260 T ${410 + wave3} 160`} />
        <path d={`M 440 440 Q ${430 + wave3} 360 450 270 T ${430 + wave1} 170`} />
      </g>

      {/* Partículas de aroma / estrellas */}
      {[0, 1, 2].map((i) => {
        const y = 200 - ((frame * 2 + i * 80) % 200);
        const x = 380 + Math.sin(frame * 0.05 + i) * 60;
        return <polygon key={i} points={`${x},${y-8} ${x+3},${y-2} ${x+9},${y} ${x+3},${y+2} ${x},${y+8} ${x-3},${y+2} ${x-9},${y} ${x-3},${y-2}`} fill="#fde047" />;
      })}
    </svg>
  );
};

// 5. Escena 16 y 18: Pulmones y Parada Respiratoria
export const Scene16LungsRig: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Expansión rítmica de respiración
  const lungScale = 1 + Math.sin(frame * 0.16) * 0.08;
  const heartBeat = (frame * 6) % 600;

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Tráquea */}
      <path d="M 400 200 L 400 340" stroke="#94a3b8" strokeWidth="24" strokeLinecap="round" />
      {/* Bronquios */}
      <path d="M 400 340 L 330 420 M 400 340 L 470 420" stroke="#94a3b8" strokeWidth="18" strokeLinecap="round" />

      {/* Pulmón Izquierdo */}
      <g transform={`translate(280, 470) scale(${lungScale})`} transform-origin="0 0">
        <path
          d="M 30 -100 C -70 -70 -90 40 -60 110 C -40 160 30 170 60 110 C 80 70 70 -50 30 -100 Z"
          fill="#f43f5e"
          stroke="#881337"
          strokeWidth="10"
        />
      </g>

      {/* Pulmón Derecho */}
      <g transform={`translate(520, 470) scale(${lungScale})`} transform-origin="0 0">
        <path
          d="M -30 -100 C 70 -70 90 40 60 110 C 40 160 -30 170 -60 110 C -80 70 -70 -50 -30 -100 Z"
          fill="#f43f5e"
          stroke="#881337"
          strokeWidth="10"
        />
      </g>

      {/* Línea de monitor cardíaco ECG inferior */}
      <g transform="translate(100, 680)">
        <line x1="0" y1="0" x2="600" y2="0" stroke="#334155" strokeWidth="4" />
        <path
          d="M 0 0 L 180 0 L 200 -25 L 220 30 L 240 -40 L 260 15 L 280 0 L 600 0"
          stroke="#22c55e"
          strokeWidth="6"
          fill="none"
          strokeLinejoin="round"
        />
        <circle cx={heartBeat} cy="0" r="6" fill="#86efac" />
      </g>
    </svg>
  );
};

// 6. Escena 8 y 9: Endorfinas naturales vs molécula masiva
export const Scene8EndorphinsRig: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Criaturas endorfinas sonrientes flotando suavemente */}
      {[
        { x: 260, y: 380, delay: 0, color: '#38bdf8' },
        { x: 520, y: 340, delay: 1.5, color: '#34d399' },
        { x: 390, y: 490, delay: 3, color: '#a78bfa' },
      ].map((endo, idx) => {
        const floatY = Math.sin(frame * 0.1 + endo.delay) * 15;
        const floatR = Math.cos(frame * 0.08 + endo.delay) * 8;
        return (
          <g key={idx} transform={`translate(${endo.x}, ${endo.y + floatY}) rotate(${floatR})`}>
            {/* Cuerpo de gota/molécula redonda */}
            <circle cx="0" cy="0" r="48" fill={endo.color} stroke="#0f172a" strokeWidth="7" />
            {/* Ojos */}
            <circle cx="-16" cy="-8" r="6" fill="#0f172a" />
            <circle cx="16" cy="-8" r="6" fill="#0f172a" />
            {/* Sonrisa feliz */}
            <path d="M -15 12 Q 0 26 15 12" fill="none" stroke="#0f172a" strokeWidth="5" strokeLinecap="round" />
            {/* Mejillas sonrojadas */}
            <circle cx="-24" cy="8" r="8" fill="#fda4af" opacity="0.7" />
            <circle cx="24" cy="8" r="8" fill="#fda4af" opacity="0.7" />
          </g>
        );
      })}
      <text x="400" y="660" textAnchor="middle" fill="#7dd3fc" fontFamily="Impact, sans-serif" fontSize="42">ENDORFINAS NATURALES</text>
    </svg>
  );
};

// 7. Escena 10 y 11: Fentanilo - La Llave Falsa 100x Morfina
export const Scene10FakeKeyRig: React.FC = () => {
  const frame = useCurrentFrame();

  const shake = Math.sin(frame * 0.4) * 4;
  const auraGlow = 1 + Math.sin(frame * 0.2) * 0.06;

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      <g transform={`translate(${400 + shake}, 380) scale(${auraGlow})`}>
        {/* Resplandor radiactivo de peligro */}
        <circle cx="0" cy="0" r="220" fill="none" stroke="#ef4444" strokeWidth="8" strokeDasharray="14,10" opacity="0.6" />

        {/* Llave amenazante con espinas y cabeza calavera/tóxica */}
        {/* Mango */}
        <circle cx="-140" cy="0" r="65" fill="#dc2626" stroke="#450a0a" strokeWidth="10" />
        <circle cx="-140" cy="0" r="30" fill="#18181b" stroke="#450a0a" strokeWidth="7" />

        {/* Vástago de la llave */}
        <rect x="-80" y="-18" width="220" height="36" rx="8" fill="#ef4444" stroke="#450a0a" strokeWidth="9" />

        {/* Dientes afilados múltiples */}
        <path d="M 40 18 L 60 75 L 80 18 Z" fill="#b91c1c" stroke="#450a0a" strokeWidth="7" />
        <path d="M 90 18 L 110 95 L 130 18 Z" fill="#b91c1c" stroke="#450a0a" strokeWidth="7" />

        {/* Rayos y chispas */}
        <path d="M -20 -40 L 0 -80 L 15 -50 L 40 -90" stroke="#fef08a" strokeWidth="6" fill="none" strokeLinecap="round" />
      </g>

      {/* Sello de advertencia 100X */}
      <g transform="translate(400, 640)">
        <rect x="-190" y="-45" width="380" height="90" rx="16" fill="#991b1b" stroke="#f87171" strokeWidth="6" />
        <text x="0" y="16" textAnchor="middle" fill="#ffffff" fontFamily="Impact, sans-serif" fontSize="52" letterSpacing="3">100X MORFINA</text>
      </g>
    </svg>
  );
};

// 8. Escena 17: Granos de Sal (2 mg que pesan nada)
export const Scene17SaltGrainsRig: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <svg viewBox="0 0 800 800" width="100%" height="100%">
      {/* Yema del dedo doodle sosteniendo los granos */}
      <g transform="translate(400, 480)">
        {/* Silueta dedo */}
        <path
          d="M -120 220 L -100 0 C -90 -120 90 -120 100 0 L 120 220 Z"
          fill="#fbcfe8"
          stroke="#475569"
          strokeWidth="10"
        />
        {/* Huella dactilar orgánica */}
        <ellipse cx="0" cy="-30" rx="40" ry="50" fill="none" stroke="#f472b6" strokeWidth="4" opacity="0.6" strokeDasharray="10,6" />

        {/* Solo 3 granitos minúsculos de sal brillando en la punta */}
        <rect x="-25" y="-105" width="16" height="16" rx="3" fill="#ffffff" stroke="#0f172a" strokeWidth="3" transform={`rotate(${frame * 2}, -17, -97)`} />
        <rect x="5" y="-115" width="18" height="18" rx="3" fill="#ffffff" stroke="#0f172a" strokeWidth="3" transform={`rotate(-${frame * 1.5}, 14, -106)`} />
        <rect x="-10" y="-130" width="14" height="14" rx="2" fill="#ffffff" stroke="#0f172a" strokeWidth="3" />

        {/* Resplandor focal */}
        <circle cx="0" cy="-115" r="50" fill="#38bdf8" opacity={0.25 + Math.sin(frame * 0.2) * 0.15} />
      </g>

      <g transform="translate(400, 200)">
        <text x="0" y="0" textAnchor="middle" fill="#f87171" fontFamily="Impact, sans-serif" fontSize="72">SOLO 2 mg</text>
        <text x="0" y="50" textAnchor="middle" fill="#94a3b8" fontFamily="sans-serif" fontWeight="bold" fontSize="30">Unos granos de sal</text>
      </g>
    </svg>
  );
};
