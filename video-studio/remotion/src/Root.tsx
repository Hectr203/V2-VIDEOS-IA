import React from 'react';
import { Composition } from 'remotion';
import { DoodleComposition, defaultProps } from './DoodleComposition';
import { ReferenceReplica, referenceReplicaProps } from './ReferenceReplica';
import { CombustionEngine, combustionEngineProps } from './CombustionEngine';

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
        width={716}
        height={1274}
        defaultProps={referenceReplicaProps as any}
      />
      <Composition
        id="CombustionEngine"
        component={CombustionEngine}
        durationInFrames={combustionEngineProps.durationInFrames}
        fps={30}
        width={716}
        height={1274}
        defaultProps={combustionEngineProps as any}
      />
    </>
  );
};
