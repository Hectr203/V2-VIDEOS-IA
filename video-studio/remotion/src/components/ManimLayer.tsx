import React from 'react';
import { OffthreadVideo, staticFile } from 'remotion';

export interface ManimLayerProps {
  clipSrc: string; // e.g., "motion/tecnologia/laptop.webm" or URL
  size?: number;
  x?: number;
  y?: number;
  scale?: number;
  rotate?: number;
}

export const ManimLayer: React.FC<ManimLayerProps> = ({
  clipSrc,
  size = 600,
  x = 0,
  y = 0,
  scale = 1,
  rotate = 0,
}) => {
  const resolvedSrc =
    clipSrc.startsWith('http') || clipSrc.startsWith('data:')
      ? clipSrc
      : staticFile(clipSrc);

  return (
    <div
      style={{
        position: 'absolute',
        top: '50%',
        left: '50%',
        width: size,
        height: size,
        transform: `translate(-50%, -50%) translate(${x}px, ${y}px) scale(${scale}) rotate(${rotate}deg)`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        pointerEvents: 'none',
        zIndex: 6,
      }}
    >
      <OffthreadVideo
        src={resolvedSrc}
        transparent
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'contain',
        }}
      />
    </div>
  );
};
