import React from 'react';
import { Audio, Sequence, staticFile } from 'remotion';

interface AudioSceneTiming {
  sfx: string;
  startFrame: number;
}

interface AudioMixerProps {
  voiceAudioSrc: string;
  musicSrc?: string;
  scenesTiming: AudioSceneTiming[];
}

export const AudioMixer: React.FC<AudioMixerProps> = ({
  voiceAudioSrc,
  musicSrc = staticFile('music/ambient_curiosity.mp3'),
  scenesTiming,
}) => {
  return (
    <>
      {/* Voz en off principal (Edge-TTS) */}
      <Audio src={voiceAudioSrc} volume={1.0} />

      {/* Música de fondo ambiental atenuada */}
      {musicSrc && <Audio src={musicSrc} volume={0.12} loop />}

      {/* Efectos de sonido (SFX) por escena */}
      {scenesTiming.map((scene, idx) => {
        const sfxFile = staticFile(`sfx/${scene.sfx}.mp3`);
        return (
          <Sequence
            key={`sfx-${idx}-${scene.startFrame}`}
            from={scene.startFrame}
            durationInFrames={45}
          >
            <Audio src={sfxFile} volume={0.45} />
          </Sequence>
        );
      })}
    </>
  );
};
