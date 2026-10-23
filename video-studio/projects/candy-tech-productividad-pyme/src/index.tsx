import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { CandyTechProductividadPymeFilm, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="candy-tech-productividad-pyme"
        component={CandyTechProductividadPymeFilm}
        durationInFrames={timeline.durationInFrames}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ aspectRatio: '9:16' as const }}
      />
      <Composition
        id="candy-tech-productividad-pyme-16x9"
        component={CandyTechProductividadPymeFilm}
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
