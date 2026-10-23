import React from 'react';
import { interpolate, Loop, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { AnimatedSticker } from './AnimatedSticker';
import { ManimLayer } from './ManimLayer';
import {
  Scene1HookRig,
  Scene2BalanzaRig,
  Scene4LockAndKeyRig,
  Scene8EndorphinsRig,
  Scene10FakeKeyRig,
  Scene12CoffeeRig,
  Scene16LungsRig,
  Scene17SaltGrainsRig,
} from './RiggedCharacters';

export interface SceneData {
  id: number;
  title: string;
  text: string;
  callout: string;
  sticker: string;
  sfx: string;
  bg_color: string;
  motion_type?: 'sticker' | 'manim' | 'rig';
  rig_component?: string;
  manim_clip?: string;
  svg_markup?: string;
  source_video_src?: string | null;
  source_start_seconds?: number;
  source_media_duration_seconds?: number | null;
  source_audio_enabled?: boolean;
}

interface SceneProps {
  scene: SceneData;
  durationInFrames: number;
}

export const Scene: React.FC<SceneProps> = ({ scene, durationInFrames }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const landscape = width > height;
  const safeSceneId = Number.isFinite(scene.id) ? Math.max(0, Math.trunc(scene.id)) : 0;

  // Animación del Callout superior (banner de impacto)
  const bannerScale = interpolate(frame, [0, 8], [0.8, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const svgLayerMotion = scene.svg_markup
    ? Array.from({ length: 12 }, (_, index) => {
        const layer = index + 1;
        const phase = frame * (0.035 + (index % 4) * 0.006) + index * 0.9;
        const drift = Math.sin(phase) * (2 + (index % 3) * 1.5);
        const lift = Math.cos(phase * 0.8) * (1.5 + (index % 2) * 1.5);
        return `.scene-svg-${safeSceneId} > svg > :nth-child(${layer}):not(defs){transform-box:fill-box;transform-origin:center;transform:translate(${drift.toFixed(2)}px,${lift.toFixed(2)}px)}`;
      }).join('\n')
    : '';

  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        backgroundColor: scene.bg_color,
        backgroundImage: `
          radial-gradient(#111111 1.2px, transparent 1.2px),
          radial-gradient(#111111 1.2px, ${scene.bg_color} 1.2px)
        `,
        backgroundSize: '36px 36px',
        backgroundPosition: '0 0, 18px 18px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'flex-start',
        position: 'relative',
        overflow: 'hidden',
        paddingTop: landscape ? 90 : 180,
      }}
    >
      {/* Marco estilo cómic */}
      <div
        style={{
          position: 'absolute',
          top: 30,
          bottom: 30,
          left: 30,
          right: 30,
          border: '6px solid #111111',
          borderRadius: 36,
          pointerEvents: 'none',
          boxShadow: 'inset 0 0 0 3px rgba(255, 255, 255, 0.4)',
        }}
      />

      {/* Callout / Banner superior */}
      <div
        style={{
          transform: `scale(${bannerScale}) rotate(-1.5deg)`,
          backgroundColor: '#111111',
          color: '#FFE600',
          padding: '16px 36px',
          borderRadius: '16px',
          fontFamily: '"Impact", "Montserrat", sans-serif',
          fontSize: landscape ? '52px' : '44px',
          letterSpacing: '1px',
          textTransform: 'uppercase',
          boxShadow: '8px 8px 0px rgba(0, 0, 0, 0.3)',
          marginBottom: landscape ? 24 : 100,
          zIndex: 10,
        }}
      >
        {scene.callout}
      </div>

      {/* Ilustración SVG original generada por IA y animada con Remotion */}
      <div
        style={{
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginTop: -60,
          zIndex: 5,
        }}
      >
        {scene.source_video_src ? (
          <Loop durationInFrames={Math.max(1, durationInFrames)}>
            <OffthreadVideo
              src={staticFile(scene.source_video_src.replace(/^\//, ''))}
              startFrom={Math.max(0, Math.min(
                Math.round((scene.source_start_seconds || 0) * fps),
                Math.floor(Math.max(0, (scene.source_media_duration_seconds || 0.1) - 0.1) * fps),
              ))}
              muted={!scene.source_audio_enabled}
              style={{ width: '100%', height: '100%', objectFit: 'cover', border: '8px solid #111', borderRadius: 24 }}
            />
          </Loop>
        ) : scene.motion_type === 'rig' || scene.rig_component ? (
          <div
            style={{
              width: landscape ? 900 : 720,
              height: landscape ? 600 : 720,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              filter: 'drop-shadow(0 20px 25px rgba(0,0,0,0.35))',
            }}
          >
            {scene.rig_component === 'Scene1HookRig' ? <Scene1HookRig /> :
             scene.rig_component === 'Scene2BalanzaRig' ? <Scene2BalanzaRig /> :
             scene.rig_component === 'Scene4LockAndKeyRig' ? <Scene4LockAndKeyRig /> :
             scene.rig_component === 'Scene8EndorphinsRig' ? <Scene8EndorphinsRig /> :
             scene.rig_component === 'Scene10FakeKeyRig' ? <Scene10FakeKeyRig /> :
             scene.rig_component === 'Scene12CoffeeRig' ? <Scene12CoffeeRig /> :
             scene.rig_component === 'Scene16LungsRig' ? <Scene16LungsRig /> :
             scene.rig_component === 'Scene17SaltGrainsRig' ? <Scene17SaltGrainsRig /> :
             <Scene1HookRig />}
          </div>
        ) : scene.svg_markup ? (
          <>
          <style>{svgLayerMotion}</style>
          <div
            className={`scene-svg-${safeSceneId}`}
            style={{
              width: landscape ? 1120 : 780,
              height: landscape ? 650 : 900,
              transform: `translateY(${Math.sin(frame * 0.08) * 10}px) scale(${interpolate(frame, [0, 12], [0.88, 1], { extrapolateRight: 'clamp' })})`,
              filter: 'drop-shadow(0 24px 22px rgba(0,0,0,.22))',
            }}
            dangerouslySetInnerHTML={{ __html: scene.svg_markup }}
          />
          </>
        ) : scene.manim_clip || scene.motion_type === 'manim' ? (
          <ManimLayer clipSrc={scene.manim_clip || `motion/${scene.sticker}.webm`} size={520} />
        ) : (
          <AnimatedSticker stickerName={scene.sticker} size={460} />
        )}
      </div>
    </div>
  );
};
