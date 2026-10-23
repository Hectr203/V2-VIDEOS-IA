import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { Helado2dV2Film, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <>
      {/* Variante Vertical 9:16 (TikTok, Reels, Shorts) */}
      <Composition
        id="la-ciencia-del-helado"
        component={Helado2dV2Film}
        durationInFrames={timeline.durationInFrames}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ aspectRatio: '9:16' as const }}
      />
      {/* Variante Horizontal 16:9 (YouTube, Presentaciones) */}
      <Composition
        id="la-ciencia-del-helado-16x9"
        component={Helado2dV2Film}
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
