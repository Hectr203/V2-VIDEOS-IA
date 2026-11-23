import React from 'react';

/**
 * Biblia de Estilo Unificada — Universo Cartoon Editorial "Vecindad"
 * Derivada directamente del personaje base de referencia:
 * - Contorno uniforme negro tinta (#0b0d10) con remates y uniones redondeadas.
 * - Rellenos planos (flat cel) de paleta cálida/desaturada editorial con coherencia cromática absoluta.
 * - Cabeza ovalada expresiva (ancho > alto), ojos circulares sólidos, orejas redondeadas integradas.
 * - Extremidades articuladas con Cinemática Inversa 2D (IK) de 2 segmentos para poses naturales sin rigidez.
 */

export type Vec2 = {x: number; y: number};

export type CartoonMood =
  | 'serio'
  | 'enojado'
  | 'feliz'
  | 'triste'
  | 'sorpresa'
  | 'pensativo'
  | 'hablando';

export type CartoonPose =
  | 'neutral'
  | 'caminando'
  | 'explicando'
  | 'brazos_cruzados'
  | 'pensativo'
  | 'celebrando'
  | 'triste_encogido'
  | 'señalando';

export type HandShape = 'abierta' | 'puno' | 'senalando' | 'palma_arriba';

export const CARTOON_INK = '#0b0d10';
export const CARTOON_STROKE = 4.4;
export const CARTOON_BG_WARM = '#9f9890';
export const CARTOON_SHEET_BG = '#ebe6de';
export const CARTOON_CARD_BG = '#f6f2eb';

export const inkProps = (strokeWidth = CARTOON_STROKE) => ({
  stroke: CARTOON_INK,
  strokeWidth,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
});

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));

/** Cinemática Inversa 2D (IK) para brazos y piernas articulados sin romper proporciones */
export function solveIK2D(root: Vec2, target: Vec2, l1: number, l2: number, bend: 1 | -1 = 1): Vec2 {
  const dx = target.x - root.x;
  const dy = target.y - root.y;
  const d = clamp(Math.hypot(dx, dy), 2, l1 + l2 - 0.5);
  const cosAngle = clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1);
  const angle = Math.atan2(dy, dx) + bend * Math.acos(cosAngle);
  return {
    x: root.x + Math.cos(angle) * l1,
    y: root.y + Math.sin(angle) * l1,
  };
}

/** Parpadeo estocástico determinista para animación viva */
export function cartoonBlink(frame: number, animated: boolean, seed = 0): number {
  if (!animated) return 1;
  const period = 108 + (seed % 29);
  const local = (frame + seed * 17) % period;
  if (local < period - 6) return 1;
  return clamp(Math.abs(local - (period - 3)) / 3, 0.08, 1);
}

/** Mano cartoon modular con contorno negro limpio y múltiples gestos */
export const CartoonHand: React.FC<{
  x: number;
  y: number;
  angleDeg?: number;
  skin: string;
  shape?: HandShape;
  flipX?: boolean;
  scale?: number;
}> = ({x, y, angleDeg = 0, skin, shape = 'abierta', flipX = false, scale = 1}) => {
  const sx = flipX ? -scale : scale;
  const ink = inkProps(CARTOON_STROKE / Math.max(0.75, scale));

  return (
    <g transform={`translate(${x} ${y}) rotate(${angleDeg}) scale(${sx} ${scale})`}>
      {shape === 'puno' && (
        <>
          <path
            d="M -11 -10 C -14 -4 -14 10 -6 14 C 4 17 15 12 15 0 C 15 -10 8 -14 -2 -13 Z"
            fill={skin}
            {...ink}
          />
          <path d="M -2 -3 Q 5 -2 7 6" fill="none" {...ink} />
        </>
      )}
      {shape === 'abierta' && (
        <>
          <path
            d="M -10 -11 C -15 -3 -14 10 -5 14 C 3 17 14 13 16 2 C 17 -6 12 -14 4 -14 C 0 -14 -2 -11 -4 -11 C -6 -13 -8 -13 -10 -11 Z"
            fill={skin}
            {...ink}
          />
          <path d="M -12 -1 Q -19 1 -15 8 Q -11 11 -6 8" fill={skin} {...ink} />
        </>
      )}
      {shape === 'palma_arriba' && (
        <>
          <path
            d="M -12 -4 C -14 6 -6 14 5 14 C 15 14 22 6 20 -3 C 19 -8 12 -9 7 -6 C 4 -12 -4 -13 -7 -7 Z"
            fill={skin}
            {...ink}
          />
          <path d="M 4 -2 Q 11 -2 15 3" fill="none" {...ink} />
        </>
      )}
      {shape === 'senalando' && (
        <>
          <path
            d="M -11 -10 L -11 8 C -11 14 -3 17 4 15 C 12 13 15 7 14 0 L 29 -13 C 33 -17 29 -23 23 -19 L 9 -9 C 7 -14 1 -15 -3 -11 C -6 -14 -10 -13 -11 -10 Z"
            fill={skin}
            {...ink}
          />
          <path d="M 3 -6 L 10 0" fill="none" {...ink} />
        </>
      )}
    </g>
  );
};

/** Brazo articulado de 2 segmentos (hombro → codo → mano) con manga integrada y trazo continuo */
export const CartoonArmIK: React.FC<{
  shoulder: Vec2;
  handTarget: Vec2;
  upperLen: number;
  lowerLen: number;
  bend: 1 | -1;
  thickness: number;
  skin: string;
  sleeveColor: string;
  sleeveRatio?: number;
  handShape?: HandShape;
  handFlipX?: boolean;
  cuffColor?: string;
}> = ({
  shoulder,
  handTarget,
  upperLen,
  lowerLen,
  bend,
  thickness,
  skin,
  sleeveColor,
  sleeveRatio = 0.58,
  handShape = 'abierta',
  handFlipX = false,
  cuffColor,
}) => {
  const elbow = solveIK2D(shoulder, handTarget, upperLen, lowerLen, bend);
  const armPath = `M ${shoulder.x.toFixed(1)} ${shoulder.y.toFixed(1)} L ${elbow.x.toFixed(1)} ${elbow.y.toFixed(1)} L ${handTarget.x.toFixed(1)} ${handTarget.y.toFixed(1)}`;
  const handAngle = (Math.atan2(handTarget.y - elbow.y, handTarget.x - elbow.x) * 180) / Math.PI;

  // Punto exacto hasta donde llega la manga + vector unitario para remate recto limpio
  let sleeveEnd: Vec2;
  let sleeveFrom: Vec2;
  let sleevePath: string;
  if (sleeveRatio <= 1) {
    sleeveFrom = shoulder;
    sleeveEnd = {
      x: shoulder.x + (elbow.x - shoulder.x) * sleeveRatio,
      y: shoulder.y + (elbow.y - shoulder.y) * sleeveRatio,
    };
    sleevePath = `M ${shoulder.x.toFixed(1)} ${shoulder.y.toFixed(1)} L ${sleeveEnd.x.toFixed(1)} ${sleeveEnd.y.toFixed(1)}`;
  } else {
    const r2 = clamp(sleeveRatio - 1, 0, 0.88);
    sleeveFrom = elbow;
    sleeveEnd = {
      x: elbow.x + (handTarget.x - elbow.x) * r2,
      y: elbow.y + (handTarget.y - elbow.y) * r2,
    };
    sleevePath = `M ${shoulder.x.toFixed(1)} ${shoulder.y.toFixed(1)} L ${elbow.x.toFixed(1)} ${elbow.y.toFixed(1)} L ${sleeveEnd.x.toFixed(1)} ${sleeveEnd.y.toFixed(1)}`;
  }

  const sdx = sleeveEnd.x - sleeveFrom.x;
  const sdy = sleeveEnd.y - sleeveFrom.y;
  const slen = Math.max(1, Math.hypot(sdx, sdy));
  const nx = -sdy / slen;
  const ny = sdx / slen;
  const halfSleeve = (thickness + 8) * 0.5;
  const cuffLine = `M ${(sleeveEnd.x + nx * halfSleeve).toFixed(1)} ${(sleeveEnd.y + ny * halfSleeve).toFixed(1)} L ${(sleeveEnd.x - nx * halfSleeve).toFixed(1)} ${(sleeveEnd.y - ny * halfSleeve).toFixed(1)}`;

  return (
    <g>
      {/* Trazo exterior negro del brazo piel */}
      <path d={armPath} fill="none" stroke={CARTOON_INK} strokeWidth={thickness + CARTOON_STROKE * 2} strokeLinecap="round" strokeLinejoin="round" />
      {/* Relleno piel del brazo */}
      <path d={armPath} fill="none" stroke={skin} strokeWidth={thickness} strokeLinecap="round" strokeLinejoin="round" />

      {/* Manga limpia con hombrera redondeada y borde de puño recto estilo referencia */}
      <path d={sleevePath} fill="none" stroke={CARTOON_INK} strokeWidth={thickness + 8 + CARTOON_STROKE * 2} strokeLinecap="butt" strokeLinejoin="round" />
      <circle cx={shoulder.x} cy={shoulder.y} r={(thickness + 8) * 0.5 + CARTOON_STROKE} fill={CARTOON_INK} />
      <path d={sleevePath} fill="none" stroke={sleeveColor} strokeWidth={thickness + 8} strokeLinecap="butt" strokeLinejoin="round" />
      <circle cx={shoulder.x} cy={shoulder.y} r={(thickness + 8) * 0.5} fill={sleeveColor} />
      <path d={cuffLine} fill="none" stroke={CARTOON_INK} strokeWidth={CARTOON_STROKE} strokeLinecap="round" />

      {/* Puño contrastante opcional (suéter, camisa o marinero) */}
      {cuffColor && (
        <path d={cuffLine} fill="none" stroke={cuffColor} strokeWidth={CARTOON_STROKE * 1.4} strokeLinecap="round" />
      )}

      {/* Mano articulada */}
      <CartoonHand
        x={handTarget.x}
        y={handTarget.y}
        angleDeg={handAngle}
        skin={skin}
        shape={handShape}
        flipX={handFlipX}
        scale={thickness / 24}
      />
    </g>
  );
};

/** Pierna articulada de 2 segmentos (cadera → rodilla → tobillo → zapato/bota) */
export const CartoonLegIK: React.FC<{
  hip: Vec2;
  foot: Vec2;
  thighLen: number;
  calfLen: number;
  bend: 1 | -1;
  thickness: number;
  pantsColor: string;
  shoeColor: string;
  sockColor?: string;
  shortsMode?: boolean;
  skinColor?: string;
  footDir?: 1 | -1;
}> = ({
  hip,
  foot,
  thighLen,
  calfLen,
  bend,
  thickness,
  pantsColor,
  shoeColor,
  sockColor,
  shortsMode = false,
  skinColor = '#d7b180',
  footDir = 1,
}) => {
  const knee = solveIK2D(hip, foot, thighLen, calfLen, bend);
  const fullPath = `M ${hip.x.toFixed(1)} ${hip.y.toFixed(1)} L ${knee.x.toFixed(1)} ${knee.y.toFixed(1)} L ${foot.x.toFixed(1)} ${foot.y.toFixed(1)}`;
  const shortPath = `M ${hip.x.toFixed(1)} ${hip.y.toFixed(1)} L ${knee.x.toFixed(1)} ${knee.y.toFixed(1)}`;
  const sockTop = {
    x: knee.x + (foot.x - knee.x) * 0.55,
    y: knee.y + (foot.y - knee.y) * 0.55,
  };

  return (
    <g>
      {shortsMode ? (
        <>
          {/* Pantorrilla piel */}
          <path d={fullPath} fill="none" stroke={CARTOON_INK} strokeWidth={thickness * 0.82 + CARTOON_STROKE * 2} strokeLinecap="round" strokeLinejoin="round" />
          <path d={fullPath} fill="none" stroke={skinColor} strokeWidth={thickness * 0.82} strokeLinecap="round" strokeLinejoin="round" />
          {/* Calceta opcional */}
          {sockColor && (
            <>
              <path
                d={`M ${sockTop.x.toFixed(1)} ${sockTop.y.toFixed(1)} L ${foot.x.toFixed(1)} ${foot.y.toFixed(1)}`}
                fill="none"
                stroke={CARTOON_INK}
                strokeWidth={thickness * 0.86 + CARTOON_STROKE * 2}
                strokeLinecap="round"
              />
              <path
                d={`M ${sockTop.x.toFixed(1)} ${sockTop.y.toFixed(1)} L ${foot.x.toFixed(1)} ${foot.y.toFixed(1)}`}
                fill="none"
                stroke={sockColor}
                strokeWidth={thickness * 0.86}
                strokeLinecap="round"
              />
            </>
          )}
          {/* Short hasta la rodilla */}
          <path d={shortPath} fill="none" stroke={CARTOON_INK} strokeWidth={thickness + 6 + CARTOON_STROKE * 2} strokeLinecap="round" strokeLinejoin="round" />
          <path d={shortPath} fill="none" stroke={pantsColor} strokeWidth={thickness + 6} strokeLinecap="round" strokeLinejoin="round" />
        </>
      ) : (
        <>
          {/* Pantalón completo */}
          <path d={fullPath} fill="none" stroke={CARTOON_INK} strokeWidth={thickness + CARTOON_STROKE * 2} strokeLinecap="round" strokeLinejoin="round" />
          <path d={fullPath} fill="none" stroke={pantsColor} strokeWidth={thickness} strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}

      {/* Zapato / Bota aterrizado con volumen cartoon limpio */}
      <g transform={`translate(${foot.x} ${foot.y}) scale(${footDir} 1)`}>
        <path
          d="M -18 -8 L 16 -8 C 28 -8 35 1 35 9 C 35 15 30 17 22 17 L -18 17 C -24 17 -26 12 -24 5 Z"
          fill={shoeColor}
          {...inkProps()}
        />
      </g>
    </g>
  );
};

/** Ojos + Cejas + Boca compartidos para consistencia expresiva absoluta entre los 4 personajes */
export const CartoonFaceFeatures: React.FC<{
  mood: CartoonMood;
  blink: number;
  lookX?: number;
  lookY?: number;
  mouthOpen?: number;
  eyeSpacing?: number;
  eyeY?: number;
  mouthY?: number;
  eyebrowColor?: string;
  hideMouthWhenClosed?: boolean;
  blush?: boolean;
  tears?: boolean;
}> = ({
  mood,
  blink,
  lookX = 0,
  lookY = 0,
  mouthOpen = 0,
  eyeSpacing = 36,
  eyeY = 4,
  mouthY = 30,
  eyebrowColor = CARTOON_INK,
  hideMouthWhenClosed = false,
  blush = false,
  tears = false,
}) => {
  const dx = lookX * 4;
  const dy = lookY * 2.5;
  const rx = mood === 'sorpresa' ? 10.5 : 9.2;
  const ry = (mood === 'sorpresa' ? 11.5 : 9.6) * blink;

  return (
    <g>
      {/* Rubor sutil opcional */}
      {blush && (
        <>
          <ellipse cx={-eyeSpacing - 8} cy={eyeY + 14} rx="11" ry="5.5" fill="#d97773" opacity="0.34" />
          <ellipse cx={eyeSpacing + 8} cy={eyeY + 14} rx="11" ry="5.5" fill="#d97773" opacity="0.34" />
        </>
      )}

      {/* Ojos */}
      <g transform={`translate(${dx} ${dy})`}>
        {mood === 'feliz' ? (
          <>
            <path d={`M ${-eyeSpacing - 10} ${eyeY + 2} Q ${-eyeSpacing} ${eyeY - 10} ${-eyeSpacing + 10} ${eyeY + 2}`} fill="none" stroke={CARTOON_INK} strokeWidth="4.6" strokeLinecap="round" />
            <path d={`M ${eyeSpacing - 10} ${eyeY + 2} Q ${eyeSpacing} ${eyeY - 10} ${eyeSpacing + 10} ${eyeY + 2}`} fill="none" stroke={CARTOON_INK} strokeWidth="4.6" strokeLinecap="round" />
          </>
        ) : (
          <>
            <ellipse cx={-eyeSpacing} cy={eyeY} rx={rx} ry={ry} fill={CARTOON_INK} />
            <ellipse cx={eyeSpacing} cy={eyeY} rx={rx} ry={ry} fill={CARTOON_INK} />
          </>
        )}
      </g>

      {/* Lágrimas opcionales para escenas crudas/emotivas */}
      {tears && (
        <>
          <path d={`M ${-eyeSpacing - 2} ${eyeY + 11} Q ${-eyeSpacing - 7} ${eyeY + 24} ${-eyeSpacing - 2} ${eyeY + 27} Q ${-eyeSpacing + 3} ${eyeY + 24} ${-eyeSpacing - 2} ${eyeY + 11} Z`} fill="#7ec8e3" stroke={CARTOON_INK} strokeWidth="2.4" />
          <path d={`M ${eyeSpacing + 2} ${eyeY + 11} Q ${eyeSpacing + 7} ${eyeY + 24} ${eyeSpacing + 2} ${eyeY + 27} Q ${eyeSpacing - 3} ${eyeY + 24} ${eyeSpacing + 2} ${eyeY + 11} Z`} fill="#7ec8e3" stroke={CARTOON_INK} strokeWidth="2.4" />
        </>
      )}

      {/* Cejas expresivas */}
      {mood === 'enojado' && (
        <>
          <path d={`M ${-eyeSpacing - 19} ${eyeY - 22} L ${-eyeSpacing + 16} ${eyeY - 9}`} fill="none" stroke={eyebrowColor} strokeWidth="4.2" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 16} ${eyeY - 9} L ${eyeSpacing + 19} ${eyeY - 22}`} fill="none" stroke={eyebrowColor} strokeWidth="4.2" strokeLinecap="round" />
        </>
      )}
      {mood === 'serio' && (
        <>
          <path d={`M ${-eyeSpacing - 15} ${eyeY - 16} L ${-eyeSpacing + 14} ${eyeY - 14}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 14} L ${eyeSpacing + 15} ${eyeY - 16}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
        </>
      )}
      {mood === 'triste' && (
        <>
          <path d={`M ${-eyeSpacing - 16} ${eyeY - 11} Q ${-eyeSpacing} ${eyeY - 16} ${-eyeSpacing + 14} ${eyeY - 21}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 21} Q ${eyeSpacing} ${eyeY - 16} ${eyeSpacing + 16} ${eyeY - 11}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
        </>
      )}
      {mood === 'feliz' && (
        <>
          <path d={`M ${-eyeSpacing - 14} ${eyeY - 18} Q ${-eyeSpacing} ${eyeY - 25} ${-eyeSpacing + 14} ${eyeY - 18}`} fill="none" stroke={eyebrowColor} strokeWidth="3.8" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 18} Q ${eyeSpacing} ${eyeY - 25} ${eyeSpacing + 14} ${eyeY - 18}`} fill="none" stroke={eyebrowColor} strokeWidth="3.8" strokeLinecap="round" />
        </>
      )}
      {mood === 'sorpresa' && (
        <>
          <path d={`M ${-eyeSpacing - 14} ${eyeY - 22} Q ${-eyeSpacing} ${eyeY - 31} ${-eyeSpacing + 14} ${eyeY - 22}`} fill="none" stroke={eyebrowColor} strokeWidth="3.8" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 22} Q ${eyeSpacing} ${eyeY - 31} ${eyeSpacing + 14} ${eyeY - 22}`} fill="none" stroke={eyebrowColor} strokeWidth="3.8" strokeLinecap="round" />
        </>
      )}
      {mood === 'pensativo' && (
        <>
          <path d={`M ${-eyeSpacing - 15} ${eyeY - 14} L ${-eyeSpacing + 14} ${eyeY - 14}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 21} Q ${eyeSpacing} ${eyeY - 27} ${eyeSpacing + 15} ${eyeY - 19}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
        </>
      )}
      {mood === 'hablando' && (
        <>
          <path d={`M ${-eyeSpacing - 15} ${eyeY - 18} Q ${-eyeSpacing} ${eyeY - 22} ${-eyeSpacing + 14} ${eyeY - 16}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
          <path d={`M ${eyeSpacing - 14} ${eyeY - 16} Q ${eyeSpacing} ${eyeY - 22} ${eyeSpacing + 15} ${eyeY - 18}`} fill="none" stroke={eyebrowColor} strokeWidth="4.0" strokeLinecap="round" />
        </>
      )}

      {/* Boca expresiva */}
      {(mood === 'hablando' || mouthOpen > 0.1) ? (
        <ellipse
          cx="0"
          cy={mouthY}
          rx={12 + mouthOpen * 5}
          ry={4 + mouthOpen * 10}
          fill="#692029"
          stroke={CARTOON_INK}
          strokeWidth="3.4"
        />
      ) : mood === 'sorpresa' ? (
        <ellipse cx="0" cy={mouthY} rx="10" ry="11" fill="#692029" stroke={CARTOON_INK} strokeWidth="3.4" />
      ) : mood === 'feliz' ? (
        <path d={`M -18 ${mouthY - 4} Q 0 ${mouthY + 16} 18 ${mouthY - 4} Z`} fill="#692029" stroke={CARTOON_INK} strokeWidth="3.4" strokeLinejoin="round" />
      ) : mood === 'triste' ? (
        <path d={`M -14 ${mouthY + 5} Q 0 ${mouthY - 6} 14 ${mouthY + 5}`} fill="none" stroke={CARTOON_INK} strokeWidth="3.8" strokeLinecap="round" />
      ) : mood === 'pensativo' ? (
        <path d={`M -10 ${mouthY + 2} Q 2 ${mouthY - 1} 12 ${mouthY + 4}`} fill="none" stroke={CARTOON_INK} strokeWidth="3.8" strokeLinecap="round" />
      ) : !hideMouthWhenClosed ? (
        <path d={`M -12 ${mouthY} Q 0 ${mouthY + 2} 12 ${mouthY}`} fill="none" stroke={CARTOON_INK} strokeWidth="3.8" strokeLinecap="round" />
      ) : null}
    </g>
  );
};
