import React from 'react';
import { AbsoluteFill, useCurrentFrame } from 'remotion';
import { ChavoDefs, CHAVO_COLORS, ChavoMood } from './ChavoRig';
import { wave, spring, clamp } from '../../../shared-art/math/motion';

export interface ChavoBarrelSceneProps {
  mood?: ChavoMood;
}

/**
 * Ejemplo 2: El Chavo del 8 asomándose desde adentro de su icónico Barril.
 * Estructura de capas con profundidad real: fondo -> interior de barril -> torso
 * -> frontal de barril -> manos apoyadas en el borde -> cabeza con gorro y gestos.
 */
export const ChavoBarrelScene: React.FC<ChavoBarrelSceneProps> = ({
  mood = 'neutral',
}) => {
  const frame = useCurrentFrame();

  // Ciclo de asomarse / esconderse con resorte amortiguado
  // Cada 120 frames (4s), se esconde un segundo y vuelve a asomarse
  const cycleFrame = frame % 150;
  let peekProgress = 1;
  if (cycleFrame < 25) {
    // Sube asomándose
    peekProgress = spring(cycleFrame / 22);
  } else if (cycleFrame > 120 && cycleFrame < 135) {
    // Baja escondiéndose
    peekProgress = 1 - spring((cycleFrame - 120) / 14);
  } else if (cycleFrame >= 135) {
    // Escondido en el fondo
    peekProgress = 0;
  }

  const peekOffsetY = (1 - peekProgress) * 180;
  const breathe = wave(frame, 0.05, 3.5);
  const headTilt = wave(frame, 0.04, 3.5);
  const hatFlapSway = wave(frame, 0.06, 2.5);

  // Mirada curiosa de lado a lado
  const lookX = wave(frame, 0.04, 0.7);
  const lookY = wave(frame, 0.02, 0.3);

  // Parpadeo cómico
  const blinkCycle = frame % 115;
  const isBlinking = blinkCycle > 110;
  const blinkScale = isBlinking ? 0.05 : 1;

  // Estado de humor dinámico según el frame
  const currentMood: ChavoMood =
    cycleFrame > 40 && cycleFrame < 80 ? 'smile' :
    cycleFrame >= 80 && cycleFrame < 115 ? 'talk' : mood;

  const mouthOpen = currentMood === 'talk' ? Math.abs(wave(frame, 0.35, 7)) : 0;

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
      <svg viewBox="0 0 1080 1920" width="100%" height="100%">
        <ChavoDefs />

        {/* FONDO VECINDAD CÁLIDA */}
        <rect width="1080" height="1920" fill={CHAVO_COLORS.wallOrange} />
        <rect width="1080" height="1920" fill="url(#sun-glow)" />
        <line x1="0" y1="1260" x2="1080" y2="1260" stroke={CHAVO_COLORS.lineDark} strokeWidth="8" />
        <rect x="0" y="1260" width="1080" height="660" fill={CHAVO_COLORS.floorBrown} />

        {/* SOMBRA GENERAL DEL BARRIL */}
        <ellipse cx="540" cy="1620" rx="340" ry="60" fill="#000000" opacity="0.3" />

        {/* COMPOSICIÓN DEL BARRIL Y EL CHAVO CENTRADO */}
        <g transform="translate(540, 1150) scale(2.6)">

          {/* CAPA 1: BORDE TRASERO E INTERIOR DEL BARRIL */}
          <ellipse cx="0" cy="0" rx="90" ry="24" fill="#180e07" stroke={CHAVO_COLORS.lineDark} strokeWidth="6" />

          {/* CAPA 2: CUERPO / TORSO DEL CHAVO ADENTRO DEL BARRIL */}
          <g id="chavo-inside" transform={`translate(0, ${peekOffsetY + breathe})`}>
            {/* Torso con rayas */}
            <g id="chavo-torso-peek">
              <clipPath id="chavo-peek-clip">
                <path d="M -75,-10 L 70,-8 L 60,110 L -65,110 Z" />
              </clipPath>
              <g clipPath="url(#chavo-peek-clip)">
                <rect x="-85" y="-15" width="170" height="35" fill={CHAVO_COLORS.shirtBrown} />
                <rect x="-85" y="20" width="170" height="32" fill={CHAVO_COLORS.shirtDark} />
                <rect x="-85" y="52" width="170" height="34" fill={CHAVO_COLORS.shirtCream} />
                <rect x="-85" y="86" width="170" height="34" fill={CHAVO_COLORS.shirtBrown} />
              </g>
              <path d="M -75,-10 L 70,-8 L 60,110 L -65,110 Z" fill="none" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinejoin="round" />

              {/* Cuello de la camiseta */}
              <path d="M -40,-15 Q -5,-2 18,-10" stroke={CHAVO_COLORS.lineDark} strokeWidth="5" fill="none" strokeLinecap="round" />

              {/* El tirante rojo cruzado */}
              <path d="M 6,-14 L -35,110 L -20,110 L 22,-12 Z" fill={CHAVO_COLORS.suspender} stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" strokeLinejoin="round" />
              <path d="M 14,-12 L -5,90 L 4,90 L 24,-12 Z" fill={CHAVO_COLORS.suspender} stroke={CHAVO_COLORS.lineDark} strokeWidth="4" strokeLinejoin="round" />
            </g>
          </g>

          {/* CAPA 3: CUERPO Y FRONTAL DEL BARRIL DE MADERA (TAPA EL CUERPO INFERIOR) */}
          <g id="barrel-front">
            {/* Silueta frontal del barril */}
            <path
              d="M -90,0 Q -130,180 -95,360 L 95,360 Q 130,180 90,0 Z"
              fill="url(#chavo-barrel-wood)"
              stroke={CHAVO_COLORS.lineDark}
              strokeWidth="6"
              strokeLinejoin="round"
            />
            {/* Duelas verticales */}
            <path d="M -54,0 Q -80,180 -58,360" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
            <path d="M -18,0 Q -27,180 -19,360" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
            <path d="M 18,0 Q 27,180 19,360" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />
            <path d="M 54,0 Q 80,180 58,360" stroke="#351f0f" strokeWidth="3.5" fill="none" opacity="0.65" />

            {/* Aros de hierro negros */}
            <path d="M -110,90 Q 0,115 110,90" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="22" fill="none" strokeLinecap="round" />
            <path d="M -112,210 Q 0,235 112,210" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="22" fill="none" strokeLinecap="round" />
            <path d="M -98,330 Q 0,352 98,330" stroke={CHAVO_COLORS.barrelHoop} strokeWidth="22" fill="none" strokeLinecap="round" />

            {/* Remaches de metal */}
            <circle cx="-75" cy="102" r="3.5" fill="#666" />
            <circle cx="75" cy="102" r="3.5" fill="#666" />
            <circle cx="-77" cy="223" r="3.5" fill="#666" />
            <circle cx="77" cy="223" r="3.5" fill="#666" />

            {/* Borde frontal curvado de madera del barril */}
            <path d="M -90,0 Q 0,26 90,0" stroke={CHAVO_COLORS.lineDark} strokeWidth="6" fill="none" />
          </g>

          {/* CAPA 4: MANOS APOYADAS POR FUERA EN EL BORDE SUPERIOR */}
          {peekProgress > 0.4 && (
            <g id="hands-resting-on-rim" transform={`translate(0, ${peekOffsetY * 0.4 + breathe})`}>
              {/* Mano izquierda */}
              <g transform="translate(-48, 8)">
                <ellipse cx="0" cy="0" rx="14" ry="9" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" />
                <path d="M -8,5 Q 0,9 8,5" stroke={CHAVO_COLORS.lineDark} strokeWidth="3" fill="none" strokeLinecap="round" />
              </g>
              {/* Mano derecha */}
              <g transform="translate(48, 8)">
                <ellipse cx="0" cy="0" rx="14" ry="9" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" />
                <path d="M -8,5 Q 0,9 8,5" stroke={CHAVO_COLORS.lineDark} strokeWidth="3" fill="none" strokeLinecap="round" />
              </g>
            </g>
          )}

          {/* CAPA 5: CABEZA DEL CHAVO ASOMANDO CON SU GORRO Y EXPRESIONES */}
          <g
            id="chavo-head-peek"
            transform={`translate(0, ${peekOffsetY + breathe - 20}) rotate(${headTilt})`}
          >
            {/* Cuello */}
            <path d="M -20,-20 L -20,6 L 16,6 L 16,-20 Z" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="5" />

            {/* Orejera izquierda */}
            <g transform={`rotate(${hatFlapSway}, -70, -70)`}>
              <path d="M -75,-100 Q -110,-35 -105,25 Q -85,75 -55,55 Q -38,20 -50,-40 Z" fill="url(#chavo-hat-flap-l)" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinejoin="round" />
            </g>

            {/* Rostro base */}
            <path d="M -72,-105 C -75,-50 -72,0 -52,18 C -32,35 25,35 45,18 C 65,0 68,-50 65,-105 Z" fill={CHAVO_COLORS.skin} stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinejoin="round" />

            {/* Orejera derecha */}
            <g transform={`rotate(${-hatFlapSway}, 55, -70)`}>
              <path d="M 50,-85 Q 58,-35 66,15 Q 72,65 52,70 Q 38,40 38,-20 Z" fill="url(#chavo-hat-flap-r)" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinejoin="round" />
            </g>

            {/* Corona del gorro */}
            <path d="M -85,-100 C -90,-200 -40,-235 0,-235 C 40,-235 80,-200 75,-100 Z" fill="url(#chavo-hat-plaid)" stroke={CHAVO_COLORS.lineDark} strokeWidth="6" strokeLinejoin="round" />
            <path d="M 0,-235 Q -6,-165 -10,-105" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />
            <path d="M 0,-235 Q -48,-165 -52,-115" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />
            <path d="M 0,-235 Q 42,-165 48,-115" stroke={CHAVO_COLORS.hatDarkLine} strokeWidth="3" fill="none" opacity="0.75" />

            {/* Visera frontal */}
            <path d="M -60,-95 Q 0,-78 62,-95 Q 10,-70 -50,-85 Z" fill={CHAVO_COLORS.skinShadow} opacity="0.65" />
            <path d="M -68,-108 Q -10,-90 68,-108 Q 80,-72 68,-65 Q 0,-72 -60,-75 Q -72,-88 -68,-108 Z" fill="url(#chavo-hat-plaid)" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinejoin="round" />
            <path d="M -62,-75 Q 0,-72 68,-65" stroke={CHAVO_COLORS.lineDark} strokeWidth="4" fill="none" strokeLinecap="round" />

            {/* Ojos */}
            <g transform={`translate(0, -36) scale(1, ${blinkScale})`}>
              <g transform="translate(-25, 0)">
                <ellipse cx="0" cy="0" rx="27" ry="16" fill="#ffffff" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" />
                <ellipse cx={lookX * 4} cy={lookY * 2.5} rx="21" ry="14.5" fill="#121214" />
              </g>
              <g transform="translate(30, 0)">
                <ellipse cx="0" cy="0" rx="27" ry="16" fill="#ffffff" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" />
                <ellipse cx={lookX * 4} cy={lookY * 2.5} rx="21" ry="14.5" fill="#121214" />
              </g>
            </g>

            {/* Boca */}
            <g transform="translate(2, -2)">
              {currentMood === 'smile' ? (
                <path d="M -16,-3 Q 0,16 16,-3 Z" fill="#ffffff" stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" strokeLinejoin="round" />
              ) : currentMood === 'talk' ? (
                <ellipse cx="0" cy="2" rx="10" ry={3 + mouthOpen} fill="#54171f" stroke={CHAVO_COLORS.lineDark} strokeWidth="4.5" />
              ) : (
                <line x1="-14" y1="0" x2="10" y2="0" stroke={CHAVO_COLORS.lineDark} strokeWidth="5.5" strokeLinecap="round" />
              )}
            </g>
          </g>

        </g>
      </svg>
    </AbsoluteFill>
  );
};
