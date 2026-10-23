import React from 'react';
import { Sequence, Audio, staticFile, useVideoConfig } from 'remotion';
import { Scene, SceneData } from './components/Scene';
import { KaraokeSubtitles, WordTimestamp } from './components/KaraokeSubtitles';

export interface SceneTimingItem extends SceneData {
  start_frame: number;
  duration_in_frames: number;
  audio_data_uri?: string;
}

export interface DoodleCompositionProps {
  scenes: SceneTimingItem[];
  words: WordTimestamp[];
  voiceAudioSrc?: string;
  musicSrc?: string;
  durationInFrames: number;
}

export const defaultProps: DoodleCompositionProps = {
  scenes: [
    {
      id: 1,
      title: 'El Gancho',
      text: '¡Resulta que los piratas usaban parches no por tuertos!',
      callout: '¡EL SECRETO!',
      sticker: 'question',
      sfx: 'whoosh',
      bg_color: '#FEF3C7',
      start_frame: 0,
      duration_in_frames: 100,
    },
    {
      id: 2,
      title: 'La Revelación',
      text: 'Lo hacían para adaptar un ojo a la oscuridad bajo cubierta al instante.',
      callout: 'VISIÓN NOCTURNA',
      sticker: 'eye_patch',
      sfx: 'pop',
      bg_color: '#E0F2FE',
      start_frame: 100,
      duration_in_frames: 120,
    },
  ],
  words: [
    { word: 'Resulta', start: 0.1, end: 0.5 },
    { word: 'que', start: 0.5, end: 0.7 },
    { word: 'los', start: 0.7, end: 0.9 },
    { word: 'piratas', start: 0.9, end: 1.4 },
    { word: 'usaban', start: 1.4, end: 1.8 },
    { word: 'parches', start: 1.8, end: 2.3 },
  ],
  durationInFrames: 220,
};

export const DoodleComposition: React.FC<DoodleCompositionProps> = ({
  scenes = defaultProps.scenes,
  words = defaultProps.words,
  voiceAudioSrc,
  musicSrc = staticFile('music/ambient_curiosity.mp3'),
  durationInFrames,
}) => {
  const { width, height } = useVideoConfig();
  return (
    <div
      style={{
        width,
        height,
        position: 'relative',
        backgroundColor: '#0F172A',
        overflow: 'hidden',
      }}
    >
      {/* Música de fondo atenuada durante todo el video */}
      {musicSrc && <Audio src={musicSrc} volume={0.12} loop />}

      {/* Voz global en caso de audio único continuo */}
      {voiceAudioSrc && <Audio src={voiceAudioSrc} volume={1.0} />}

      {/* Escenas secuenciales con sus audios y SFX dedicados */}
      {scenes.map((scene) => (
        <Sequence
          key={`scene-${scene.id}-${scene.start_frame}`}
          from={scene.start_frame}
          durationInFrames={scene.duration_in_frames}
        >
          {/* Visual de la escena */}
          <Scene scene={scene} durationInFrames={scene.duration_in_frames} />

          {/* Audio narrado propio de la escena */}
          {scene.audio_data_uri && (
            <Audio src={scene.audio_data_uri} volume={1.0} />
          )}

          {/* Efecto de sonido SFX al inicio de la escena */}
          {scene.sfx && (
            <Sequence from={0} durationInFrames={35}>
              <Audio src={staticFile(`sfx/${scene.sfx}.mp3`)} volume={0.4} />
            </Sequence>
          )}
        </Sequence>
      ))}

      {/* Subtítulos dinámicos de estilo Karaoke */}
      <KaraokeSubtitles words={words} />
    </div>
  );
};
