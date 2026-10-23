import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { Helado2dV2Film, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <Composition
      id="la-ciencia-del-helado"
      component={Helado2dV2Film}
      durationInFrames={timeline.durationInFrames}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};

registerRoot(ProjectRoot);
