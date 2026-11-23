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

export type BaseOutfit = 'base' | 'vecindad' | 'abrigo';
export type MustacheVariant = 'muesca' | 'frondoso' | 'sin_bigote';
export type HatVariant = 'casco' | 'boina' | 'gorra_plana' | 'sin_sombrero';

export interface Personaje1BaseProps {
  /** Origen en el centro del suelo (pies en y=0, cabeza alrededor de y=-330) */
  x?: number;
  y?: number;
  scale?: number;
  flipX?: boolean;
  frame?: number;
  animated?: boolean;
  pose?: CartoonPose;
  mood?: CartoonMood;
  outfit?: BaseOutfit;
  mustache?: MustacheVariant;
  hat?: HatVariant;
  mouthOpen?: number;
  lookX?: number;
  lookY?: number;
  tears?: boolean;
  blush?: boolean;
  /** Sobreescrituras directas de manos para coreografía libre en Remotion */
  leftHandOverride?: Vec2;
  rightHandOverride?: Vec2;
}

const OUTFIT_STYLES: Record<
  BaseOutfit,
  {
    shirt: string;
    sleeve: string;
    sleeveRatio: number;
    cuff?: string;
    pants: string;
    shoe: string;
    hatFill: string;
    defaultHat: HatVariant;
    accent?: string;
  }
> = {
  // Referencia estandarizada del personaje original
  base: {
    shirt: '#42474a',
    sleeve: '#42474a',
    sleeveRatio: 0.62,
    pants: '#1e272c',
    shoe: '#14191d',
    hatFill: '#cbdbff',
    defaultHat: 'casco',
  },
  // Variante IP-Safe para narrativa de la vecindad (cero infracción de marca registrada)
  vecindad: {
    shirt: '#c7b59a',
    sleeve: '#c7b59a',
    sleeveRatio: 1.38,
    cuff: '#a89479',
    pants: '#524136',
    shoe: '#2c221c',
    hatFill: '#6b8e78',
    defaultHat: 'boina',
    accent: '#8a6d4b',
  },
  // Variante dramática / invernal para pasajes crudos del libro
  abrigo: {
    shirt: '#2e3a46',
    sleeve: '#2e3a46',
    sleeveRatio: 1.82,
    cuff: '#1f2831',
    pants: '#23282e',
    shoe: '#15181c',
    hatFill: '#4a5568',
    defaultHat: 'gorra_plana',
    accent: '#d98a3c',
  },
};

const SKIN = '#d7b180';

/**
 * PERSONAJE 1 (BASE CORREGIDO Y ESTANDARIZADO): Hombre con Bigote y Sombrero/Casco.
 * - Anatomía completa, simétrica y coherente (pies, piernas IK, torso independiente, brazos IK, cabeza).
 * - Independiente de su antigua pose estática señalando: adopta 8 poses dinámicas naturales.
 * - Soporta 7 expresiones faciales, cambios de vestuario, gorro/sombrero y estilo de bigote.
 */
export const Personaje1Base: React.FC<Personaje1BaseProps> = ({
  x = 0,
  y = 0,
  scale = 1,
  flipX = false,
  frame = 0,
  animated = false,
  pose = 'neutral',
  mood = 'serio',
  outfit = 'base',
  mustache = 'muesca',
  hat,
  mouthOpen = 0,
  lookX = 0,
  lookY = 0,
  tears = false,
  blush = false,
  leftHandOverride,
  rightHandOverride,
}) => {
  const st = OUTFIT_STYLES[outfit];
  const activeHat = hat ?? st.defaultHat;
  const ink = inkProps();

  const breathY = animated ? Math.sin(frame * 0.09) * 2.5 : 0;
  const headLagY = animated ? Math.sin((frame - 4) * 0.09) * 1.8 : 0;
  const walkPhase = animated ? Math.sin(frame * 0.24) : 0.75;
  const blink = cartoonBlink(frame, animated, 11);

  // Coordenadas locales con pies apoyados en y = 0 (altura total ~365 px)
  const hipY = pose === 'triste_encogido' ? -104 : pose === 'señalando' ? -104 : -112;
  const hipL: Vec2 = {x: -24, y: hipY};
  const hipR: Vec2 = {x: 24, y: hipY};

  // Posiciones de pies según postura corporal (anatomía equilibrada y estable)
  let footL: Vec2 = {x: -32, y: -17};
  let footR: Vec2 = {x: 32, y: -17};
  let torsoLean = 0;
  let headTilt = animated ? Math.sin(frame * 0.05) * 2 : 0;

  if (pose === 'caminando') {
    footL = {x: -24 - walkPhase * 30, y: -17 - Math.max(0, -walkPhase) * 14};
    footR = {x: 24 + walkPhase * 30, y: -17 - Math.max(0, walkPhase) * 14};
    torsoLean = 4;
  } else if (pose === 'señalando') {
    footL = {x: -64, y: -17};
    footR = {x: 54, y: -17};
    torsoLean = -4;
  } else if (pose === 'triste_encogido') {
    footL = {x: -24, y: -17};
    footR = {x: 24, y: -17};
    torsoLean = 6;
    headTilt = 11;
  } else if (pose === 'celebrando') {
    footL = {x: -42, y: -17};
    footR = {x: 42, y: -17};
    headTilt = -4;
  } else if (pose === 'pensativo') {
    headTilt = 7;
  }

  // Hombros (anclados en el torso)
  const shL: Vec2 = {x: -48, y: -214 + breathY};
  const shR: Vec2 = {x: 48, y: -214 + breathY};

  // Objetivos de manos IK + gesto según postura
  let handL: Vec2 = {x: -68, y: -120 + breathY};
  let handR: Vec2 = {x: 68, y: -120 + breathY};
  let shapeL: HandShape = 'abierta';
  let shapeR: HandShape = 'abierta';

  if (pose === 'caminando') {
    handL = {x: -78 + walkPhase * 12, y: -134 - walkPhase * 18 + breathY};
    handR = {x: 78 - walkPhase * 12, y: -134 + walkPhase * 18 + breathY};
  } else if (pose === 'explicando') {
    const gest = animated ? Math.sin(frame * 0.16) * 8 : 0;
    handL = {x: -96, y: -176 + gest + breathY};
    handR = {x: 98, y: -186 - gest + breathY};
    shapeL = 'palma_arriba';
    shapeR = 'palma_arriba';
  } else if (pose === 'brazos_cruzados') {
    handL = {x: 24, y: -162 + breathY};
    handR = {x: -24, y: -158 + breathY};
    shapeL = 'puno';
    shapeR = 'puno';
  } else if (pose === 'pensativo') {
    handL = {x: -64, y: -126 + breathY};
    handR = {x: 22, y: -230 + breathY};
    shapeL = 'abierta';
    shapeR = 'puno';
  } else if (pose === 'celebrando') {
    const cheer = animated ? Math.sin(frame * 0.22) * 12 : 0;
    handL = {x: -104, y: -292 + cheer};
    handR = {x: 104, y: -292 - cheer};
    shapeL = 'abierta';
    shapeR = 'abierta';
  } else if (pose === 'triste_encogido') {
    handL = {x: -48, y: -116 + breathY};
    handR = {x: 48, y: -116 + breathY};
  } else if (pose === 'señalando') {
    handL = {x: -132, y: -286 + breathY};
    handR = {x: 78, y: -146 + breathY};
    shapeL = 'senalando';
    shapeR = 'puno';
  }

  if (leftHandOverride) handL = leftHandOverride;
  if (rightHandOverride) handR = rightHandOverride;

  const leftArmFront = pose === 'brazos_cruzados';
  const rightArmFront = pose === 'brazos_cruzados' || pose === 'pensativo';

  // Signos anatómicos correctos de codo:
  // Brazo izquierdo (hacia -X/+Y): bend=-1 dobla el codo hacia ABAJO/afuera naturalmente.
  // Brazo derecho (hacia +X/+Y): bend=+1 dobla el codo hacia ABAJO/afuera naturalmente.
  const leftElbowBend: 1 | -1 = pose === 'brazos_cruzados' ? 1 : -1;
  const rightElbowBend: 1 | -1 = pose === 'brazos_cruzados' ? -1 : 1;

  const renderLeftArm = () => (
    <CartoonArmIK
      shoulder={shL}
      handTarget={handL}
      upperLen={52}
      lowerLen={50}
      bend={leftElbowBend}
      thickness={25}
      skin={SKIN}
      sleeveColor={st.sleeve}
      sleeveRatio={st.sleeveRatio}
      cuffColor={st.cuff}
      handShape={shapeL}
      handFlipX
    />
  );

  const renderRightArm = () => (
    <CartoonArmIK
      shoulder={shR}
      handTarget={handR}
      upperLen={52}
      lowerLen={50}
      bend={rightElbowBend}
      thickness={25}
      skin={SKIN}
      sleeveColor={st.sleeve}
      sleeveRatio={st.sleeveRatio}
      cuffColor={st.cuff}
      handShape={shapeR}
    />
  );

  return (
    <g transform={`translate(${x} ${y}) scale(${flipX ? -scale : scale} ${scale})`}>
      {/* ================================================================
          CADERA Y PIERNAS ARTICULADAS IK + BOTAS (SIN CRUCE EN X)
         ================================================================ */}
      <CartoonLegIK
        hip={hipL}
        foot={footL}
        thighLen={49}
        calfLen={48}
        bend={pose === 'caminando' ? -1 : 1}
        thickness={31}
        pantsColor={st.pants}
        shoeColor={st.shoe}
        footDir={-1}
      />
      <CartoonLegIK
        hip={hipR}
        foot={footR}
        thighLen={49}
        calfLen={48}
        bend={-1}
        thickness={31}
        pantsColor={st.pants}
        shoeColor={st.shoe}
        footDir={1}
      />
      {/* Puente de pelvis limpio uniendo ambas piernas bajo el borde de la camiseta */}
      <rect x="-42" y={hipY - 12} width="84" height="30" rx="14" fill={st.pants} stroke={CARTOON_INK} strokeWidth={CARTOON_STROKE} />

      {/* Bloque superior con inclinación natural de torso */}
      <g transform={`rotate(${torsoLean} 0 -115)`}>
        {/* Brazos detrás cuando están relajados o abiertos */}
        {!leftArmFront && renderLeftArm()}
        {!rightArmFront && renderRightArm()}

        {/* ================================================================
            TORSO PROPORCIONADO + VARIANTES DE VESTUARIO
           ================================================================ */}
        <g transform={`translate(0 ${breathY})`}>
          {/* Camiseta / Suéter / Abrigo base */}
          <path
            d="M -49 -224
               C -54 -190 -58 -145 -56 -108
               C -24 -101 24 -101 56 -108
               C 58 -145 54 -190 49 -224
               C 20 -232 -20 -232 -49 -224 Z"
            fill={st.shirt}
            {...ink}
          />

          {/* Detalles específicos del vestuario Vecindad (botones Henley y cuello) */}
          {outfit === 'vecindad' && (
            <g>
              <path d="M -18 -226 L 0 -196 L 18 -226" fill="none" stroke={st.accent} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" />
              <line x1="0" y1="-196" x2="0" y2="-168" stroke={CARTOON_INK} strokeWidth="3.2" strokeLinecap="round" />
              <circle cx="0" cy="-185" r="3" fill={CARTOON_INK} />
              <circle cx="0" cy="-173" r="3" fill={CARTOON_INK} />
            </g>
          )}

          {/* Detalles específicos del vestuario Abrigo (solapas + bufanda cálida) */}
          {outfit === 'abrigo' && (
            <g>
              <line x1="0" y1="-215" x2="0" y2="-104" stroke={CARTOON_INK} strokeWidth="3.8" />
              <circle cx="14" cy="-168" r="4" fill="#15181c" />
              <circle cx="14" cy="-140" r="4" fill="#15181c" />
              {/* Bufanda ocre alrededor del cuello */}
              <path
                d="M -42 -224 C -18 -210 18 -210 42 -224 L 46 -206 C 18 -194 -18 -194 -46 -206 Z"
                fill={st.accent}
                {...ink}
              />
              <path d="M 14 -202 L 32 -202 L 36 -156 L 16 -156 Z" fill={st.accent} {...ink} />
            </g>
          )}
        </g>

        {/* Brazos delante cuando cruza brazos o apoya mano en barbilla */}
        {leftArmFront && renderLeftArm()}
        {rightArmFront && renderRightArm()}

        {/* ================================================================
            CABEZA ESTANDARIZADA + OREJAS + CABELLO + ROSTRO + BIGOTE + SOMBRERO
           ================================================================ */}
        <g transform={`translate(0 ${-274 + breathY + headLagY}) rotate(${headTilt})`}>
          {/* Orejas redondeadas simétricas */}
          <ellipse cx="-66" cy="4" rx="14" ry="18" fill={SKIN} {...ink} />
          <ellipse cx="66" cy="4" rx="14" ry="18" fill={SKIN} {...ink} />

          {/* Cabello negro corto lateral/posterior (firma del personaje original) */}
          <path
            d="M -64 -16 C -68 -48 68 -48 64 -16 C 68 4 64 16 56 20 L 52 -12 L -52 -12 L -56 20 C -64 16 -68 4 -64 -16 Z"
            fill={CARTOON_INK}
            {...ink}
          />

          {/* Óvalo facial amplio característico */}
          <ellipse cx="0" cy="4" rx="64" ry="50" fill={SKIN} {...ink} />

          {/* Ojos, cejas y boca expresivos */}
          <CartoonFaceFeatures
            mood={mood}
            blink={blink}
            lookX={lookX}
            lookY={lookY}
            mouthOpen={mouthOpen}
            eyeSpacing={34}
            eyeY={4}
            mouthY={33}
            hideMouthWhenClosed={mustache !== 'sin_bigote'}
            blush={blush}
            tears={tears}
          />

          {/* Variantes de bigote (muesca icónica original, frondoso o sin bigote) */}
          {mustache === 'muesca' && (
            <path
              d="M -38 28 C -24 10 24 10 38 29 C 22 28 4 27 -12 27 L -16 21 L -21 27 Z"
              fill="#101113"
              stroke={CARTOON_INK}
              strokeWidth="3.2"
              strokeLinejoin="round"
            />
          )}
          {mustache === 'frondoso' && (
            <path
              d="M -42 32 C -34 10 34 10 42 32 C 26 35 12 31 0 32 C -12 31 -26 35 -42 32 Z"
              fill="#101113"
              stroke={CARTOON_INK}
              strokeWidth="3.2"
              strokeLinejoin="round"
            />
          )}

          {/* Variantes de sombrero / casco */}
          {activeHat === 'casco' && (
            <path
              d="M -74 -18
                 L -65 -30
                 C -65 -58 -52 -86 0 -88
                 C 52 -86 65 -58 65 -30
                 L 74 -18
                 C 28 -14 -28 -14 -74 -18 Z"
              fill={st.hatFill}
              {...ink}
            />
          )}
          {activeHat === 'boina' && (
            <g>
              <path
                d="M -68 -20 C -74 -58 -40 -78 4 -78 C 46 -78 72 -58 68 -20 C 26 -14 -26 -14 -68 -20 Z"
                fill={st.hatFill}
                {...ink}
              />
              <path
                d="M -68 -20 C -26 -14 26 -14 68 -20 L 66 -32 C 26 -26 -26 -26 -66 -32 Z"
                fill="#52725e"
                {...ink}
              />
            </g>
          )}
          {activeHat === 'gorra_plana' && (
            <g>
              <path
                d="M -66 -22 C -64 -56 -24 -72 16 -68 C 52 -64 68 -44 64 -20 Z"
                fill={st.hatFill}
                {...ink}
              />
              <path d="M -78 -18 C -44 -26 22 -26 68 -20 C 30 -12 -36 -10 -78 -18 Z" fill="#323b49" {...ink} />
            </g>
          )}
          {activeHat === 'sin_sombrero' && (
            <path
              d="M -60 -18 C -58 -56 58 -56 60 -18 C 36 -32 -36 -32 -60 -18 Z"
              fill={CARTOON_INK}
              {...ink}
            />
          )}
        </g>
      </g>
    </g>
  );
};
