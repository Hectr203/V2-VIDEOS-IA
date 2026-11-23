import {Easing, interpolate, spring as remotionSpring} from 'remotion';

export type Vec2 = {x: number; y: number};

export const kiwiClamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const kiwiMix = (a: number, b: number, p: number) => a + (b - a) * p;
export const kiwiEase = (n: number) => {
  const t = kiwiClamp(n);
  return t * t * (3 - 2 * t);
};
export const kiwiEaseOutCubic = (n: number) => 1 - Math.pow(1 - kiwiClamp(n), 3);
export const kiwiEaseInOutCubic = (n: number) => {
  const t = kiwiClamp(n);
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
};
export const kiwiWave = (f: number, speed = 0.06, amount = 1, phase = 0) =>
  Math.sin(f * speed + phase) * amount;

export const kiwiSeeded = (n: number) => {
  const a = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return a - Math.floor(a);
};

/** Resorte críticamente amortiguado (estándar WWDC / Emil Kowalski para UI limpia sin rebote nervioso) */
export function uiSpring(frame: number, fps: number, delayFrames = 0) {
  return remotionSpring({
    frame: Math.max(0, frame - delayFrames),
    fps,
    config: {damping: 22, stiffness: 185, mass: 0.9},
  });
}

/** Resorte elástico con inercia física para impactos, sellos y acciones de personajes */
export function bounceSpring(frame: number, fps: number, delayFrames = 0) {
  return remotionSpring({
    frame: Math.max(0, frame - delayFrames),
    fps,
    config: {damping: 11, stiffness: 220, mass: 0.85},
  });
}

/** Progreso determinista disparado en el segundo exacto del guion (timeline.json) */
export function beatProgress(frame: number, fps: number, startSec: number, durationSec = 0.45) {
  const startF = startSec * fps;
  const endF = (startSec + durationSec) * fps;
  return interpolate(frame, [startF, endF], [0, 1], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
}

/** Conservación de volumen para Squash & Stretch (si estira en X, comprime en Y y viceversa) */
export function squashStretch(amount: number): {sx: number; sy: number} {
  const sx = kiwiClamp(1 + amount, 0.65, 1.45);
  return {sx, sy: 1 / sx};
}

/** Trayectoria en arco parabólico (Principio #7 de Disney: Arcs) */
export function arcPoint(from: Vec2, to: Vec2, p: number, arcHeight = 90): Vec2 {
  const t = kiwiClamp(p);
  return {
    x: kiwiMix(from.x, to.x, t),
    y: kiwiMix(from.y, to.y, t) - Math.sin(t * Math.PI) * arcHeight,
  };
}

/** Cinemática Inversa 2D (IK) para brazos/piernas articulados sin romper codos ni rodillas */
export function solveIK(root: Vec2, target: Vec2, l1: number, l2: number, bend: 1 | -1 = 1): Vec2 {
  const dx = target.x - root.x;
  const dy = target.y - root.y;
  const d = kiwiClamp(Math.hypot(dx, dy), 1, l1 + l2 - 0.5);
  const cosAngle = kiwiClamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1);
  const angle = Math.atan2(dy, dx) + bend * Math.acos(cosAngle);
  return {
    x: root.x + Math.cos(angle) * l1,
    y: root.y + Math.sin(angle) * l1,
  };
}

/** Parpadeo natural estocástico determinista */
export function eyeBlinkScale(f: number, seed = 0): number {
  const period = 105 + Math.round(kiwiSeeded(seed + 7) * 35);
  const local = (f + Math.round(kiwiSeeded(seed + 3) * 40)) % period;
  if (local < period - 7) return 1;
  const t = Math.abs(local - (period - 3.5)) / 3.5;
  return kiwiClamp(t, 0.08, 1);
}

/** Nivel de apertura bucal (lip-sync) calculado directamente desde los timestamps de palabras */
export function mouthOpenness(
  f: number,
  fps: number,
  words: {word: string; start: number; end: number}[],
): number {
  const sec = f / fps;
  const active = words.find((w) => sec >= w.start && sec <= w.end);
  if (!active) return 0;
  const dur = Math.max(0.08, active.end - active.start);
  const local = (sec - active.start) / dur;
  const syllables = Math.max(1, Math.min(4, Math.ceil(active.word.length / 3)));
  return Math.abs(Math.sin(local * Math.PI * syllables)) * 0.85 + 0.15;
}
