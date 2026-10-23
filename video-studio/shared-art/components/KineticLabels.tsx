import React from 'react';
import { ease, mix, clamp } from '../math/motion';

export const ChapterBadge: React.FC<{
  x: number;
  y: number;
  text: string;
  f: number;
  color?: string;
  bgColor?: string;
  size?: number;
}> = ({
  x,
  y,
  text,
  f,
  color = '#effdff',
  bgColor = '#1b173a',
  size = 22
}) => {
  const pop = ease(f / 12);
  const scale = mix(0.7, 1.0, pop);
  const opacity = pop;
  const w = text.length * size * 0.54 + 34;

  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`} opacity={opacity}>
      <rect
        x={-w / 2}
        y={-size - 8}
        width={w}
        height={size + 22}
        rx="11"
        fill={bgColor}
        stroke="#4a3e75"
        strokeWidth="1.5"
        opacity="0.9"
      />
      <text
        textAnchor="middle"
        fill={color}
        fontSize={size}
        fontWeight="800"
        letterSpacing="1.2"
        fontFamily="sans-serif"
      >
        {text}
      </text>
    </g>
  );
};

export const MetricCallout: React.FC<{
  x: number;
  y: number;
  value: string;
  unit: string;
  color?: string;
  f: number;
}> = ({ x, y, value, unit, color = '#ffe35f', f }) => {
  const pop = ease(f / 14);
  return (
    <g transform={`translate(${x} ${y}) scale(${mix(0.8, 1, pop)})`} opacity={pop}>
      <text
        textAnchor="middle"
        y="-8"
        fill={color}
        fontSize="54"
        fontWeight="900"
        letterSpacing="-1.5"
      >
        {value}
      </text>
      <text
        textAnchor="middle"
        y="28"
        fill="#ffffff"
        fontSize="18"
        fontWeight="700"
        opacity="0.85"
        letterSpacing="1.5"
      >
        {unit.toUpperCase()}
      </text>
    </g>
  );
};
