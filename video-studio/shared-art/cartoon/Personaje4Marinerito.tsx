import React from 'react';
import {
  CARTOON_INK,
  CARTOON_STROKE,
  CartoonArmIK,
  CartoonFaceFeatures,
  CartoonLegIK,
  CartoonMood,
  CartoonPose,
  HandShape,
  Vec2,
  cartoonBlink,
  inkProps,
} from './sharedCartoonStyle';

export type MarineritoOutfit = 'base' | 'vecindad' | 'diario';

export interface Personaje4MarineritoProps {
  x?: number;
  y?: number;
  scale?: number;
  flipX?: boolean;
  frame?: number;
  animated?: boolean;
  pose?: CartoonPose;
  mood?: CartoonMood;
  outfit?: MarineritoOutfit;
  capOn?: boolean;
  mouthOpen?: number;
  lookX?: number;
  lookY?: number;
  tears?: boolean;
  blush?: boolean;
  leftHandOverride?: Vec2;
  rightHandOverride?: Vec2;
}

const SKIN = '#dbb588';
const HAIR = '#2b221c';

const OUTFIT_STYLES: Record<
  MarineritoOutfit,
  {
    tunic: string;
    collar: string;
    stripe: string;
    scarf: string;
    shorts: string;
    sock: string;
    shoe: string;
    cap: string;
    capBand: string;
    sleeveRatio: number;
    defaultCap: boolean;
    patch?: string;
  }
> = {
  // Look base estandarizado: traje marinerito azul petróleo + cuello crema + pañoleta ocre
  base: {
    tunic: '#2f6b7c',
    collar: '#f3eee4',
    stripe: '#2f6b7c',
    scarf: '#e09f3e',
    shorts: '#1f3444',
    sock: '#f3eee4',
    shoe: '#1d262e',
    cap: '#f3eee4',
    capBand: '#2f6b7c',
    sleeveRatio: 0.62,
    defaultCap: true,
  },
  // Variante IP-Safe Vecindad: blusa marinera crema vintage + cuello pizarra + pañoleta terracota
  vecindad: {
    tunic: '#ece4d3',
    collar: '#466a82',
    stripe: '#ece4d3',
    scarf: '#c9644a',
    shorts: '#4b5763',
    sock: '#ece4d3',
    shoe: '#262b30',
    cap: '#466a82',
    capBand: '#c9644a',
    sleeveRatio: 0.65,
    defaultCap: true,
  },
  // Variante literaria / libro crudo: suéter marinero azul humo desgastado con parche + sin gorra
  diario: {
    tunic: '#647785',
    collar: '#d7d1c5',
    stripe: '#455460',
    scarf: '#8a6d4b',
    shorts: '#3c434a',
    sock: '#c8c2b6',
    shoe: '#252322',
    cap: '#647785',
    capBand: '#3c434a',
    sleeveRatio: 1.56,
    defaultCap: false,
    patch: '#9e8462',
  },
};

/**
 * PERSONAJE 4: Niño con Traje de Marinerito.
 * Misma línea gráfica exacta del Personaje Base (tinta #0b0d10, trazo 4.4, rellenos planos,
 * cabeza ovalada, ojos sólidos, extremidades IK de 2 segmentos).
 * Proporción infantil ágil (~0.84× altura adulto base), 100% IP-Safe (cero copia de traje negro/moño rojo/gorra de hélice).
 */
export const Personaje4Marinerito: React.FC<Personaje4MarineritoProps> = ({
  x = 0,
  y = 0,
  scale = 1,
  flipX = false,
  frame = 0,
  animated = false,
  pose = 'neutral',
  mood = 'feliz',
  outfit = 'base',
  capOn,
  mouthOpen = 0,
  lookX = 0,
  lookY = 0,
  tears = false,
  blush = false,
  leftHandOverride,
  rightHandOverride,
}) => {
  const st = OUTFIT_STYLES[outfit];
  const showCap = capOn ?? st.defaultCap;
  const ink = inkProps();

  const breathY = animated ? Math.sin(frame * 0.11) * 2.2 : 0;
  const headLagY = animated ? Math.sin((frame - 4) * 0.11) * 1.6 : 0;
  const walkPhase = animated ? Math.sin(frame * 0.27) : 0.74;
  const blink = cartoonBlink(frame, animated, 49);

  // Coordenadas locales con pies en y = 0 (altura total ~314 px ≈ 0.85× adulto base)
  const hipY = pose === 'triste_encogido' ? -92 : -98;
  const hipL: Vec2 = {x: -19, y: hipY};
  const hipR: Vec2 = {x: 19, y: hipY};

  let footL: Vec2 = {x: -26, y: -15};
  let footR: Vec2 = {x: 26, y: -15};
  let torsoLean = 0;
  let headTilt = animated ? Math.sin(frame * 0.065) * 2.3 : 0;

  if (pose === 'caminando') {
    footL = {x: -20 - walkPhase * 28, y: -15 - Math.max(0, -walkPhase) * 14};
    footR = {x: 20 + walkPhase * 28, y: -15 - Math.max(0, walkPhase) * 14};
    torsoLean = 5;
  } else if (pose === 'triste_encogido') {
    footL = {x: -20, y: -15};
    footR = {x: 20, y: -15};
    torsoLean = 6;
    headTilt = 11;
  } else if (pose === 'celebrando') {
    footL = {x: -36, y: -15};
    footR = {x: 36, y: -15};
    headTilt = -5;
  } else if (pose === 'pensativo') {
    headTilt = 7;
  } else if (pose === 'señalando') {
    footL = {x: -44, y: -15};
    footR = {x: 38, y: -15};
    torsoLean = -3;
  }

  const shL: Vec2 = {x: -36, y: -188 + breathY};
  const shR: Vec2 = {x: 36, y: -188 + breathY};

  let handL: Vec2 = {x: -56, y: -112 + breathY};
  let handR: Vec2 = {x: 56, y: -112 + breathY};
  let shapeL: HandShape = 'abierta';
  let shapeR: HandShape = 'abierta';

  if (pose === 'caminando') {
    handL = {x: -66 + walkPhase * 12, y: -120 - walkPhase * 16 + breathY};
    handR = {x: 66 - walkPhase * 12, y: -120 + walkPhase * 16 + breathY};
  } else if (pose === 'explicando') {
    const g = animated ? Math.sin(frame * 0.18) * 8 : 0;
    handL = {x: -82, y: -158 + g + breathY};
    handR = {x: 84, y: -168 - g + breathY};
    shapeL = 'palma_arriba';
    shapeR = 'palma_arriba';
  } else if (pose === 'brazos_cruzados') {
    handL = {x: 20, y: -146 + breathY};
    handR = {x: -20, y: -142 + breathY};
    shapeL = 'puno';
    shapeR = 'puno';
  } else if (pose === 'pensativo') {
    handL = {x: -48, y: -118 + breathY};
    handR = {x: 18, y: -204 + breathY};
    shapeR = 'puno';
  } else if (pose === 'celebrando') {
    const ch = animated ? Math.sin(frame * 0.24) * 11 : 0;
    handL = {x: -84, y: -256 + ch};
    handR = {x: 84, y: -256 - ch};
  } else if (pose === 'triste_encogido') {
    handL = {x: -38, y: -108 + breathY};
    handR = {x: 38, y: -108 + breathY};
  } else if (pose === 'señalando') {
    handL = {x: -104, y: -244 + breathY};
    handR = {x: 60, y: -126 + breathY};
    shapeL = 'senalando';
    shapeR = 'puno';
  }

  if (leftHandOverride) handL = leftHandOverride;
  if (rightHandOverride) handR = rightHandOverride;

  const leftArmFront = pose === 'brazos_cruzados';
  const rightArmFront = pose === 'brazos_cruzados' || pose === 'pensativo';
  const leftElbowBend: 1 | -1 = pose === 'brazos_cruzados' ? 1 : -1;
  const rightElbowBend: 1 | -1 = pose === 'brazos_cruzados' ? -1 : 1;

  const renderLeftArm = () => (
    <CartoonArmIK
      shoulder={shL}
      handTarget={handL}
      upperLen={44}
      lowerLen={42}
      bend={leftElbowBend}
      thickness={20}
      skin={SKIN}
      sleeveColor={st.tunic}
      sleeveRatio={st.sleeveRatio}
      handShape={shapeL}
      handFlipX
    />
  );

  const renderRightArm = () => (
    <CartoonArmIK
      shoulder={shR}
      handTarget={handR}
      upperLen={44}
      lowerLen={42}
      bend={rightElbowBend}
      thickness={20}
      skin={SKIN}
      sleeveColor={st.tunic}
      sleeveRatio={st.sleeveRatio}
      handShape={shapeR}
    />
  );

  return (
    <g transform={`translate(${x} ${y}) scale(${flipX ? -scale : scale} ${scale})`}>
      {/* Piernas infantiles con shorts de marinerito y calcetas */}
      <CartoonLegIK
        hip={hipL}
        foot={footL}
        thighLen={43}
        calfLen={42}
        bend={pose === 'caminando' ? -1 : 1}
        thickness={23}
        pantsColor={st.shorts}
        shoeColor={st.shoe}
        sockColor={st.sock}
        shortsMode
        skinColor={SKIN}
        footDir={-1}
      />
      <CartoonLegIK
        hip={hipR}
        foot={footR}
        thighLen={43}
        calfLen={42}
        bend={-1}
        thickness={23}
        pantsColor={st.shorts}
        shoeColor={st.shoe}
        sockColor={st.sock}
        shortsMode
        skinColor={SKIN}
        footDir={1}
      />
      {/* Cintura de shorts uniendo ambas piernas */}
      <rect x="-35" y={hipY - 12} width="70" height="28" rx="12" fill={st.shorts} stroke={CARTOON_INK} strokeWidth={CARTOON_STROKE} />

      <g transform={`rotate(${torsoLean} 0 -98)`}>
        {!leftArmFront && renderLeftArm()}
        {!rightArmFront && renderRightArm()}

        {/* BLUSA MARINERA CON CUELLO CUADRADO Y PAÑOLETA */}
        <g transform={`translate(0 ${breathY})`}>
          <path
            d="M -38 -196
               C -42 -164 -45 -128 -44 -96
               C -18 -90 18 -90 44 -96
               C 45 -128 42 -164 38 -196
               C 16 -202 -16 -202 -38 -196 Z"
            fill={st.tunic}
            {...ink}
          />

          {/* Solapa marinera en V con rayas características */}
          <path d="M -36 -196 L -28 -164 L 0 -148 L 28 -164 L 36 -196 C 14 -201 -14 -201 -36 -196 Z" fill={st.collar} {...ink} />
          <path d="M -27 -172 L 0 -158 L 27 -172" fill="none" stroke={st.stripe} strokeWidth="3.2" strokeLinecap="round" />

          {/* Pañoleta marinera anudada al centro */}
          <path d="M -8 -162 L 8 -162 L 13 -130 L 0 -138 L -13 -130 Z" fill={st.scarf} {...ink} />
          <circle cx="0" cy="-162" r="7.5" fill={st.scarf} {...ink} />

          {/* Parche opcional en variante emotiva/diario */}
          {st.patch && (
            <g transform="translate(18 -118) rotate(-6)">
              <rect x="-12" y="-9" width="24" height="18" rx="3" fill={st.patch} stroke={CARTOON_INK} strokeWidth="2.8" />
              <path d="M -12 -3 L -15 -3 M 12 3 L 15 3 M -3 -9 L -3 -12" stroke={CARTOON_INK} strokeWidth="2.2" strokeLinecap="round" />
            </g>
          )}
        </g>

        {leftArmFront && renderLeftArm()}
        {rightArmFront && renderRightArm()}

        {/* CABEZA CON MECHÓN Y GORRA MARINERA */}
        <g transform={`translate(0 ${-242 + breathY + headLagY}) rotate(${headTilt})`}>
          <ellipse cx="-56" cy="4" rx="12" ry="15" fill={SKIN} {...ink} />
          <ellipse cx="56" cy="4" rx="12" ry="15" fill={SKIN} {...ink} />

          {/* Base de cabello castaño */}
          <path
            d="M -54 -14 C -58 -48 58 -48 54 -14 C 56 0 52 10 46 14 L 44 -14 L -44 -14 L -46 14 C -52 10 -56 0 -54 -14 Z"
            fill={HAIR}
            {...ink}
          />

          {/* Óvalo facial de la misma familia artística */}
          <ellipse cx="0" cy="4" rx="56" ry="45" fill={SKIN} {...ink} />

          {/* Flequillo travieso de niño */}
          <path
            d="M -52 -14 C -48 -46 48 -46 52 -14 C 34 -26 16 -18 4 -24 C -6 -10 -24 -12 -32 -24 C -40 -22 -46 -18 -52 -14 Z"
            fill={HAIR}
            {...ink}
          />

          <CartoonFaceFeatures
            mood={mood}
            blink={blink}
            lookX={lookX}
            lookY={lookY}
            mouthOpen={mouthOpen}
            eyeSpacing={30}
            eyeY={4}
            mouthY={28}
            blush={blush}
            tears={tears}
          />

          {/* Gorra marinera clásica ligeramente inclinada (si capOn está activo) */}
          {showCap && (
            <g transform="translate(4 -36) rotate(7)">
              {/* Copa blanda marinera */}
              <path
                d="M -54 14
                   C -62 -16 -38 -36 0 -36
                   C 38 -36 62 -16 54 14 Z"
                fill={st.cap}
                {...ink}
              />
              {/* Cinta inferior con dos colitas laterales */}
              <path d="M -52 14 C -20 20 20 20 52 14 L 50 2 C 20 7 -20 7 -50 2 Z" fill={st.capBand} {...ink} />
              <path d="M 48 12 L 62 24 L 54 29 L 44 16 Z" fill={st.capBand} {...ink} />
            </g>
          )}
        </g>
      </g>
    </g>
  );
};
