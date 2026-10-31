export type AnimationType = "draw" | "write" | "move" | "rotate" | "scale" | "fade" | "highlight";
export interface Animation { type: AnimationType; start: number; duration: number; delay?: number; from?: number; to?: number; x?: number; y?: number; color?: string; }
export type ShapeType = "card" | "pill" | "circle" | "line" | "bar";
export interface SceneObject { id: string; kind: "svg" | "text" | "shape"; asset?: string; text?: string; shape?: ShapeType; fill?: string; stroke?: string; strokeWidth?: number; radius?: number; label?: string; labelColor?: string; syncWithNarration?: number; x: number; y: number; width?: number; height?: number; animations: Animation[]; }
export interface Scene { id: string; duration: number; objects: SceneObject[]; camera?: { x?: number; y?: number; zoom?: number }; transition?: { type: "fade"; duration: number }; }
export interface NarrationClip { text: string; start: number; voice?: string; rate?: string; }
export interface AudioTrack { narration: NarrationClip[]; }
export interface HandDrawProject { version: 1; project: { title: string; width: number; height: number; fps: number; background?: string; style?: "business" | "narrative-sketch" }; scenes: Scene[]; audio?: AudioTrack; }
export interface ValidationIssue { path: string; message: string; }

export function projectDuration(project: HandDrawProject): number { return project.scenes.reduce((total, scene) => total + scene.duration, 0); }
export function validateProject(input: unknown): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const p = input as Partial<HandDrawProject>;
  if (!p || typeof p !== "object") return [{ path: "$", message: "Project must be an object" }];
  if (p.version !== 1) issues.push({ path: "version", message: "Only DSL version 1 is supported" });
  if (!p.project || !Number.isFinite(p.project.width) || !Number.isFinite(p.project.height) || !Number.isFinite(p.project.fps)) issues.push({ path: "project", message: "project.width, project.height, and project.fps are required numbers" });
  if (!Array.isArray(p.scenes) || p.scenes.length === 0) return [...issues, { path: "scenes", message: "At least one scene is required" }];
  p.audio?.narration?.forEach((clip, index) => {
    if (!clip.text || !Number.isFinite(clip.start) || clip.start < 0) issues.push({ path: `audio.narration[${index}]`, message: "Narration requires non-empty text and a non-negative start time" });
  });
  const sceneIds = new Set<string>();
  p.scenes.forEach((scene, si) => {
    const base = `scenes[${si}]`;
    if (!scene.id || sceneIds.has(scene.id)) issues.push({ path: `${base}.id`, message: "Scene id must be unique" });
    sceneIds.add(scene.id);
    if (!Number.isFinite(scene.duration) || scene.duration <= 0) issues.push({ path: `${base}.duration`, message: "Scene duration must be positive" });
    if (scene.transition && (scene.transition.type !== "fade" || !Number.isFinite(scene.transition.duration) || scene.transition.duration <= 0 || scene.transition.duration >= scene.duration)) issues.push({ path: `${base}.transition`, message: "Transition must be a fade shorter than its scene" });
    if (!Array.isArray(scene.objects) || scene.objects.length > 8) issues.push({ path: `${base}.objects`, message: "A scene must contain 0–8 objects" });
    const ids = new Set<string>();
    scene.objects?.forEach((object, oi) => {
      const op = `${base}.objects[${oi}]`;
      if (!object.id || ids.has(object.id)) issues.push({ path: `${op}.id`, message: "Object id must be unique within its scene" });
      ids.add(object.id);
      if (object.kind === "svg" && !object.asset) issues.push({ path: `${op}.asset`, message: "SVG objects require an asset" });
      if (object.kind === "text" && !object.text) issues.push({ path: `${op}.text`, message: "Text objects require text" });
      if (object.kind === "shape" && !object.shape) issues.push({ path: `${op}.shape`, message: "Shape objects require a shape type" });
      object.animations?.forEach((animation, ai) => {
        const ap = `${op}.animations[${ai}]`;
        if (!Number.isFinite(animation.start) || animation.start < 0 || !Number.isFinite(animation.duration) || animation.duration <= 0) issues.push({ path: ap, message: "Animation start must be ≥ 0 and duration must be positive" });
        if (animation.start + animation.duration + (animation.delay ?? 0) > scene.duration) issues.push({ path: ap, message: "Animation cannot exceed its scene duration" });
      });
    });
  });
  return issues;
}
export function progressAt(time: number, animation: Animation): number { const start = animation.start + (animation.delay ?? 0); return Math.max(0, Math.min(1, (time - start) / animation.duration)); }

/** Align linked `write` animations to the real TTS clip durations after synthesis. */
export function synchronizeNarration(project: HandDrawProject, narrationDurations: number[]): HandDrawProject {
  const synced = structuredClone(project); let sceneStart = 0;
  for (const scene of synced.scenes) {
    for (const object of scene.objects) {
      if (object.syncWithNarration === undefined) continue;
      const narration = synced.audio?.narration[object.syncWithNarration]; const duration = narrationDurations[object.syncWithNarration];
      const write = object.animations.find((animation) => animation.type === "write");
      if (!narration || !duration || !write) continue;
      write.start = Math.max(0, narration.start - sceneStart);
      write.duration = Math.max(0.35, Math.min(duration * 0.9, scene.duration - write.start));
    }
    sceneStart += scene.duration;
  }
  return synced;
}
