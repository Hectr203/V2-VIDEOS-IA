import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { AnimatedSticker } from './AnimatedSticker';
import { ManimLayer } from './ManimLayer';

export interface SceneData {
  id: number;
  title: string;
  text: string;
  callout: string;
  sticker: string;
  sfx: string;
  bg_color: string;
  motion_type?: 'sticker' | 'manim';
  manim_clip?: string;
}

interface SceneProps {
  scene: SceneData;
  durationInFrames: number;
}

export const Scene: React.FC<SceneProps> = ({ scene, durationInFrames }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Animación del Callout superior (banner de impacto)
  const bannerScale = interpolate(frame, [0, 8], [0.8, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

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
        paddingTop: 180,
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
          fontSize: '44px',
          letterSpacing: '1px',
          textTransform: 'uppercase',
          boxShadow: '8px 8px 0px rgba(0, 0, 0, 0.3)',
          marginBottom: 100,
          zIndex: 10,
        }}
      >
        {scene.callout}
      </div>

      {/* Ilustración / Sticker animado central o Capa Manim */}
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
        {scene.manim_clip || scene.motion_type === 'manim' ? (
          <ManimLayer clipSrc={scene.manim_clip || `motion/${scene.sticker}.webm`} size={520} />
        ) : (
          <AnimatedSticker stickerName={scene.sticker} size={460} />
        )}
      </div>
    </div>
  );
};
