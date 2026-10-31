import React from "react";
import { AbsoluteFill, Composition, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import type { Animation, HandDrawProject, Scene, SceneObject } from "@handdraw/core";
import { progressAt, projectDuration } from "@handdraw/core";

export type PreparedObject = SceneObject & { assetContent?: string };
export type PreparedProject = Omit<HandDrawProject, "scenes"> & { scenes: Array<Omit<HandDrawProject["scenes"][number], "objects"> & { objects: PreparedObject[] }> };
const ease = (progress: number) => progress * progress * (3 - 2 * progress);
const active = (time: number, animations: Animation[], type: Animation["type"]) => animations.filter((animation) => animation.type === type).reduce((value, animation) => Math.max(value, progressAt(time, animation)), 0);

function DrawingHand({ object, progress }: { object: PreparedObject; progress: number }) {
  if (progress <= 0 || progress >= 1) return null;
  const left = object.x + (object.width ?? 200) * (0.04 + progress * 0.84);
  const top = object.y + (object.height ?? 200) * (0.78 - progress * 0.55);
  return <svg viewBox="0 0 170 120" style={{ position: "absolute", left, top, width: 145, height: 102, zIndex: 10, transform: "rotate(-18deg)", filter: "drop-shadow(2px 3px 2px rgba(15,23,42,.18))" }}>
    <path d="M5 8h60l25 70H27Z" fill="#2563eb" /><path d="M60 52c12-17 26-15 34-3l23 35-42 20-23-32c-5-8-2-15 8-20Z" fill="#f1c7a5" />
    <path d="m105 83 48-54 11 11-48 55Z" fill="#1f2937" /><path d="m153 29 10-11 11 11-10 11Z" fill="#f59e0b" />
  </svg>;
}

function Art({ object, time, narrative }: { object: PreparedObject; time: number; narrative: boolean }) {
  const drawAnimations = object.animations.filter((animation) => animation.type === "draw");
  const draw = drawAnimations.length ? active(time, object.animations, "draw") : 1;
  const fade = object.animations.some((animation) => animation.type === "fade") ? active(time, object.animations, "fade") : 1;
  const move = object.animations.filter((animation) => animation.type === "move").at(-1);
  const rotate = object.animations.filter((animation) => animation.type === "rotate").at(-1);
  const scale = object.animations.filter((animation) => animation.type === "scale").at(-1);
  const moveProgress = move ? ease(progressAt(time, move)) : 0;
  const tx = (move?.x ?? 0) * moveProgress, ty = (move?.y ?? 0) * moveProgress;
  const angle = (rotate?.to ?? 0) * ease(rotate ? progressAt(time, rotate) : 0);
  const scaleFrom = scale?.from ?? 1;
  const size = scaleFrom + ((scale?.to ?? 1) - scaleFrom) * ease(scale ? progressAt(time, scale) : 0);
  const highlighted = active(time, object.animations, "highlight") > 0;
  const style = { position: "absolute", left: object.x, top: object.y, width: object.width ?? 200, height: object.height ?? 200, opacity: fade, transform: `translate(${tx}px, ${ty}px) rotate(${angle}deg) scale(${size})`, transformOrigin: "center", filter: highlighted ? "drop-shadow(0 0 14px #fbbf24)" : undefined, "--draw-progress": draw } as React.CSSProperties;
  if (object.kind === "shape") {
    const width = object.width ?? 200, height = object.height ?? 100;
    const common = { ...style, background: object.fill ?? "rgba(255,255,255,.7)", border: object.stroke ? `${object.strokeWidth ?? 3}px solid ${object.stroke}` : undefined } as React.CSSProperties;
    if (object.shape === "line") return <div style={{ ...common, height: object.strokeWidth ?? 4, top: object.y + height / 2, border: "none", borderRadius: 999 }} />;
    const shapeStyle = object.shape === "circle" ? { ...common, borderRadius: "50%" } : object.shape === "pill" ? { ...common, borderRadius: 999 } : object.shape === "bar" ? { ...common, borderRadius: "16px 16px 4px 4px", boxShadow: "0 10px 18px rgba(15,23,42,.10)", transformOrigin: "bottom center" } : { ...common, borderRadius: object.radius ?? 28, boxShadow: "0 14px 30px rgba(15,23,42,.06)" };
    return <div style={shapeStyle}>{object.label && <div style={{ position: "absolute", left: 28, top: 24, color: object.labelColor ?? "#475569", fontFamily: "PingFang SC, sans-serif", fontWeight: 700, fontSize: 25, letterSpacing: "0.08em" }}>{object.label}</div>}</div>;
  }
  if (object.kind === "text") {
    const writes = object.animations.filter((animation) => animation.type === "write");
    const writeProgress = writes.length ? active(time, object.animations, "write") : 1;
    const characters = Array.from(object.text ?? "");
    const visibleText = characters.slice(0, Math.ceil(characters.length * writeProgress)).join("");
    return <div style={{ ...style, width: object.width ?? 1200, height: "auto", fontFamily: narrative ? "Kaiti SC, STKaiti, KaiTi, serif" : "PingFang SC, Microsoft YaHei, sans-serif", fontWeight: narrative ? 500 : 700, fontSize: object.height ?? 48, lineHeight: 1.48, letterSpacing: narrative ? "0.08em" : "0.045em", color: narrative ? "#1c1917" : "#172033", textShadow: narrative ? "0.4px 0.4px 0 #a8a29e" : "0.8px 0.8px 0 #dbe3eb", whiteSpace: "pre-wrap" }}>{visibleText}</div>;
  }
  return <><div style={style} className="handdraw-svg" dangerouslySetInnerHTML={{ __html: object.assetContent ?? "" }} />{!narrative && <DrawingHand object={object} progress={draw} />}</>;
}

function SceneLayer({ scene, time, opacity, narrative }: { scene: PreparedProject["scenes"][number]; time: number; opacity: number; narrative: boolean }) {
  const camera = scene.camera ?? {}; const zoom = camera.zoom ?? 1;
  return <AbsoluteFill className={narrative ? "narrative-layer" : undefined} style={{ opacity, transform: `translate(${camera.x ?? 0}px, ${camera.y ?? 0}px) scale(${zoom})`, transformOrigin: "50% 48%" }}>
    {scene.objects.map((object) => <Art key={object.id} object={object} time={time} narrative={narrative} />)}
  </AbsoluteFill>;
}

function SceneView({ project }: { project: PreparedProject }) {
  const frame = useCurrentFrame(); const { fps } = useVideoConfig(); const time = frame / fps;
  let start = 0, index = project.scenes.length - 1;
  for (let candidate = 0; candidate < project.scenes.length; candidate++) { const scene = project.scenes[candidate]; if (time < start + scene.duration) { index = candidate; break; } start += scene.duration; }
  const scene = project.scenes[index]; const sceneTime = Math.max(0, time - start);
  const transitionDuration = Math.min(scene.transition?.duration ?? 0.45, scene.duration * 0.25);
  const entering = index === 0 ? 1 : ease(Math.min(1, sceneTime / transitionDuration));
  const previous = index > 0 ? project.scenes[index - 1] : undefined;
  const narrative = project.project.style === "narrative-sketch";
  const canvasStyle = narrative ? { backgroundColor: project.project.background ?? "#fffefb", backgroundImage: "linear-gradient(100deg, rgba(255,255,255,.85), rgba(251,247,240,.45))", overflow: "hidden" } : { backgroundColor: project.project.background ?? "#fffdf8", backgroundImage: "radial-gradient(#e7dfd0 0.75px, transparent 0.8px), linear-gradient(110deg, rgba(255,255,255,.72), rgba(255,248,235,.28))", backgroundSize: "11px 11px, 100% 100%", overflow: "hidden" };
  return <AbsoluteFill style={canvasStyle}>
    <style>{`.handdraw-svg svg{width:100%;height:100%;overflow:visible;filter:drop-shadow(1px 1px 0 rgba(15,23,42,.12))}.handdraw-svg svg path,.handdraw-svg svg circle,.handdraw-svg svg line,.handdraw-svg svg polyline,.handdraw-svg svg polygon{stroke-dasharray:1000;stroke-dashoffset:calc(1000 * (1 - var(--draw-progress)));stroke-linecap:round;stroke-linejoin:round}.narrative-layer .handdraw-svg svg{filter:none}.narrative-layer .handdraw-svg svg path,.narrative-layer .handdraw-svg svg circle,.narrative-layer .handdraw-svg svg line,.narrative-layer .handdraw-svg svg polyline,.narrative-layer .handdraw-svg svg polygon{stroke-width:4.25px}`}</style>
    {!narrative && <><div style={{ position: "absolute", top: 48, left: 70, color: "#8b99aa", fontSize: 24, fontFamily: "PingFang SC, sans-serif", fontWeight: 600, letterSpacing: "0.13em", zIndex: 20 }}>{project.project.title}</div><div style={{ position: "absolute", left: 70, top: 96, width: 110, height: 5, background: "#14b8a6", borderRadius: 8, zIndex: 20 }} /></>}
    {previous && sceneTime < transitionDuration && <SceneLayer scene={previous} time={previous.duration} opacity={1 - entering} narrative={narrative} />}
    <SceneLayer scene={scene} time={sceneTime} opacity={entering} narrative={narrative} />
  </AbsoluteFill>;
}

export const RemotionRoot: React.FC = () => <Composition id="HandDrawAnimation" component={SceneView} durationInFrames={30} fps={30} width={1920} height={1080} defaultProps={{ project: { version: 1, project: { title: "Untitled", width: 1920, height: 1080, fps: 30 }, scenes: [] } as PreparedProject }} calculateMetadata={({ props }) => { const project = (props as { project: PreparedProject }).project; return { durationInFrames: Math.max(1, Math.ceil(projectDuration(project) * project.project.fps)), fps: project.project.fps, width: project.project.width, height: project.project.height }; }} />;
