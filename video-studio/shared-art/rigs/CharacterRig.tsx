import React from 'react';
import { joint, wave, ease, clamp, Point } from '../math/motion';

export type CharacterMood = 'happy' | 'worried' | 'focus' | 'talk' | 'neutral';

export interface CharacterRigProps {
  x: number;
  y: number;
  scale?: number;
  f: number;
  mood?: CharacterMood;
  skinColor?: string;
  shirtColor?: string;
  pantsColor?: string;
  hairColor?: string;
  armPose?: 'down' | 'gesture' | 'hold' | 'point';
}

export const CharacterRig: React.FC<CharacterRigProps> = ({
  x,
  y,
  scale = 1,
  f,
  mood = 'neutral',
  skinColor = '#e9a05d',
  shirtColor = '#2caead',
  pantsColor = '#1b173a',
  hairColor = '#2a1810',
  armPose = 'gesture'
}) => {
  // Ciclos biológicos
  const breathe = wave(f, 0.05, 3.5);
  const headBob = wave(f, 0.05, 1.8, 0.4);
  const hairSway = wave(f, 0.04, 3.2, 0.8);
  const blink = (f % 110) > 104 ? 0.1 : 1;

  // Base anatómica (relativa al centro de cadera)
  const hip: Point = { x: 0, y: 0 };
  const chest: Point = { x: 0, y: -70 + breathe };
  const head: Point = { x: 0, y: -125 + breathe + headBob };

  // Brazos con Cinemática Inversa (IK)
  const shoulderL: Point = { x: -28, y: chest.y + 12 };
  const shoulderR: Point = { x: 28, y: chest.y + 12 };

  let targetHandR: Point;
  let targetHandL: Point;

  if (armPose === 'gesture') {
    const gestureWave = wave(f, 0.08, 14);
    targetHandR = { x: 55, y: -45 + gestureWave };
    targetHandL = { x: -35, y: 15 + wave(f, 0.05, 5) };
  } else if (armPose === 'point') {
    targetHandR = { x: 75, y: -80 + wave(f, 0.06, 4) };
    targetHandL = { x: -32, y: 15 };
  } else if (armPose === 'hold') {
    targetHandR = { x: 28, y: -35 + wave(f, 0.05, 3) };
    targetHandL = { x: -28, y: -35 + wave(f, 0.05, 3) };
  } else {
    targetHandR = { x: 34, y: 18 + wave(f, 0.05, 4) };
    targetHandL = { x: -34, y: 18 + wave(f, 0.05, 4) };
  }

  const elbowR = joint(shoulderR, targetHandR, 38, 38, -1);
  const elbowL = joint(shoulderL, targetHandL, 38, 38, 1);

  // Piernas
  const legL: Point = { x: -16, y: 85 };
  const legR: Point = { x: 16, y: 85 };
  const kneeL = joint({ x: -14, y: hip.y }, legL, 46, 46, 1);
  const kneeR = joint({ x: 14, y: hip.y }, legR, 46, 46, -1);

  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      {/* Piernas */}
      <polyline points={`-14,0 ${kneeL.x},${kneeL.y} ${legL.x},${legL.y}`} stroke={pantsColor} strokeWidth="18" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <polyline points={`14,0 ${kneeR.x},${kneeR.y} ${legR.x},${legR.y}`} stroke={pantsColor} strokeWidth="18" strokeLinecap="round" strokeLinejoin="round" fill="none" />

      {/* Zapatos */}
      <ellipse cx={legL.x - 3} cy={legL.y + 4} rx="12" ry="6" fill="#120e24" />
      <ellipse cx={legR.x + 3} cy={legR.y + 4} rx="12" ry="6" fill="#120e24" />

      {/* Torso */}
      <path
        d={`M -26,${hip.y} L -32,${chest.y + 15} Q 0,${chest.y - 5} 32,${chest.y + 15} L 26,${hip.y} Z`}
        fill={shirtColor}
      />
      {/* Cuello */}
      <rect x="-7" y={head.y + 15} width="14" height="20" rx="4" fill={skinColor} />

      {/* Brazo Izquierdo (detrás o al frente según pose) */}
      <polyline points={`${shoulderL.x},${shoulderL.y} ${elbowL.x},${elbowL.y} ${targetHandL.x},${targetHandL.y}`} stroke={shirtColor} strokeWidth="14" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <circle cx={targetHandL.x} cy={targetHandL.y} r="7.5" fill={skinColor} />

      {/* Cabeza */}
      <g transform={`translate(${head.x} ${head.y})`}>
        {/* Cabello posterior */}
        <ellipse cx="0" cy="-6" rx="30" ry="32" fill={hairColor} />
        {/* Rostro */}
        <circle cx="0" cy="0" r="26" fill={skinColor} />
        {/* Orejas */}
        <circle cx="-25" cy="0" r="6" fill={skinColor} />
        <circle cx="25" cy="0" r="6" fill={skinColor} />
        {/* Ojos */}
        <g transform={`scale(1 ${blink})`}>
          <ellipse cx="-9" cy="-2" rx="3.5" ry="4.5" fill="#120b22" />
          <circle cx="-10.5" cy="-3.5" r="1.2" fill="#ffffff" />
          <ellipse cx="9" cy="-2" rx="3.5" ry="4.5" fill="#120b22" />
          <circle cx="7.5" cy="-3.5" r="1.2" fill="#ffffff" />
        </g>
        {/* Cejas según emoción */}
        {mood === 'worried' ? (
          <>
            <line x1="-14" y1="-10" x2="-5" y2="-13" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
            <line x1="5" y1="-13" x2="14" y2="-10" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
          </>
        ) : mood === 'focus' ? (
          <>
            <line x1="-14" y1="-10" x2="-4" y2="-7" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
            <line x1="4" y1="-7" x2="14" y2="-10" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
          </>
        ) : (
          <>
            <line x1="-14" y1="-10" x2="-5" y2="-10" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
            <line x1="5" y1="-10" x2="14" y2="-10" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" />
          </>
        )}
        {/* Boca */}
        {mood === 'talk' ? (
          <ellipse cx="0" cy="11" rx="5" ry={2 + wave(f, 0.35, 3)} fill="#7b1f35" />
        ) : mood === 'happy' ? (
          <path d="M -7,8 Q 0,16 7,8" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" fill="none" />
        ) : mood === 'worried' ? (
          <path d="M -6,13 Q 0,8 6,13" stroke="#120b22" strokeWidth="2.5" strokeLinecap="round" fill="none" />
        ) : (
          <line x1="-5" y1="10" x2="5" y2="10" stroke="#120b22" strokeWidth="2.2" strokeLinecap="round" />
        )}
        {/* Mechón frontal con inercia física */}
        <path
          d={`M -20,-16 Q ${hairSway},-36 22,-18 Q 8,-12 -20,-16 Z`}
          fill={hairColor}
        />
      </g>

      {/* Brazo Derecho (frontal) */}
      <polyline points={`${shoulderR.x},${shoulderR.y} ${elbowR.x},${elbowR.y} ${targetHandR.x},${targetHandR.y}`} stroke={shirtColor} strokeWidth="14" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      <circle cx={targetHandR.x} cy={targetHandR.y} r="7.5" fill={skinColor} />
    </g>
  );
};
