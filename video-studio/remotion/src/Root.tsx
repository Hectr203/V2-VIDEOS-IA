import React from 'react';
import { Composition } from 'remotion';
import { DoodleComposition, defaultProps } from './DoodleComposition';
import { ReferenceReplica, referenceReplicaProps } from './ReferenceReplica';
import { CombustionEngine, combustionEngineProps } from './CombustionEngine';
import { ChavoScene, ChavoBarrelScene } from '../../proyectos-test/el-chavo-del-8/src/index';

export const Root: React.FC = () => {
  return (
    <>
      {/* Test Project: El Chavo del 8 (video-studio/proyectos-test/el-chavo-del-8) */}
      <Composition
        id="ChavoEjemplo1Sentado"
        component={ChavoScene}
        durationInFrames={180}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ showAllTransitions: true }}
      />
      <Composition
        id="ChavoEjemplo2Barril"
        component={ChavoBarrelScene}
        durationInFrames={180}
        fps={30}
        width={1080}
        height={1920}
      />
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
