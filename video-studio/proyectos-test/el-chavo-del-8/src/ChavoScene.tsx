import React from 'react';
import { AbsoluteFill, useCurrentFrame } from 'remotion';
import { ChavoRig, CHAVO_COLORS, ChavoPose, ChavoMood } from './ChavoRig';
import { wave } from '../../../shared-art/math/motion';

export interface ChavoSceneProps {
  customPose?: ChavoPose;
  customMood?: ChavoMood;
  showAllTransitions?: boolean;
}

/**
 * Ejemplo 1: Réplica idéntica de la imagen de referencia.
 * El Chavo sentado en el piso de la vecindad junto a su barril,
 * sujetando el carrito de juguete rojo con parabrisas celeste.
 */
export const ChavoScene: React.FC<ChavoSceneProps> = ({
  customPose,
  customMood,
  showAllTransitions = false,
}) => {
  const frame = useCurrentFrame();

  let currentPose: ChavoPose = customPose || 'seated_car';
  let currentMood: ChavoMood = customMood || 'neutral';
  let lookX = 0;
  let lookY = 0;

  if (showAllTransitions) {
    const cycle = frame % 360;
    if (cycle < 140) {
      currentPose = 'seated_car';
      currentMood = 'neutral';
      lookX = wave(frame, 0.03, 0.3);
      lookY = 0.1;
    } else if (cycle < 210) {
      currentPose = 'seated_car';
      currentMood = 'talk';
      lookX = wave(frame, 0.05, 0.5);
      lookY = 0;
    } else if (cycle < 290) {
      currentPose = 'eso_eso';
      currentMood = 'smile';
      lookX = 0.4;
      lookY = -0.1;
    } else {
      currentPose = 'pipipipi';
      currentMood = 'crying';
      lookX = 0;
      lookY = 0.2;
    }
  }

  const camSwayX = wave(frame, 0.02, 3);
  const camSwayY = wave(frame, 0.025, 2);

  return (
    <AbsoluteFill
      style={{
        backgroundColor: CHAVO_COLORS.wallOrange,
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <svg
        viewBox="0 0 1080 1920"
        width="100%"
        height="100%"
        style={{
          transform: `translate(${camSwayX}px, ${camSwayY}px)`,
        }}
      >
        <rect x="0" y="0" width="1080" height="1920" fill={CHAVO_COLORS.wallOrange} />

        <radialGradient id="sun-glow" cx="80%" cy="20%" r="65%">
          <stop offset="0%" stopColor="#ffc766" stopOpacity="0.45" />
          <stop offset="100%" stopColor="#f29f2e" stopOpacity="0" />
        </radialGradient>
        <rect x="0" y="0" width="1080" height="1920" fill="url(#sun-glow)" />

        <line x1="0" y1="1160" x2="1080" y2="1160" stroke={CHAVO_COLORS.lineDark} strokeWidth="8" />
        <rect x="0" y="1160" width="1080" height="760" fill={CHAVO_COLORS.floorBrown} />
        <ellipse cx="440" cy="1480" rx="420" ry="75" fill="#000000" opacity="0.22" />

        <ChavoRig
          x={460}
          y={1020}
          scale={2.75}
          f={frame}
          pose={currentPose}
          mood={currentMood}
          showToyCar={true}
          showBarrel={true}
          showBackground={false}
          lookX={lookX}
          lookY={lookY}
        />

        {[...Array(10)].map((_, i) => {
          const px = ((i * 105 + frame * 0.7) % 1040) + 20;
          const py = ((i * 157 - frame * 0.4) % 1800 + 1800) % 1800;
          const alpha = 0.12 + Math.sin(frame * 0.05 + i) * 0.08;
          return (
            <circle
              key={i}
              cx={px}
              cy={py}
              r={2.5 + (i % 2)}
              fill="#ffffff"
              opacity={alpha}
            />
          );
        })}
      </svg>
    </AbsoluteFill>
  );
};
