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

export type NinaOutfit = 'base' | 'vecindad' | 'lluvia';

export interface Personaje2NinaProps {
  x?: number;
  y?: number;
  scale?: number;
  flipX?: boolean;
  frame?: number;
  animated?: boolean;
  pose?: CartoonPose;
  mood?: CartoonMood;
  outfit?: NinaOutfit;
  glasses?: boolean;
  mouthOpen?: number;
  lookX?: number;
  lookY?: number;
  tears?: boolean;
  blush?: boolean;
  leftHandOverride?: Vec2;
  rightHandOverride?: Vec2;
}

const SKIN = '#dfba8d';
const HAIR = '#241c19';

const OUTFIT_STYLES: Record<
  NinaOutfit,
  {
    dress: string;
    collar: string;
    sleeve: string;
    sleeveRatio: number;
    ribbon: string;
    sock: string;
    shoe: string;
    cardigan?: string;
    cape?: string;
  }
> = {
  // Look base estandarizado: vestido mostaza cálido + cuello crema + lazos turquesa
  base: {
    dress: '#e2a84b',
    collar: '#f4efe6',
    sleeve: '#e2a84b',
    sleeveRatio: 0.56,
    ribbon: '#4a9b96',
    sock: '#f4efe6',
    shoe: '#2b221e',
  },
  // Variante IP-Safe Vecindad: vestido terracota + cárdigan abierto crema + lazos ámbar
  vecindad: {
    dress: '#c45d4a',
    collar: '#f4efe6',
    sleeve: '#ebe2cf',
    sleeveRatio: 1.48,
    ribbon: '#e2a84b',
    sock: '#f4efe6',
    shoe: '#2d231e',
    cardigan: '#ebe2cf',
  },
  // Variante dramática / lluvia para capítulos emotivos del libro
  lluvia: {
    dress: '#506d84',
    collar: '#dbe4ec',
    sleeve: '#d9b34a',
    sleeveRatio: 1.72,
    ribbon: '#506d84',
    sock: '#dbe4ec',
    shoe: '#283847',
    cape: '#d9b34a',
  },
};

/**
 * PERSONAJE 2: Niña con Vestido y Coletas.
 * Misma línea gráfica exacta del Personaje Base (tinta #0b0d10, trazo 4.4, rellenos planos,
 * cabeza ovalada expresiva, ojos sólidos, brazos y piernas IK de 2 segmentos).
 * Proporción infantil (~0.82× altura del adulto base).
 */
export const Personaje2Nina: React.FC<Personaje2NinaProps> = ({
  x = 0,
  y = 0,
  scale = 1,
  flipX = false,
  frame = 0,
  animated = false,
  pose = 'neutral',
  mood = 'feliz',
  outfit = 'base',
  glasses = false,
  mouthOpen = 0,
  lookX = 0,
  lookY = 0,
  tears = false,
  blush = true,
  leftHandOverride,
  rightHandOverride,
}) => {
  const st = OUTFIT_STYLES[outfit];
  const ink = inkProps();

  const breathY = animated ? Math.sin(frame * 0.1) * 2.2 : 0;
  const headLagY = animated ? Math.sin((frame - 4) * 0.1) * 1.6 : 0;
  const hairSway = animated ? Math.sin((frame - 7) * 0.12) * 5.5 : 0;
  const walkPhase = animated ? Math.sin(frame * 0.26) : 0.72;
  const blink = cartoonBlink(frame, animated, 23);

  // Coordenadas locales con pies en y = 0 (altura total ~306 px ≈ 0.83× adulto base)
  const hipY = pose === 'triste_encogido' ? -88 : -94;
  const hipL: Vec2 = {x: -18, y: hipY};
  const hipR: Vec2 = {x: 18, y: hipY};

  let footL: Vec2 = {x: -24, y: -15};
  let footR: Vec2 = {x: 24, y: -15};
  let torsoLean = 0;
  let headTilt = animated ? Math.sin(frame * 0.06) * 2.4 : 0;

  if (pose === 'caminando') {
    footL = {x: -18 - walkPhase * 26, y: -15 - Math.max(0, -walkPhase) * 14};
    footR = {x: 18 + walkPhase * 26, y: -15 - Math.max(0, walkPhase) * 14};
    torsoLean = 4;
  } else if (pose === 'triste_encogido') {
    footL = {x: -18, y: -15};
    footR = {x: 18, y: -15};
    torsoLean = 6;
    headTilt = 10;
  } else if (pose === 'celebrando') {
    footL = {x: -32, y: -15};
    footR = {x: 32, y: -15};
    headTilt = -5;
  } else if (pose === 'pensativo') {
    headTilt = 8;
  } else if (pose === 'señalando') {
    footL = {x: -40, y: -15};
    footR = {x: 36, y: -15};
    torsoLean = -3;
  }

  const shL: Vec2 = {x: -34, y: -182 + breathY};
  const shR: Vec2 = {x: 34, y: -182 + breathY};

  let handL: Vec2 = {x: -54, y: -108 + breathY};
  let handR: Vec2 = {x: 54, y: -108 + breathY};
  let shapeL: HandShape = 'abierta';
  let shapeR: HandShape = 'abierta';

  if (pose === 'caminando') {
    handL = {x: -64 + walkPhase * 12, y: -116 - walkPhase * 16 + breathY};
    handR = {x: 64 - walkPhase * 12, y: -116 + walkPhase * 16 + breathY};
  } else if (pose === 'explicando') {
    const g = animated ? Math.sin(frame * 0.18) * 8 : 0;
    handL = {x: -78, y: -152 + g + breathY};
    handR = {x: 80, y: -162 - g + breathY};
    shapeL = 'palma_arriba';
    shapeR = 'palma_arriba';
  } else if (pose === 'brazos_cruzados') {
    handL = {x: 18, y: -140 + breathY};
    handR = {x: -18, y: -136 + breathY};
    shapeL = 'puno';
    shapeR = 'puno';
  } else if (pose === 'pensativo') {
    handL = {x: -46, y: -114 + breathY};
    handR = {x: 18, y: -198 + breathY};
    shapeR = 'puno';
  } else if (pose === 'celebrando') {
    const ch = animated ? Math.sin(frame * 0.24) * 10 : 0;
    handL = {x: -78, y: -248 + ch};
    handR = {x: 78, y: -248 - ch};
  } else if (pose === 'triste_encogido') {
    handL = {x: -36, y: -104 + breathY};
    handR = {x: 36, y: -104 + breathY};
  } else if (pose === 'señalando') {
    handL = {x: -98, y: -236 + breathY};
    handR = {x: 58, y: -120 + breathY};
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
      upperLen={42}
      lowerLen={40}
      bend={leftElbowBend}
      thickness={19}
      skin={SKIN}
      sleeveColor={st.sleeve}
      sleeveRatio={st.sleeveRatio}
      handShape={shapeL}
      handFlipX
    />
  );

  const renderRightArm = () => (
    <CartoonArmIK
      shoulder={shR}
      handTarget={handR}
      upperLen={42}
      lowerLen={40}
      bend={rightElbowBend}
      thickness={19}
      skin={SKIN}
      sleeveColor={st.sleeve}
      sleeveRatio={st.sleeveRatio}
      handShape={shapeR}
    />
  );

  return (
    <g transform={`translate(${x} ${y}) scale(${flipX ? -scale : scale} ${scale})`}>
      {/* Piernas infantiles limpias con calcetas y zapatos Mary-Jane bajo el vestido */}
      <CartoonLegIK
        hip={hipL}
        foot={footL}
        thighLen={41}
        calfLen={40}
        bend={pose === 'caminando' ? -1 : 1}
        thickness={20}
        pantsColor={SKIN}
        shoeColor={st.shoe}
        sockColor={st.sock}
        shortsMode
        skinColor={SKIN}
        footDir={-1}
      />
      <CartoonLegIK
        hip={hipR}
        foot={footR}
        thighLen={41}
        calfLen={40}
        bend={-1}
        thickness={20}
        pantsColor={SKIN}
        shoeColor={st.shoe}
        sockColor={st.sock}
        shortsMode
        skinColor={SKIN}
        footDir={1}
      />

      <g transform={`rotate(${torsoLean} 0 -95)`}>
        {!leftArmFront && renderLeftArm()}
        {!rightArmFront && renderRightArm()}

        {/* VESTIDO ACAMPANADO (A-LINE) + VARIANTES */}
        <g transform={`translate(0 ${breathY})`}>
          <path
            d="M -34 -188
               C -40 -146 -56 -112 -64 -78
               C -26 -70 26 -70 64 -78
               C 56 -112 40 -146 34 -188
               C 14 -195 -14 -195 -34 -188 Z"
            fill={st.dress}
            {...ink}
          />

          {/* Pliegue vertical sutil del vestido */}
          <path d="M -22 -108 L -28 -76 M 22 -108 L 28 -76" fill="none" stroke={CARTOON_INK} strokeWidth="3.2" strokeLinecap="round" opacity="0.45" />

          {/* Cuello Peter Pan redondeado crema */}
          <path
            d="M -26 -188 C -22 -170 -6 -168 0 -178 C 6 -168 22 -170 26 -188 C 10 -193 -10 -193 -26 -188 Z"
            fill={st.collar}
            {...ink}
          />

          {/* Cárdigan tejido abierto (variante Vecindad IP-Safe) */}
          {st.cardigan && (
            <g>
              <path
                d="M -36 -188 L -10 -184 L -14 -102 L -46 -104 C -44 -134 -40 -162 -36 -188 Z"
                fill={st.cardigan}
                {...ink}
              />
              <path
                d="M 36 -188 L 10 -184 L 14 -102 L 46 -104 C 44 -134 40 -162 36 -188 Z"
                fill={st.cardigan}
                {...ink}
              />
              <circle cx="-19" cy="-152" r="3" fill={CARTOON_INK} />
              <circle cx="-20" cy="-130" r="3" fill={CARTOON_INK} />
            </g>
          )}

          {/* Capa impermeable (variante Lluvia) */}
          {st.cape && (
            <path
              d="M -38 -188 C -52 -152 -60 -122 -64 -102 C -24 -94 24 -94 64 -102 C 60 -122 52 -152 38 -188 C 14 -194 -14 -194 -38 -188 Z"
              fill={st.cape}
              {...ink}
            />
          )}
        </g>

        {leftArmFront && renderLeftArm()}
        {rightArmFront && renderRightArm()}

        {/* CABEZA CON COLETAS SIMÉTRICAS Y LAZOS (MISMA BIBLIA DE ESTILO) */}
        <g transform={`translate(0 ${-234 + breathY + headLagY}) rotate(${headTilt})`}>
          {/* Coleta izquierda (pigtail con rebote orgánico) */}
          <g transform={`translate(-60 -16) rotate(${-14 + hairSway})`}>
            <path
              d="M 0 -4 C -28 -18 -46 10 -34 38 C -24 52 -6 46 -4 26 C -2 12 4 4 0 -4 Z"
              fill={HAIR}
              {...ink}
            />
            {/* Lazo / Moño izquierdo */}
            <ellipse cx="-6" cy="-2" rx="11" ry="7" fill={st.ribbon} {...ink} />
          </g>

          {/* Coleta derecha (pigtail simétrica) */}
          <g transform={`translate(60 -16) rotate(${14 - hairSway})`}>
            <path
              d="M 0 -4 C 28 -18 46 10 34 38 C 24 52 6 46 4 26 C 2 12 -4 4 0 -4 Z"
              fill={HAIR}
              {...ink}
            />
            {/* Lazo / Moño derecho */}
            <ellipse cx="6" cy="-2" rx="11" ry="7" fill={st.ribbon} {...ink} />
          </g>

          {/* Orejas redondeadas */}
          <ellipse cx="-56" cy="4" rx="12" ry="15" fill={SKIN} {...ink} />
          <ellipse cx="56" cy="4" rx="12" ry="15" fill={SKIN} {...ink} />

          {/* Óvalo facial (misma proporción amigable que Personaje 1) */}
          <ellipse cx="0" cy="4" rx="55" ry="45" fill={SKIN} {...ink} />

          {/* Melena superior y flequillo limpio */}
          <path
            d="M -56 -4
               C -58 -52 58 -52 56 -4
               C 40 -20 18 -24 6 -16
               C -6 -24 -28 -24 -56 -4 Z"
            fill={HAIR}
            {...ink}
          />

          {/* Rasgos faciales compartidos */}
          <CartoonFaceFeatures
            mood={mood}
            blink={blink}
            lookX={lookX}
            lookY={lookY}
            mouthOpen={mouthOpen}
            eyeSpacing={29}
            eyeY={4}
            mouthY={27}
            blush={blush}
            tears={tears}
          />

          {/* Lentes rectangulares opcionales (apagados por defecto para mayor seguridad IP) */}
          {glasses && (
            <g fill="none" stroke={CARTOON_INK} strokeWidth="3.4">
              <rect x="-44" y="-8" width="30" height="22" rx="6" fill="#ffffff" fillOpacity="0.18" />
              <rect x="14" y="-8" width="30" height="22" rx="6" fill="#ffffff" fillOpacity="0.18" />
              <line x1="-14" y1="2" x2="14" y2="2" />
            </g>
          )}
        </g>
      </g>
    </g>
  );
};
