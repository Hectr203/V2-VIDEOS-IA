import React from 'react';
import { Composition } from 'remotion';
import { DoodleComposition, defaultProps } from './DoodleComposition';

export const Root: React.FC = () => {
  return (
    <>
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
          };
        }}
      />
    </>
  );
};
