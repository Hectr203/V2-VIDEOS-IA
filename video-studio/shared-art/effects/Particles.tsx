import React from 'react';
import { wave, seeded, clamp } from '../math/motion';

export interface ParticleFieldProps {
  f: number;
  width?: number;
  height?: number;
  count?: number;
  color?: string;
  seed?: number;
}

export const FloatingDust: React.FC<ParticleFieldProps> = ({
  f,
  width = 1080,
  height = 1920,
  count = 24,
  color = '#ffffff',
  seed = 42
}) => {
  return (
    <g opacity="0.45">
      {Array.from({ length: count }).map((_, i) => {
        const sx = seeded(seed + i * 13.7) * width;
        const sy = seeded(seed + i * 29.3) * height;
        const speed = 0.4 + seeded(seed + i * 7.1) * 0.8;
        const currentY = (sy - f * speed + height) % height;
        const drift = wave(f + i * 20, 0.03, 16);
        const r = 1.2 + seeded(seed + i * 5.5) * 2.2;
        const alpha = 0.2 + Math.abs(wave(f + i * 15, 0.04, 0.5));

        return (
          <circle
            key={i}
            cx={sx + drift}
            cy={currentY}
            r={r}
            fill={color}
            opacity={alpha}
          />
        );
      })}
    </g>
  );
};

export const SparkBurst: React.FC<{
  x: number;
  y: number;
  f: number;
  burstFrame?: number;
  color?: string;
  count?: number;
}> = ({ x, y, f, burstFrame = 0, color = '#ffe35f', count = 12 }) => {
  const age = Math.max(0, f - burstFrame);
  if (age > 25) return null;
  const progress = age / 25;
  const radius = progress * 95;
  const opacity = 1 - progress;

  return (
    <g transform={`translate(${x} ${y})`}>
      {Array.from({ length: count }).map((_, i) => {
        const angle = (i * 2 * Math.PI) / count + seeded(i) * 0.3;
        const px = Math.cos(angle) * radius;
        const py = Math.sin(angle) * radius;
        const sparkLength = (1 - progress) * 8 + 2;

        return (
          <line
            key={i}
            x1={px * 0.7}
            y1={py * 0.7}
            x2={px}
            y2={py}
            stroke={color}
            strokeWidth={sparkLength * 0.4}
            strokeLinecap="round"
            opacity={opacity}
          />
        );
      })}
    </g>
  );
};

export const EnergyPulse: React.FC<{
  x: number;
  y: number;
  f: number;
  color?: string;
  size?: number;
}> = ({ x, y, f, color = '#31d1e5', size = 80 }) => {
  const pulse = (wave(f, 0.08, 0.5) + 0.5);
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle cx="0" cy="0" r={size * (0.85 + pulse * 0.3)} fill={color} opacity={0.12 * (1 - pulse * 0.4)} />
      <circle cx="0" cy="0" r={size * (0.55 + pulse * 0.2)} fill={color} opacity={0.25 * (1 - pulse * 0.3)} />
      <circle cx="0" cy="0" r={size * 0.3} fill={color} opacity="0.6" />
    </g>
  );
};
