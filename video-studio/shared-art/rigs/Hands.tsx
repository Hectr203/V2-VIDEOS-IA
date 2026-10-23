import React from 'react';
import { wave } from '../math/motion';

export interface HandProps {
  x: number;
  y: number;
  scale?: number;
  rotation?: number;
  skinColor?: string;
  f?: number;
}

export const PointingHand: React.FC<HandProps> = ({
  x,
  y,
  scale = 1,
  rotation = 0,
  skinColor = '#e9a05d',
  f = 0
}) => {
  const tremble = f ? wave(f, 0.12, 1.5) : 0;
  return (
    <g transform={`translate(${x} ${y + tremble}) scale(${scale}) rotate(${rotation})`}>
      {/* Palma cerrada */}
      <rect x="-14" y="-12" width="28" height="26" rx="8" fill={skinColor} />
      {/* Dedo índice extendido */}
      <rect x="-5" y="-38" width="10" height="30" rx="5" fill={skinColor} />
      {/* Pulgar flexionado */}
      <path d="M -14,0 Q -22,-6 -14,-14" stroke={skinColor} strokeWidth="8" strokeLinecap="round" fill="none" />
      {/* Sombra de nudillos */}
      <line x1="-10" y1="2" x2="10" y2="2" stroke="#b55b38" strokeWidth="1.5" opacity="0.4" strokeLinecap="round" />
    </g>
  );
};

export const ThumbsUpHand: React.FC<HandProps> = ({
  x,
  y,
  scale = 1,
  rotation = 0,
  skinColor = '#e9a05d',
  f = 0
}) => {
  const bob = f ? wave(f, 0.08, 2) : 0;
  return (
    <g transform={`translate(${x} ${y + bob}) scale(${scale}) rotate(${rotation})`}>
      {/* Puño */}
      <rect x="-16" y="-10" width="30" height="24" rx="8" fill={skinColor} />
      {/* Pulgar hacia arriba */}
      <rect x="-6" y="-32" width="12" height="26" rx="6" fill={skinColor} />
      <circle cx="0" cy="-28" r="4" fill="#ffcaa0" opacity="0.5" />
    </g>
  );
};

export const OpenHand: React.FC<HandProps> = ({
  x,
  y,
  scale = 1,
  rotation = 0,
  skinColor = '#e9a05d',
  f = 0
}) => {
  const splay = f ? wave(f, 0.06, 2) : 0;
  return (
    <g transform={`translate(${x} ${y}) scale(${scale}) rotate(${rotation + splay})`}>
      {/* Palma */}
      <ellipse cx="0" cy="0" rx="16" ry="14" fill={skinColor} />
      {/* Dedos extendidos */}
      <rect x="-14" y="-30" width="6.5" height="22" rx="3" fill={skinColor} />
      <rect x="-6" y="-34" width="7" height="26" rx="3.5" fill={skinColor} />
      <rect x="2" y="-32" width="6.5" height="24" rx="3" fill={skinColor} />
      <rect x="10" y="-26" width="6" height="18" rx="3" fill={skinColor} />
      {/* Pulgar lateral */}
      <rect x="-24" y="-8" width="14" height="7" rx="3.5" transform="rotate(-30 -16 -4)" fill={skinColor} />
    </g>
  );
};
