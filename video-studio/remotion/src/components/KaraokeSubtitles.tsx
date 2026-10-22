import React from 'react';
import { useCurrentFrame, useVideoConfig } from 'remotion';

export interface WordTimestamp {
  word: string;
  start: number; // en segundos
  end: number;   // en segundos
}

interface KaraokeSubtitlesProps {
  words: WordTimestamp[];
}

export const KaraokeSubtitles: React.FC<KaraokeSubtitlesProps> = ({ words }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const currentTime = frame / fps;

  // Encontrar el índice de la palabra activa
  const activeIndex = words.findIndex(
    (w) => currentTime >= w.start && currentTime <= w.end
  );

  // Si ninguna palabra está activa en este momento exacto, buscar la última pronunciada
  let displayIndex = activeIndex;
  if (displayIndex === -1) {
    for (let i = words.length - 1; i >= 0; i--) {
      if (currentTime >= words[i].end) {
        displayIndex = i;
        break;
      }
    }
    if (displayIndex === -1 && words.length > 0 && currentTime < words[0].start) {
      displayIndex = 0;
    }
  }

  if (displayIndex === -1 || words.length === 0) {
    return null;
  }

  // Agrupar en ventanas legibles de 4 palabras
  const chunkSize = 4;
  const chunkStart = Math.floor(displayIndex / chunkSize) * chunkSize;
  const currentChunk = words.slice(chunkStart, chunkStart + chunkSize);

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 340,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        padding: '0 40px',
        zIndex: 50,
      }}
    >
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          justifyContent: 'center',
          alignItems: 'center',
          gap: '14px',
          background: 'rgba(15, 23, 42, 0.82)',
          padding: '18px 32px',
          borderRadius: '24px',
          boxShadow: '0 16px 32px rgba(0, 0, 0, 0.4), 0 0 0 4px #111111',
          backdropFilter: 'blur(8px)',
          maxWidth: '92%',
        }}
      >
        {currentChunk.map((w, idx) => {
          const globalIdx = chunkStart + idx;
          const isActive = globalIdx === activeIndex;

          return (
            <span
              key={`${w.word}-${globalIdx}`}
              style={{
                fontFamily: '"Montserrat", "Impact", -apple-system, sans-serif',
                fontSize: isActive ? '58px' : '52px',
                fontWeight: 900,
                letterSpacing: '-0.5px',
                color: isActive ? '#FFE600' : '#FFFFFF',
                textTransform: 'uppercase',
                transform: isActive ? 'scale(1.12) translateY(-2px)' : 'scale(1)',
                transition: 'all 0.08s ease-out',
                display: 'inline-block',
                textShadow: isActive
                  ? '0 0 16px rgba(255, 230, 0, 0.6), 3px 3px 0px #000000'
                  : '2px 2px 0px #000000',
              }}
            >
              {w.word}
            </span>
          );
        })}
      </div>
    </div>
  );
};
