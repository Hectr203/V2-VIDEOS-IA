import React from 'react';
import { registerRoot, Composition } from 'remotion';
import { FentanylFilm, timeline } from './Film';

export const ProjectRoot: React.FC = () => {
  return (
    <Composition
      id="fentanilo-la-llave-quimica"
      component={FentanylFilm}
      durationInFrames={timeline.durationInFrames}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};

registerRoot(ProjectRoot);
