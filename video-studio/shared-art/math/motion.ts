/**
 * Primitivas matemáticas deterministas para animación y dinamismo procedimental.
 */

export const clamp = (n: number, lo = 0, hi = 1): number => Math.min(hi, Math.max(lo, n));

export const ease = (n: number): number => {
  const t = clamp(n);
  return t * t * (3 - 2 * t);
};

export const easeInOutCubic = (n: number): number => {
  const t = clamp(n);
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
};

export const mix = (a: number, b: number, p: number): number => a + (b - a) * p;

export const wave = (f: number, speed = 0.06, amount = 1, phase = 0): number =>
  Math.sin(f * speed + phase) * amount;

export const cosWave = (f: number, speed = 0.06, amount = 1, phase = 0): number =>
  Math.cos(f * speed + phase) * amount;

export const seeded = (n: number): number => {
  const a = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return a - Math.floor(a);
};

export type Point = { x: number; y: number };

/**
 * Cinemática inversa para extremidades de dos segmentos (muslo/pierna, brazo/antebrazo).
 * a: origen (hombro/cadera)
 * b: destino (mano/pie)
 * l1: longitud segmento 1
 * l2: longitud segmento 2
 * bend: dirección de flexión (-1 o 1)
 */
export function joint(a: Point, b: Point, l1: number, l2: number, bend = 1): Point {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const d = clamp(Math.hypot(dx, dy), 1, l1 + l2 - 0.01);
  const angle = Math.atan2(dy, dx) + bend * Math.acos(clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1));
  return { x: a.x + Math.cos(angle) * l1, y: a.y + Math.sin(angle) * l1 };
}
