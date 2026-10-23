import React from 'react';
import { Composition } from 'remotion';
import { DoodleComposition, defaultProps } from './DoodleComposition';
import { ReferenceReplica, referenceReplicaProps } from './ReferenceReplica';
import { FentanylFilm, timeline } from './projects/fentanilo-v2/Film';

export const Root: React.FC = () => {
  return (
    <>
      <Composition id="Fentanilo2DStudio" component={FentanylFilm}
        durationInFrames={timeline.durationInFrames} fps={30} width={1080} height={1920}/>
      <Composition
        id="DoodleReel"
        component={DoodleComposition as any}
        durationInFrames={defaultProps.durationInFrames}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={defaultProps as any}
        calculateMetadata={({ props }: any) => {
          return {
            durationInFrames: props?.durationInFrames || defaultProps.durationInFrames,
            width: props?.width || 1080,
            height: props?.height || 1920,
          };
        }}
      />
      <Composition
        id="ReferenceReplica"
        component={ReferenceReplica}
        durationInFrames={referenceReplicaProps.durationInFrames}
        fps={30}
        width={720}
        height={1280}
        defaultProps={referenceReplicaProps as any}
      />
    </>
  );
};
