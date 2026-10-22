import React from 'react';
import { spring, useCurrentFrame, useVideoConfig, Img, staticFile } from 'remotion';

interface AnimatedStickerProps {
  stickerName: string;
  startFrame?: number;
  size?: number;
}

export const AnimatedSticker: React.FC<AnimatedStickerProps> = ({
  stickerName,
  startFrame = 0,
  size = 420,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const localFrame = Math.max(0, frame - startFrame);

  // Física de rebote elástico (Spring overshoot)
  const scale = spring({
    frame: localFrame,
    fps,
    config: {
      damping: 10,
      mass: 0.6,
      stiffness: 110,
    },
  });

  // Wiggle o temblor sutil orgánico (efecto cómic / stop-motion)
  const wobbleRotation = Math.sin(localFrame * 0.18) * 3.5;
  const floatY = Math.sin(localFrame * 0.1) * 8;

  // Ruta al SVG estático
  const stickerSrc = staticFile(`stickers/${stickerName}.svg`);

  return (
    <div
      style={{
        transform: `translateY(${floatY}px) scale(${scale}) rotate(${wobbleRotation}deg)`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        filter: 'drop-shadow(10px 14px 0px rgba(17, 17, 17, 0.9))',
      }}
    >
      <Img
        src={stickerSrc}
        style={{
          width: size,
          height: size,
          objectFit: 'contain',
        }}
      />
    </div>
  );
};
