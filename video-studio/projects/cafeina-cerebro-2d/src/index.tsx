import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { CafeinaCerebro2dFilm, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="cafeina-cerebro-2d"
        component={CafeinaCerebro2dFilm}
        durationInFrames={timeline.durationInFrames}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ aspectRatio: '9:16' as const }}
      />
      <Composition
        id="cafeina-cerebro-2d-16x9"
        component={CafeinaCerebro2dFilm}
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
