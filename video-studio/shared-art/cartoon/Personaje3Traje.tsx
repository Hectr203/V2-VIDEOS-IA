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

export type TrajeOutfit = 'base' | 'vecindad' | 'escritor';
export type FacialHairVariant = 'limpio' | 'perilla' | 'bigote_fino';

export interface Personaje3TrajeProps {
  x?: number;
  y?: number;
  scale?: number;
  flipX?: boolean;
  frame?: number;
  animated?: boolean;
  pose?: CartoonPose;
  mood?: CartoonMood;
  outfit?: TrajeOutfit;
  facialHair?: FacialHairVariant;
  mouthOpen?: number;
  lookX?: number;
  lookY?: number;
  tears?: boolean;
  blush?: boolean;
  leftHandOverride?: Vec2;
  rightHandOverride?: Vec2;
}

const SKIN = '#d9b58a';
const HAIR = '#242228';

const OUTFIT_STYLES: Record<
  TrajeOutfit,
  {
    jacket: string;
    lapel: string;
    shirt: string;
    tie: string;
    vest?: string;
    pants: string;
    shoe: string;
    hat: string;
    hatBand: string;
    turtleneck?: boolean;
  }
> = {
  // Look base estandarizado: traje gris-ciruela elegante + fedora + corbata borgoña
  base: {
    jacket: '#3b3648',
    lapel: '#2d2838',
    shirt: '#f2ede4',
    tie: '#8c3b4a',
    pants: '#2c2836',
    shoe: '#18161d',
    hat: '#4c455c',
    hatBand: '#d4a853',
  },
  // Variante IP-Safe Vecindad: saco tweed oliva-carbón + chaleco crema + sombrero arena
  vecindad: {
    jacket: '#4a5349',
    lapel: '#394038',
    shirt: '#f3eee4',
    vest: '#ded4c0',
    tie: '#2c4257',
    pants: '#3a403a',
    shoe: '#211c18',
    hat: '#9e8669',
    hatBand: '#394038',
  },
  // Variante literaria / narrador para pasajes del libro de 1995
  escritor: {
    jacket: '#5c4a3e',
    lapel: '#45372e',
    shirt: '#242428',
    tie: '#242428',
    pants: '#342c27',
    shoe: '#1b1614',
    hat: '#4a5159',
    hatBand: '#c4864b',
    turtleneck: true,
  },
};

/**
 * PERSONAJE 3: Hombre con Traje y Sombrero.
 * Misma bibliografía gráfica exacta del Personaje Base (tinta #0b0d10, trazo 4.4, flat cel,
 * cabeza ovalada expresiva, ojos sólidos, extremidades IK articuladas).
 * Proporción adulta más estilizada y alta (~1.12× del adulto base) con 3 vestuarios IP-Safe.
 */
export const Personaje3Traje: React.FC<Personaje3TrajeProps> = ({
  x = 0,
  y = 0,
  scale = 1,
  flipX = false,
  frame = 0,
  animated = false,
  pose = 'neutral',
  mood = 'serio',
  outfit = 'base',
  facialHair = 'limpio',
  mouthOpen = 0,
  lookX = 0,
  lookY = 0,
  tears = false,
  blush = false,
  leftHandOverride,
  rightHandOverride,
}) => {
  const st = OUTFIT_STYLES[outfit];
  const ink = inkProps();

  const breathY = animated ? Math.sin(frame * 0.08) * 2.2 : 0;
  const headLagY = animated ? Math.sin((frame - 4) * 0.08) * 1.6 : 0;
  const walkPhase = animated ? Math.sin(frame * 0.22) : 0.72;
  const blink = cartoonBlink(frame, animated, 37);

  // Coordenadas locales con pies en y = 0 (altura total ~408 px ≈ 1.12× adulto base)
  const hipY = pose === 'triste_encogido' ? -130 : -138;
  const hipL: Vec2 = {x: -22, y: hipY};
  const hipR: Vec2 = {x: 22, y: hipY};

  let footL: Vec2 = {x: -30, y: -17};
  let footR: Vec2 = {x: 30, y: -17};
  let torsoLean = 0;
  let headTilt = animated ? Math.sin(frame * 0.045) * 1.8 : 0;

  if (pose === 'caminando') {
    footL = {x: -22 - walkPhase * 34, y: -17 - Math.max(0, -walkPhase) * 16};
    footR = {x: 22 + walkPhase * 34, y: -17 - Math.max(0, walkPhase) * 16};
    torsoLean = 4;
  } else if (pose === 'triste_encogido') {
    footL = {x: -22, y: -17};
    footR = {x: 22, y: -17};
    torsoLean = 6;
    headTilt = 10;
  } else if (pose === 'celebrando') {
    footL = {x: -38, y: -17};
    footR = {x: 38, y: -17};
    headTilt = -4;
  } else if (pose === 'pensativo') {
    headTilt = 6;
  } else if (pose === 'señalando') {
    footL = {x: -50, y: -17};
    footR = {x: 42, y: -17};
    torsoLean = -3;
  }

  const shL: Vec2 = {x: -46, y: -258 + breathY};
  const shR: Vec2 = {x: 46, y: -258 + breathY};

  let handL: Vec2 = {x: -66, y: -146 + breathY};
  let handR: Vec2 = {x: 66, y: -146 + breathY};
  let shapeL: HandShape = 'abierta';
  let shapeR: HandShape = 'abierta';

  if (pose === 'caminando') {
    handL = {x: -76 + walkPhase * 14, y: -158 - walkPhase * 20 + breathY};
    handR = {x: 76 - walkPhase * 14, y: -158 + walkPhase * 20 + breathY};
  } else if (pose === 'explicando') {
    const g = animated ? Math.sin(frame * 0.15) * 8 : 0;
    handL = {x: -94, y: -212 + g + breathY};
    handR = {x: 96, y: -222 - g + breathY};
    shapeL = 'palma_arriba';
    shapeR = 'palma_arriba';
  } else if (pose === 'brazos_cruzados') {
    handL = {x: 24, y: -202 + breathY};
    handR = {x: -24, y: -198 + breathY};
    shapeL = 'puno';
    shapeR = 'puno';
  } else if (pose === 'pensativo') {
    handL = {x: -58, y: -156 + breathY};
    handR = {x: 20, y: -272 + breathY};
    shapeR = 'puno';
  } else if (pose === 'celebrando') {
    const ch = animated ? Math.sin(frame * 0.2) * 12 : 0;
    handL = {x: -96, y: -340 + ch};
    handR = {x: 96, y: -340 - ch};
  } else if (pose === 'triste_encogido') {
    handL = {x: -44, y: -144 + breathY};
    handR = {x: 44, y: -144 + breathY};
  } else if (pose === 'señalando') {
    handL = {x: -124, y: -322 + breathY};
    handR = {x: 70, y: -164 + breathY};
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
      upperLen={60}
      lowerLen={58}
      bend={leftElbowBend}
      thickness={23}
      skin={SKIN}
      sleeveColor={st.jacket}
      sleeveRatio={1.86}
      cuffColor={st.shirt}
      handShape={shapeL}
      handFlipX
    />
  );

  const renderRightArm = () => (
    <CartoonArmIK
      shoulder={shR}
      handTarget={handR}
      upperLen={60}
      lowerLen={58}
      bend={rightElbowBend}
      thickness={23}
      skin={SKIN}
      sleeveColor={st.jacket}
      sleeveRatio={1.86}
      cuffColor={st.shirt}
      handShape={shapeR}
    />
  );

  return (
    <g transform={`translate(${x} ${y}) scale(${flipX ? -scale : scale} ${scale})`}>
      {/* Piernas largas de traje con zapatos Oxford */}
      <CartoonLegIK
        hip={hipL}
        foot={footL}
        thighLen={63}
        calfLen={62}
        bend={pose === 'caminando' ? -1 : 1}
        thickness={27}
        pantsColor={st.pants}
        shoeColor={st.shoe}
        footDir={-1}
      />
      <CartoonLegIK
        hip={hipR}
        foot={footR}
        thighLen={63}
        calfLen={62}
        bend={-1}
        thickness={27}
        pantsColor={st.pants}
        shoeColor={st.shoe}
        footDir={1}
      />
      <rect x="-38" y={hipY - 12} width="76" height="28" rx="12" fill={st.pants} stroke={CARTOON_INK} strokeWidth={CARTOON_STROKE} />

      <g transform={`rotate(${torsoLean} 0 -138)`}>
        {!leftArmFront && renderLeftArm()}
        {!rightArmFront && renderRightArm()}

        {/* SACO SASTRE + CAMISA/CHALECO + CORBATA */}
        <g transform={`translate(0 ${breathY})`}>
          {/* Saco principal */}
          <path
            d="M -47 -268
               C -50 -224 -52 -172 -50 -128
               C -20 -122 20 -122 50 -128
               C 52 -172 50 -224 47 -268
               C 18 -276 -18 -276 -47 -268 Z"
            fill={st.jacket}
            {...ink}
          />

          {/* Triángulo interior de camisa / chaleco / cuello tortuga */}
          <path d="M -22 -270 L 0 -192 L 22 -270 Z" fill={st.vest ?? st.shirt} {...ink} />
          {st.vest && <path d="M -16 -270 L 0 -222 L 16 -270 Z" fill={st.shirt} {...ink} />}

          {/* Corbata (cuando no es cuello de tortuga) */}
          {!st.turtleneck && (
            <path d="M -6 -258 L 6 -258 L 9 -212 L 0 -196 L -9 -212 Z" fill={st.tie} {...ink} />
          )}

          {/* Solapas del saco */}
          <path d="M -22 -270 L -32 -236 L -14 -226 L 0 -192" fill={st.lapel} {...ink} />
          <path d="M 22 -270 L 32 -236 L 14 -226 L 0 -192" fill={st.lapel} {...ink} />

          {/* Línea central y botones de saco */}
          <line x1="0" y1="-192" x2="0" y2="-126" stroke={CARTOON_INK} strokeWidth="3.6" />
          <circle cx="12" cy="-174" r="3.8" fill={CARTOON_INK} />
          <circle cx="12" cy="-150" r="3.8" fill={CARTOON_INK} />

          {/* Pañuelo de bolsillo en el pecho */}
          <path d="M 18 -232 L 36 -232 L 32 -242 L 22 -238 Z" fill={st.hatBand} stroke={CARTOON_INK} strokeWidth="2.8" strokeLinejoin="round" />
        </g>

        {leftArmFront && renderLeftArm()}
        {rightArmFront && renderRightArm()}

        {/* CABEZA CON SOMBRERO FEDORA / TRILBY */}
        <g transform={`translate(0 ${-318 + breathY + headLagY}) rotate(${headTilt})`}>
          <ellipse cx="-62" cy="4" rx="13" ry="17" fill={SKIN} {...ink} />
          <ellipse cx="62" cy="4" rx="13" ry="17" fill={SKIN} {...ink} />

          {/* Cabello lateral prolijo */}
          <path
            d="M -60 -16 C -64 -44 64 -44 60 -16 C 62 0 58 12 52 16 L 48 -14 L -48 -14 L -52 16 C -58 12 -62 0 -60 -16 Z"
            fill={HAIR}
            {...ink}
          />

          {/* Óvalo facial de la misma línea gráfica */}
          <ellipse cx="0" cy="4" rx="59" ry="48" fill={SKIN} {...ink} />

          <CartoonFaceFeatures
            mood={mood}
            blink={blink}
            lookX={lookX}
            lookY={lookY}
            mouthOpen={mouthOpen}
            eyeSpacing={31}
            eyeY={2}
            mouthY={30}
            hideMouthWhenClosed={facialHair === 'bigote_fino'}
            blush={blush}
            tears={tears}
          />

          {/* Vello facial modular opcional (por defecto 'limpio' para máxima distinción IP) */}
          {facialHair === 'perilla' && (
            <path d="M -16 38 Q 0 52 16 38 Q 0 43 -16 38 Z" fill={HAIR} stroke={CARTOON_INK} strokeWidth="2.8" strokeLinejoin="round" />
          )}
          {facialHair === 'bigote_fino' && (
            <path d="M -26 24 Q 0 15 26 24 Q 0 21 -26 24 Z" fill={HAIR} stroke={CARTOON_INK} strokeWidth="2.8" strokeLinejoin="round" />
          )}

          {/* SOMBRERO FEDORA / TRILBY DE FIELTRO CON CINTA */}
          <g>
            {/* Copa moldeada */}
            <path
              d="M -56 -22
                 L -46 -76
                 C -26 -84 -10 -74 0 -74
                 C 10 -74 26 -84 46 -76
                 L 56 -22 Z"
              fill={st.hat}
              {...ink}
            />
            {/* Cinta del sombrero */}
            <path d="M -55 -24 L 55 -24 L 53 -38 L -53 -38 Z" fill={st.hatBand} {...ink} />
            {/* Ala curva elegante */}
            <path
              d="M -86 -18
                 C -42 -28 42 -28 86 -18
                 C 50 -8 -50 -8 -86 -18 Z"
              fill={st.hat}
              {...ink}
            />
          </g>
        </g>
      </g>
    </g>
  );
};
