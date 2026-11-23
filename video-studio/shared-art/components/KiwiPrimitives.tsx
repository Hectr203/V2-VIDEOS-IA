import React from 'react';
import {
  Vec2,
  bounceSpring,
  eyeBlinkScale,
  kiwiClamp,
  kiwiEase,
  kiwiMix,
  kiwiSeeded,
  kiwiWave,
  solveIK,
  squashStretch,
  uiSpring,
} from '../math/kiwiMotion';

export interface KiwiTheme {
  bgTop: string;
  bgMid: string;
  bgBot: string;
  centerGlow: string;
  rayA: string;
  rayB: string;
  accent: string;
}

/** Paletas armónicas sin sesgos adaptables a cualquier temática manteniendo la firma visual Kiwi/Kurzgesagt 3D */
export const KIWI_THEMES: Record<string, KiwiTheme> = {
  cosmos: {bgTop: '#0f0428', bgMid: '#1e0a47', bgBot: '#100529', centerGlow: '#6d28d9', rayA: '#c084fc', rayB: '#818cf8', accent: '#facc15'},
  ocean: {bgTop: '#061426', bgMid: '#0d2b4d', bgBot: '#061221', centerGlow: '#0284c7', rayA: '#38bdf8', rayB: '#2dd4bf', accent: '#fde047'},
  emerald: {bgTop: '#051a14', bgMid: '#0c382a', bgBot: '#04140f', centerGlow: '#10b981', rayA: '#34d399', rayB: '#22d3ee', accent: '#facc15'},
  warm: {bgTop: '#1c0c08', bgMid: '#3d1911', bgBot: '#170a07', centerGlow: '#ea580c', rayA: '#fb923c', rayB: '#fbbf24', accent: '#fde047'},
  crimson: {bgTop: '#1d0710', bgMid: '#451024', bgBot: '#15050b', centerGlow: '#e11d48', rayA: '#fb7185', rayB: '#c084fc', accent: '#facc15'},
};

export function KiwiProDefs({themeKey = 'cosmos'}: {themeKey?: keyof typeof KIWI_THEMES | string}) {
  const th = KIWI_THEMES[themeKey] || KIWI_THEMES.cosmos;
  return (
    <defs>
      <linearGradient id="kiwiCosmosBg" x1="0%" y1="0%" x2="25%" y2="100%">
        <stop offset="0%" stopColor={th.bgTop} />
        <stop offset="48%" stopColor={th.bgMid} />
        <stop offset="100%" stopColor={th.bgBot} />
      </linearGradient>
      <radialGradient id="kiwiCenterGlow" cx="50%" cy="46%" r="55%">
        <stop offset="0%" stopColor={th.centerGlow} stopOpacity="0.34" />
        <stop offset="60%" stopColor={th.centerGlow} stopOpacity="0.1" />
        <stop offset="100%" stopColor={th.bgTop} stopOpacity="0" />
      </radialGradient>
      <radialGradient id="kiwiSkinPro" cx="38%" cy="30%" r="68%">
        <stop offset="0%" stopColor="#ffd7b8" />
        <stop offset="55%" stopColor="#fbb78e" />
        <stop offset="100%" stopColor="#d98762" />
      </radialGradient>
      <radialGradient id="kiwiSkinWarm" cx="38%" cy="30%" r="68%">
        <stop offset="0%" stopColor="#e8ab82" />
        <stop offset="55%" stopColor="#c47c50" />
        <stop offset="100%" stopColor="#8c4d2b" />
      </radialGradient>
      <linearGradient id="kiwiShirtBlue" x1="15%" y1="0%" x2="85%" y2="100%">
        <stop offset="0%" stopColor="#7dd3fc" />
        <stop offset="45%" stopColor="#3b82f6" />
        <stop offset="100%" stopColor="#1d4ed8" />
      </linearGradient>
      <linearGradient id="kiwiShirtGreen" x1="15%" y1="0%" x2="85%" y2="100%">
        <stop offset="0%" stopColor="#86efac" />
        <stop offset="50%" stopColor="#22c55e" />
        <stop offset="100%" stopColor="#15803d" />
      </linearGradient>
      <linearGradient id="kiwiShirtCoral" x1="15%" y1="0%" x2="85%" y2="100%">
        <stop offset="0%" stopColor="#fda4af" />
        <stop offset="50%" stopColor="#f43f5e" />
        <stop offset="100%" stopColor="#9f1239" />
      </linearGradient>
      <linearGradient id="kiwiShirtAmber" x1="15%" y1="0%" x2="85%" y2="100%">
        <stop offset="0%" stopColor="#fde68a" />
        <stop offset="50%" stopColor="#f59e0b" />
        <stop offset="100%" stopColor="#b45309" />
      </linearGradient>
      <filter id="kiwiNeonGlow" x="-45%" y="-45%" width="190%" height="190%">
        <feGaussianBlur stdDeviation="11" result="b" />
        <feMerge>
          <feMergeNode in="b" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
      <filter id="kiwiDrop3d" x="-30%" y="-30%" width="160%" height="160%">
        <feDropShadow dx="0" dy="14" stdDeviation="11" floodColor="#060112" floodOpacity="0.56" />
      </filter>
    </defs>
  );
}

/** Fondo atmosférico continuo compartido (soporta 9:16 y 16:9 sin cortes a negro entre escenas) */
export function SharedCosmicBackdrop({
  globalFrame,
  width = 720,
  height = 1280,
  themeKey = 'cosmos',
}: {
  globalFrame: number;
  width?: number;
  height?: number;
  themeKey?: string;
}) {
  const th = KIWI_THEMES[themeKey] || KIWI_THEMES.cosmos;
  const rayDrift = kiwiWave(globalFrame, 0.014, 24);
  return (
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none'}}>
      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{position: 'absolute', inset: 0}}>
        <KiwiProDefs themeKey={themeKey} />
        <rect width={width} height={height} fill="url(#kiwiCosmosBg)" />
        <rect width={width} height={height} fill="url(#kiwiCenterGlow)" />
        <g opacity="0.055">
          <polygon points={`${width * 0.08 + rayDrift},0 ${width * 0.3 + rayDrift},0 ${width * 0.65},${height} ${width * 0.4},${height}`} fill={th.rayA} />
          <polygon points={`${width * 0.52 - rayDrift},0 ${width * 0.72 - rayDrift},0 ${width * 1.02},${height} ${width * 0.8},${height}`} fill={th.rayB} />
        </g>
        {Array.from({length: 22}).map((_, i) => {
          const sx = kiwiSeeded(i * 11 + 1) * (width - 40) + 20;
          const sy = ((kiwiSeeded(i * 17 + 3) * height - globalFrame * (0.32 + (i % 4) * 0.14)) % height + height) % height;
          const r = 3 + (i % 5) * 4;
          const op = 0.04 + (i % 4) * 0.024 + kiwiWave(globalFrame, 0.04, 0.02, i);
          return <circle key={i} cx={sx} cy={sy} r={r} fill={i % 3 === 0 ? th.rayA : th.rayB} opacity={kiwiClamp(op, 0.02, 0.18)} />;
        })}
      </svg>
    </div>
  );
}

/** Partículas frontales 3D en Z=+155px pasando frente a la lente */
export function ForegroundParticles3D({
  globalFrame,
  width = 720,
  height = 1280,
  accent = '#facc15',
}: {
  globalFrame: number;
  width?: number;
  height?: number;
  accent?: string;
}) {
  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        transform: 'translateZ(155px) scale(0.87)',
      }}
    >
      {Array.from({length: 9}).map((_, i) => {
        const x = kiwiSeeded(i * 23 + 9) * (width - 60) + 30 + kiwiWave(globalFrame, 0.025, 22, i);
        const y = ((kiwiSeeded(i * 31 + 5) * height - globalFrame * (0.9 + (i % 3) * 0.35)) % height + height) % height;
        return <circle key={i} cx={x} cy={y} r={2.4 + (i % 3) * 1.4} fill={accent} opacity={0.36} />;
      })}
    </svg>
  );
}

/** Única barra de progreso limpia en la parte inferior (CERO pestañas o encabezados superiores tipo diapositiva) */
export function KiwiProgressBar({
  globalFrame,
  durationInFrames,
  width = 720,
  height = 1280,
  color = '#facc15',
}: {
  globalFrame: number;
  durationInFrames: number;
  width?: number;
  height?: number;
  color?: string;
}) {
  const pct = kiwiClamp(globalFrame / Math.max(1, durationInFrames));
  const pad = 48;
  const barW = width - pad * 2;
  const barY = height - 46;
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <rect x={pad} y={barY} width={barW} height="4" rx="2" fill="#ffffff" opacity="0.16" />
      <rect x={pad} y={barY} width={barW * pct} height="4" rx="2" fill={color} opacity="0.88" />
    </svg>
  );
}

/** Contador mecánico Flip-Clock 3D real con volteo rotateX sincronizado al frame exacto de la palabra */
export function FlipCounter3D({
  top,
  left,
  fromDigits,
  toDigits,
  flipFrame,
  f,
  fps,
}: {
  top: number;
  left?: number;
  fromDigits: string[];
  toDigits: string[];
  flipFrame: number;
  f: number;
  fps: number;
}) {
  const enter = uiSpring(f, fps, Math.max(0, flipFrame - 14));
  const tiltY = kiwiWave(f, 0.032, 6);
  const floatY = kiwiWave(f, 0.05, 4);

  return (
    <div
      style={{
        position: 'absolute',
        left: left ?? 0,
        right: left === undefined ? 0 : undefined,
        top,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
        transformStyle: 'preserve-3d',
        transform: `${left !== undefined ? 'translateX(-50%) ' : ''}translate3d(0, ${kiwiMix(-24, 0, enter) + floatY}px, 95px) rotateY(${tiltY}deg) scale(${kiwiMix(0.82, 1, enter)})`,
        opacity: kiwiClamp(enter),
      }}
    >
      <div
        style={{
          display: 'flex',
          gap: 6,
          padding: '8px 10px',
          borderRadius: 14,
          background: 'linear-gradient(180deg, #1b1333 0%, #0e091e 100%)',
          border: '2px solid #4c3b7a',
          boxShadow: '0 18px 34px rgba(0,0,0,0.55), inset 0 1px 0 rgba(255,255,255,0.2)',
        }}
      >
        {toDigits.map((targetChar, i) => {
          const fromChar = fromDigits[i] ?? '0';
          const localFlip = kiwiClamp((f - (flipFrame + i * 3)) / 10);
          const flipped = localFlip >= 0.5;
          const displayChar = flipped ? targetChar : fromChar;
          const flipDeg = flipped ? kiwiMix(90, 0, (localFlip - 0.5) * 2) : kiwiMix(0, -90, localFlip * 2);

          return (
            <div
              key={i}
              style={{
                width: 44,
                height: 52,
                borderRadius: 8,
                background: 'linear-gradient(180deg, #fbf7ec 0%, #ebe2ce 50%, #f5efe0 51%, #ded3bc 100%)',
                boxShadow: '0 4px 10px rgba(0,0,0,0.35)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                position: 'relative',
                transform: `perspective(260px) rotateX(${flipDeg}deg)`,
              }}
            >
              <div style={{position: 'absolute', left: 0, right: 0, top: '50%', height: 1.5, background: 'rgba(24,18,43,0.24)'}} />
              <span style={{fontSize: 30, fontWeight: 900, color: '#18122b', lineHeight: 1}}>{displayChar}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Recuadro oscuro 3D con borde amarillo vibrante estilo El Kiwi */
export function YellowCallout3D({
  top,
  left,
  title,
  sub,
  delayFrames,
  f,
  fps,
}: {
  top: number;
  left?: number;
  title: string;
  sub: string;
  delayFrames: number;
  f: number;
  fps: number;
}) {
  const enter = uiSpring(f, fps, delayFrames);
  const tiltY = kiwiWave(f, 0.028, 5, 1.4);
  return (
    <div
      style={{
        position: 'absolute',
        left: left ?? 0,
        right: left === undefined ? 0 : undefined,
        top,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
        transform: `${left !== undefined ? 'translateX(-50%) ' : ''}translate3d(0, ${kiwiMix(20, 0, enter)}px, 85px) rotateY(${tiltY}deg) scale(${kiwiMix(0.88, 1, enter)})`,
        opacity: kiwiClamp(enter),
      }}
    >
      <div
        style={{
          minWidth: 310,
          padding: '12px 26px',
          borderRadius: 16,
          background: 'linear-gradient(160deg, rgba(24,12,48,0.94) 0%, rgba(12,6,26,0.96) 100%)',
          border: '2.5px solid #facc15',
          boxShadow: '0 16px 32px rgba(0,0,0,0.52), 0 0 22px rgba(250,204,21,0.18)',
          textAlign: 'center',
        }}
      >
        <div style={{fontSize: 22, fontWeight: 900, color: '#facc15', letterSpacing: 0.4}}>{title}</div>
        <div style={{fontSize: 16, fontWeight: 700, color: '#f8fafc', opacity: 0.92, marginTop: 2}}>{sub}</div>
      </div>
    </div>
  );
}

/** Píldora de datos flotante 3D (cian / lima / amarillo / coral) */
export function DataPill3D({
  left,
  top,
  text,
  bg = '#22d3ee',
  fg = '#0f172a',
  delayFrames,
  f,
  fps,
  bouncy = false,
}: {
  left: number;
  top: number;
  text: string;
  bg?: string;
  fg?: string;
  delayFrames: number;
  f: number;
  fps: number;
  bouncy?: boolean;
}) {
  const enter = bouncy ? bounceSpring(f, fps, delayFrames) : uiSpring(f, fps, delayFrames);
  const floatY = kiwiWave(f, 0.06, 4, left * 0.02);
  return (
    <div
      style={{
        position: 'absolute',
        left,
        top,
        transform: `translate(-50%, -50%) translate3d(0, ${kiwiMix(18, 0, enter) + floatY}px, 105px) scale(${kiwiClamp(enter, 0, 1.18)})`,
        opacity: kiwiClamp(enter),
        padding: '8px 20px',
        borderRadius: 999,
        background: bg,
        color: fg,
        fontSize: 16,
        fontWeight: 900,
        letterSpacing: 0.6,
        whiteSpace: 'nowrap',
        boxShadow: `0 12px 24px rgba(0,0,0,0.42), 0 0 18px ${bg}55`,
      }}
    >
      {text}
    </div>
  );
}

/** Subtítulos cinéticos limpios estilo El Kiwi (sin caja oscura, espaciado estable, soporte 9:16 y 16:9) */
export function KiwiCaptionsPro({
  words,
  f,
  fps,
  isHorizontal = false,
  isOutro = false,
}: {
  words: {word: string; start: number; end: number}[];
  f: number;
  fps: number;
  isHorizontal?: boolean;
  isOutro?: boolean;
}) {
  const time = f / fps;
  if (!words.length) return null;

  let current = words.findIndex((w) => time >= w.start && time < w.end);
  if (current < 0) current = Math.max(0, words.findIndex((w) => w.start > time) - 1);
  if (time >= words[words.length - 1].end) current = words.length - 1;

  const groups: {word: string; start: number; end: number}[][] = [];
  const maxW = isHorizontal ? 7 : 4;
  const maxC = isHorizontal ? 44 : 26;
  for (const word of words) {
    const last = groups[groups.length - 1];
    if (!last || last.length >= maxW || last.map((w) => w.word).join(' ').length + word.word.length > maxC) {
      groups.push([word]);
    } else {
      last.push(word);
    }
  }
  const active = words[current];
  const group = groups.find((g) => g.includes(active)) || groups[0];
  const pop = uiSpring(f, fps, group[0].start * fps);

  const posStyle: React.CSSProperties = isHorizontal
    ? isOutro
      ? {left: 700, top: 290, width: 500, textAlign: 'left', fontSize: 34}
      : {left: 660, top: 270, width: 560, textAlign: 'left', fontSize: 38}
    : isOutro
    ? {left: 42, top: 1020, width: 636, textAlign: 'center', fontSize: 32}
    : {left: 42, top: 932, width: 636, textAlign: 'center', fontSize: 40};

  return (
    <div
      style={{
        position: 'absolute',
        lineHeight: 1.28,
        fontWeight: 900,
        letterSpacing: -0.4,
        transform: `translateY(${kiwiMix(10, 0, pop)}px)`,
        color: '#ffffff',
        textShadow: '0 4px 16px rgba(6,2,18,0.85)',
        pointerEvents: 'none',
        ...posStyle,
      }}
    >
      {group.map((w, i) => {
        const isActive = w === active;
        const wordPop = isActive ? kiwiEase((time - w.start) * 16) : 0;
        return (
          <span
            key={w.start + '-' + i}
            style={{
              display: 'inline-block',
              margin: '0 7px',
              color: isActive ? '#facc15' : '#ffffff',
              opacity: time >= w.start ? 1 : 0.72,
              transform: `scale(${1 + wordPop * 0.07})`,
            }}
          >
            {w.word}
          </span>
        );
      })}
    </div>
  );
}

/** Avatar circular Kiwi Pro con aro brillante, parpadeo y expresiones vivas */
export function KiwiAvatarPro({
  x,
  y,
  ring = '#60a5fa',
  hair = '#6d28d9',
  skinGrad = 'url(#kiwiSkinPro)',
  mood = 'awake',
  f = 0,
  seed = 1,
  scale = 1,
}: {
  x: number;
  y: number;
  ring?: string;
  hair?: string;
  skinGrad?: string;
  mood?: 'awake' | 'sleepy' | 'shock' | 'cool' | 'happy';
  f?: number;
  seed?: number;
  scale?: number;
}) {
  const blink = mood === 'sleepy' ? 0.14 : eyeBlinkScale(f, seed);
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`} filter="url(#kiwiDrop3d)">
      <circle r="42" fill="#180d36" stroke={ring} strokeWidth="5.5" />
      <circle r="38" fill="none" stroke="#ffffff" strokeOpacity="0.16" strokeWidth="1.5" />
      <circle cy="4" r="28" fill={skinGrad} />
      <path d="M -28 0 C -29 -29 29 -29 28 0 C 16 -12 -16 -12 -28 0 Z" fill={hair} />
      {mood === 'cool' ? (
        <g>
          <rect x="-21" y="-5" width="18" height="11" rx="4" fill="#0f172a" stroke="#facc15" strokeWidth="1.5" />
          <rect x="3" y="-5" width="18" height="11" rx="4" fill="#0f172a" stroke="#facc15" strokeWidth="1.5" />
          <line x1="-3" y1="0" x2="3" y2="0" stroke="#facc15" strokeWidth="2" />
        </g>
      ) : (
        <g>
          <ellipse cx="-10" cy="0" rx="4.6" ry={4.8 * blink} fill="#140a29" />
          <ellipse cx="10" cy="0" rx="4.6" ry={4.8 * blink} fill="#140a29" />
          {blink > 0.5 && (
            <>
              <circle cx="-11.5" cy="-1.5" r="1.4" fill="#ffffff" opacity="0.85" />
              <circle cx="8.5" cy="-1.5" r="1.4" fill="#ffffff" opacity="0.85" />
            </>
          )}
        </g>
      )}
      <circle cx="0" cy="8.5" r="4.2" fill="#f43f5e" opacity="0.88" />
      {mood === 'sleepy' && <ellipse cx="0" cy="17" rx="4" ry="2.5" fill="#991b1b" />}
      {mood === 'shock' && <circle cx="0" cy="17" r="5" fill="#991b1b" />}
      {mood === 'happy' && <path d="M -8 15 Q 0 22 8 15" fill="none" stroke="#991b1b" strokeWidth="3" strokeLinecap="round" />}
    </g>
  );
}

/**
 * Personaje Kiwi Pro Articulado universal (Cinemática Inversa 2D + 8 estados emocionales +
 * respiración, parpadeo, seguimiento de cabello, volumen rim-light y lip-sync).
 */
export function KiwiCharacterIK({
  x,
  y,
  f,
  shirtGrad = 'url(#kiwiShirtBlue)',
  skinGrad = 'url(#kiwiSkinPro)',
  hair = '#5b21b6',
  mood = 'awake',
  leftHandTarget,
  rightHandTarget,
  rightProp,
  squash = 0,
  mouthOpen = 0,
  scale = 1,
  coolShades = false,
  seated = false,
}: {
  x: number;
  y: number;
  f: number;
  shirtGrad?: string;
  skinGrad?: string;
  hair?: string;
  mood?: 'awake' | 'happy' | 'sip' | 'shock' | 'sleepy' | 'urgent' | 'proud' | 'thinking';
  leftHandTarget?: Vec2;
  rightHandTarget?: Vec2;
  rightProp?: React.ReactNode;
  squash?: number;
  mouthOpen?: number;
  scale?: number;
  coolShades?: boolean;
  seated?: boolean;
}) {
  const breath = kiwiWave(f, 0.085, 0.022);
  const {sx, sy} = squashStretch(squash);
  const headLagY = kiwiWave(f - 5, 0.085, 2.2);
  const headTilt =
    mood === 'sip'
      ? -11
      : mood === 'thinking'
      ? 9
      : mood === 'shock'
      ? kiwiWave(f, 0.35, 3.2)
      : kiwiWave(f - 6, 0.055, 2.5);
  const hairTrail = kiwiWave(f - 9, 0.09, 3.5);
  const blink = mood === 'sleepy' ? 0.16 : mood === 'sip' ? 0.25 : eyeBlinkScale(f, 19);

  const shL: Vec2 = {x: -44, y: 4};
  const shR: Vec2 = {x: 44, y: 4};
  const tgtL: Vec2 = leftHandTarget ?? {x: -64, y: 58 + kiwiWave(f, 0.08, 4)};
  const tgtR: Vec2 = rightHandTarget ?? {x: 64, y: 58 + kiwiWave(f, 0.08, 4, 2)};
  const elbL = solveIK(shL, tgtL, 38, 36, -1);
  const elbR = solveIK(shR, tgtR, 38, 36, 1);

  return (
    <g transform={`translate(${x} ${y}) scale(${scale * sx} ${scale * sy})`} filter="url(#kiwiDrop3d)">
      {!seated ? (
        <g>
          <path d={`M -22 72 Q -24 98 ${-22 + (mood === 'urgent' ? kiwiWave(f, 0.35, 10) : 0)} 116`} fill="none" stroke="#312e81" strokeWidth="18" strokeLinecap="round" />
          <path d={`M 22 72 Q 24 98 ${22 - (mood === 'urgent' ? kiwiWave(f, 0.35, 10) : 0)} 116`} fill="none" stroke="#312e81" strokeWidth="18" strokeLinecap="round" />
          <ellipse cx={-24 + (mood === 'urgent' ? kiwiWave(f, 0.35, 10) : 0)} cy="122" rx="17" ry="9" fill="#1e1b4b" />
          <ellipse cx={24 - (mood === 'urgent' ? kiwiWave(f, 0.35, 10) : 0)} cy="122" rx="17" ry="9" fill="#1e1b4b" />
        </g>
      ) : (
        <g>
          <rect x="-32" y="66" width="20" height="36" rx="10" fill="#312e81" />
          <rect x="12" y="66" width="20" height="36" rx="10" fill="#312e81" />
          <ellipse cx="-24" cy="106" rx="18" ry="9" fill="#1e1b4b" />
          <ellipse cx="24" cy="106" rx="18" ry="9" fill="#1e1b4b" />
        </g>
      )}

      {/* Brazo izquierdo IK */}
      <g>
        <path d={`M ${shL.x} ${shL.y} L ${elbL.x} ${elbL.y} L ${tgtL.x} ${tgtL.y}`} fill="none" stroke={skinGrad} strokeWidth="20" strokeLinecap="round" strokeLinejoin="round" />
        <path d={`M ${shL.x} ${shL.y} L ${kiwiMix(shL.x, elbL.x, 0.55)} ${kiwiMix(shL.y, elbL.y, 0.55)}`} fill="none" stroke={shirtGrad} strokeWidth="24" strokeLinecap="round" />
        <circle cx={tgtL.x} cy={tgtL.y} r="12" fill={skinGrad} />
      </g>

      {/* Torso cápsula volumétrico */}
      <g transform={`scale(${1 - breath * 0.45} ${1 + breath})`}>
        <rect x="-46" y="-14" width="92" height="96" rx="42" fill={shirtGrad} />
        <path d="M -34 10 C -34 -6 -16 -10 -4 -10" fill="none" stroke="#ffffff" strokeWidth="4" strokeLinecap="round" opacity="0.28" />
        <ellipse cx="0" cy="-10" rx="28" ry="10" fill="#0f0428" opacity="0.26" />
      </g>

      {/* Cabeza con retardo físico y expresiones */}
      <g transform={`translate(0 ${-64 + headLagY}) rotate(${headTilt})`}>
        <circle cx="-48" cy="4" r="12" fill={skinGrad} />
        <circle cx="-48" cy="4" r="5" fill="#9c5a44" opacity="0.45" />
        <circle cx="48" cy="4" r="12" fill={skinGrad} />
        <circle cx="48" cy="4" r="5" fill="#9c5a44" opacity="0.45" />
        <circle cx="0" cy="0" r="48" fill={skinGrad} />

        <g transform={`translate(0 ${hairTrail * 0.35})`}>
          <path d="M -48 -4 C -52 -58 52 -58 48 -4 C 32 -26 -28 -26 -48 -4 Z" fill={hair} />
          <path d={`M -6 -48 Q ${4 + hairTrail} -66 ${18 + hairTrail * 1.2} -52 Q ${6 + hairTrail * 0.5} -46 -6 -48 Z`} fill={hair} />
          <path d="M -32 -34 Q 0 -46 28 -32" fill="none" stroke="#ffffff" strokeWidth="3.5" strokeLinecap="round" opacity="0.22" />
        </g>

        <ellipse cx="-26" cy="14" rx="9" ry="5" fill="#fb7185" opacity="0.32" />
        <ellipse cx="26" cy="14" rx="9" ry="5" fill="#fb7185" opacity="0.32" />

        <path
          d={mood === 'shock' ? 'M -28 -26 Q -18 -36 -8 -26' : mood === 'thinking' ? 'M -28 -20 Q -18 -23 -8 -20' : 'M -28 -21 Q -18 -27 -8 -21'}
          fill="none"
          stroke={hair}
          strokeWidth="5.5"
          strokeLinecap="round"
        />
        <path
          d={mood === 'shock' ? 'M 8 -26 Q 18 -36 28 -26' : mood === 'thinking' ? 'M 8 -26 Q 18 -32 28 -24' : 'M 8 -21 Q 18 -27 28 -21'}
          fill="none"
          stroke={hair}
          strokeWidth="5.5"
          strokeLinecap="round"
        />

        {coolShades ? (
          <g filter="url(#kiwiDrop3d)">
            <rect x="-34" y="-12" width="30" height="19" rx="7" fill="#0f172a" stroke="#facc15" strokeWidth="2.5" />
            <rect x="4" y="-12" width="30" height="19" rx="7" fill="#0f172a" stroke="#facc15" strokeWidth="2.5" />
            <line x1="-4" y1="-3" x2="4" y2="-3" stroke="#facc15" strokeWidth="3" />
          </g>
        ) : (
          <g>
            <ellipse cx="-17" cy="-2" rx="8" ry={(mood === 'shock' ? 11 : 9) * blink} fill="#140a29" />
            <ellipse cx="17" cy="-2" rx="8" ry={(mood === 'shock' ? 11 : 9) * blink} fill="#140a29" />
            {blink > 0.45 && (
              <>
                <circle cx="-19.5" cy="-5" r="2.4" fill="#ffffff" opacity="0.9" />
                <circle cx="14.5" cy="-5" r="2.4" fill="#ffffff" opacity="0.9" />
              </>
            )}
          </g>
        )}

        <circle cx="0" cy="11" r="6.8" fill="#f43f5e" opacity="0.9" />
        <circle cx="-2" cy="9" r="2" fill="#fda4af" opacity="0.6" />

        {mood === 'shock' ? (
          <ellipse cx="0" cy="28" rx="9" ry={8 + mouthOpen * 4} fill="#881337" />
        ) : mood === 'sip' ? (
          <circle cx="0" cy="27" r="5.5" fill="#881337" />
        ) : mood === 'happy' || mood === 'proud' ? (
          <path d="M -15 23 Q 0 39 15 23 Z" fill="#881337" />
        ) : mouthOpen > 0.2 ? (
          <g>
            <path d={`M -13 24 Q 0 ${24 + mouthOpen * 16} 13 24 Z`} fill="#881337" />
            <path d="M -8 24 L 8 24" stroke="#ffffff" strokeWidth="2.5" strokeLinecap="round" />
          </g>
        ) : (
          <path d="M -13 25 Q 0 36 13 25" fill="none" stroke="#881337" strokeWidth="4.2" strokeLinecap="round" />
        )}
      </g>

      {/* Brazo derecho IK + accesorio opcional */}
      <g>
        <path d={`M ${shR.x} ${shR.y} L ${elbR.x} ${elbR.y} L ${tgtR.x} ${tgtR.y}`} fill="none" stroke={skinGrad} strokeWidth="20" strokeLinecap="round" strokeLinejoin="round" />
        <path d={`M ${shR.x} ${shR.y} L ${kiwiMix(shR.x, elbR.x, 0.55)} ${kiwiMix(shR.y, elbR.y, 0.55)}`} fill="none" stroke={shirtGrad} strokeWidth="24" strokeLinecap="round" />
        {rightProp && <g transform={`translate(${tgtR.x} ${tgtR.y})`}>{rightProp}</g>}
        <circle cx={tgtR.x} cy={tgtR.y} r="12" fill={skinGrad} />
      </g>
    </g>
  );
}
