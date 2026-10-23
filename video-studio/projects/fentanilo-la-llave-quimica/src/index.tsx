import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { FentanylFilm, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <>
      {/* Variante Vertical 9:16 (TikTok, Reels, Shorts) */}
      <Composition
        id="fentanilo-la-llave-quimica"
        component={FentanylFilm}
        durationInFrames={timeline.durationInFrames}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ aspectRatio: '9:16' as const }}
      />
      {/* Variante Horizontal 16:9 (YouTube, Presentaciones) */}
      <Composition
        id="fentanilo-la-llave-quimica-16x9"
        component={FentanylFilm}
        durationInFrames={timeline.durationInFrames}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{ aspectRatio: '16:9' as const }}
      />
    </>
  );
};

registerRoot(ProjectRoot);
