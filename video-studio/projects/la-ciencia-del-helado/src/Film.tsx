import React, {useEffect, useState} from 'react';
import {AbsoluteFill, Audio, Sequence, cancelRender, continueRender, delayRender, staticFile, useCurrentFrame} from 'remotion';
import timelineData from './timeline.json';
import {
  ArtDefs, Backdrop, BrainFreezeArt, ChurningMachine, EmulsionBridge,
  FrozenRock, IceCreamCone, IceCreamTub, IdealServing, Label, MicroscopeView,
  Person, Spark, ThreeIngredients, clamp, ease, mix, seeded, wave
} from './art';

export const timeline = timelineData;
type Scene = typeof timeline.scenes[number];

function SceneArt({scene, f}: {scene: Scene; f: number}) {
  const enter = ease(f / 18);
  switch (scene.id) {
    case 'hook': {
      const split = ease((f - 20) / 30);
      return <>
        <IceCreamTub f={f} split={split} />
        <Label x={360} y={1140} text="50% CREMA LÁCTEA · 50% AIRE" size={20} color="#ffeed1" />
      </>;
    }
    case 'overrun': {
      return <>
        <circle cx={360} cy={660} r={250} fill="url(#warm-aura)" opacity={.35} />
        <Person f={f} pose="cheer" y={760} scale={.92} />
        {Array.from({length: 14}, (_, i) => (
          <circle key={i} cx={160 + seeded(i)*400} cy={450 + (i%3)*200 + wave(f, .06, 12, i)} r={10 + seeded(i)*14} fill="#ffffff" opacity=".7" />
        ))}
        <Label x={360} y={1140} text="EL OVERRUN CREA CREMOSIDAD" size={20} color="#9effeb" />
      </>;
    }
    case 'rock': {
      return <>
        <FrozenRock f={f} />
        <Label x={360} y={1140} text="SIN AIRE = UN BLOQUE DE HIELO" size={20} color="#ffb7cc" />
      </>;
    }
    case 'ingredients': {
      return <>
        <ThreeIngredients f={f} />
        <Label x={360} y={1140} text="TRES BASES FUNDAMENTALES" size={20} color="#9effeb" />
      </>;
    }
    case 'antifreeze': {
      return <>
        <circle cx={360} cy={660} r={240} fill="url(#aura)" opacity={.3} />
        <g transform={`translate(360 660) rotate(${wave(f,.02,4)})`}>
          {Array.from({length: 8}, (_, i) => {
            const a = i * Math.PI / 4;
            return <polygon key={i} points="-20,-12 0,-25 20,-12 0,0" fill="#ffffff" transform={`translate(${Math.cos(a)*140} ${Math.sin(a)*140})`} />;
          })}
          <IceCreamCone f={f} scale={.9} />
        </g>
        <Label x={360} y={1140} text="EL AZÚCAR EVITA CRISTALES DUROS" size={19} color="#ffd8ea" />
      </>;
    }
    case 'emulsion': {
      return <>
        <EmulsionBridge f={f} />
        <Label x={360} y={1140} text="LA CIENCIA DE LA EMULSIÓN" size={20} color="#affced" />
      </>;
    }
    case 'pasteurization': {
      return <>
        <g transform="translate(360 680)">
          <ellipse cy="190" rx="170" ry="28" fill="#1b1236" opacity=".3" />
          <path d="M-140-60 L-120 160 Q0 190 120 160 L140-60Z" fill="#ff7644" stroke="#ffaa80" strokeWidth="6" />
          <path d="M-125-50 L-108 145 Q0 175 108 145 L125-50Z" fill="#ffe2b5" />
          {[-1,0,1].map(i => (
            <path key={i} d={`M${i*65} -80 C${i*65-30+wave(f,.08,12,i)} -130 ${i*65+30} -160 ${i*65+wave(f,.07,18,i)} -210`} stroke="#ffedd5" strokeWidth="8" fill="none" strokeLinecap="round" opacity=".7" />
          ))}
          <text x="0" y="70" textAnchor="middle" fill="#8f3214" fontSize="48" fontWeight="900">80°C</text>
        </g>
        <Label x={360} y={1140} text="ELIMINACIÓN DE BACTERIAS Y DISOLUCIÓN" size={18} color="#ffe5bc" />
      </>;
    }
    case 'pressure': {
      return <>
        <g transform="translate(360 670)">
          <rect x="-180" y="-80" width="130" height="160" rx="20" fill="#1e3256" stroke="#4d74ab" strokeWidth="6" />
          <path d="M-50 -30 L40 -5 V5 L-50 30Z" fill="#315587" />
          <rect x="40" y="-120" width="140" height="240" rx="25" fill="#14213d" stroke="#4d74ab" strokeWidth="6" />
          {Array.from({length: 22}, (_, i) => (
            <circle key={i} cx={60 + seeded(i)*100} cy={-90 + (i*11)%180 + wave(f, .1, 5, i)} r={2.5 + seeded(i)*3} fill="#ffe89a" />
          ))}
          <text x="0" y="-130" textAnchor="middle" fill="#75e2ff" fontSize="36" fontWeight="850">2,000 PSI</text>
        </g>
        <Label x={360} y={1140} text="HOMOGENEIZACIÓN A ALTA PRESIÓN" size={19} color="#a6f4ff" />
      </>;
    }
    case 'ripening': {
      return <>
        <g transform="translate(360 670)">
          <circle r="190" fill="url(#bg-purple)" stroke="#6a529e" strokeWidth="8" />
          <circle r="170" fill="#1b1236" />
          <text x="0" y="-20" textAnchor="middle" fill="#86ecff" fontSize="64" fontWeight="900">4°C</text>
          <text x="0" y="45" textAnchor="middle" fill="#e0d5f8" fontSize="24" fontWeight="700">REPOSO Y MADURACIÓN</text>
          {Array.from({length: 12}, (_, i) => (
            <circle key={i} cx={Math.cos(i*Math.PI/6)*130} cy={Math.sin(i*Math.PI/6)*130} r="7" fill="#6a529e" />
          ))}
        </g>
        <Label x={360} y={1140} text="LAS PROTEÍNAS LÁCTEAS SE HIDRATAN" size={19} color="#d6b8ff" />
      </>;
    }
    case 'churning': {
      return <>
        <ChurningMachine f={f} />
        <Label x={360} y={1140} text="BATIDO Y CONGELACIÓN SIMULTÁNEA" size={19} color="#84f0ff" />
      </>;
    }
    case 'crystals': {
      return <>
        <MicroscopeView f={f} />
        <Label x={360} y={1140} text="LA CLAVE: CRISTALES ULTRA FINOS" size={19} color="#b4f8ff" />
      </>;
    }
    case 'soft': {
      return <>
        <Person f={f} pose="eat" y={760} scale={.9} />
        <Label x={360} y={1140} text="TEXTURA SUAVE Y CREMOSA" size={20} color="#ffeed1" />
      </>;
    }
    case 'polar_tunnel': {
      return <>
        <g transform="translate(360 680)">
          <rect x="-190" y="-120" width="380" height="240" rx="30" fill="#16223d" stroke="#3b699c" strokeWidth="8" />
          <text x="0" y="-140" textAnchor="middle" fill="#75e2ff" fontSize="40" fontWeight="900">-40°C</text>
          <path d="M-150 40 L150 40" stroke="#75e2ff" strokeWidth="6" strokeDasharray="16 12" />
          <g transform={`translate(${wave(f,.04,20)} 0)`}>
            <rect x="-40" y="-30" width="80" height="60" rx="12" fill="#e84a73" />
            <rect x="-35" y="-25" width="70" height="15" rx="5" fill="#ffd4e0" />
          </g>
          {[-1, 1].map(side => (
            <path key={side} d={`M${side*140} -60 L${side*110} -40 L${side*140} -20`} stroke="#a4edff" strokeWidth="5" fill="none" strokeLinecap="round" />
          ))}
        </g>
        <Label x={360} y={1140} text="TÚNEL DE CONGELACIÓN ULTRA RÁPIDO" size={18} color="#b2f5ff" />
      </>;
    }
    case 'brain_freeze': {
      return <>
        <BrainFreezeArt f={f} />
        <Label x={360} y={1140} text="REFLEJO NERVIOSO POR FRÍO RÁPIDO" size={19} color="#ffb4ce" />
      </>;
    }
    case 'ideal_temp': {
      return <>
        <IdealServing f={f} />
        <Label x={360} y={1140} text="DEGUSTACIÓN GOURMET A -14°C" size={20} color="#75efff" />
      </>;
    }
    case 'call_to_action': {
      return <>
        <circle cx={360} cy={660} r={270} fill="url(#warm-aura)" opacity={.4} />
        <Person f={f} pose="cheer" y={750} scale={.93} />
        {[0, 1, 2, 3].map(i => (
          <Spark key={i} x={120 + i*160} y={440 + (i%2)*380} size={16 + wave(f, .09, 6, i)} color="#fffaad" />
        ))}
        <Label x={360} y={1140} text="CIENCIA Y PLACER EN CADA CUCHARADA" size={19} color="#fff1c4" />
      </>;
    }
    default:
      return null;
  }
}

function Captions({scene, f}: {scene: Scene; f: number}) {
  const time = f / 30;
  const words = scene.words;
  let current = words.findIndex(w => time >= w.start && time < w.end);
  if (current < 0) current = Math.max(0, words.findIndex(w => w.start > time) - 1);
  if (time >= words[words.length - 1].end) current = words.length - 1;

  const groups: {word: string; start: number; end: number}[][] = [];
  for (const word of words) {
    const last = groups[groups.length - 1];
    if (!last || last.length >= 5 || last.map(w => w.word).join(' ').length + word.word.length > 30) {
      groups.push([word]);
    } else {
      last.push(word);
    }
  }
  const active = words[current];
  const group = groups.find(g => g.includes(active)) || groups[0];
  const pop = ease((time - group[0].start) * 12);

  return (
    <div style={{
      position: 'absolute', left: 48, top: 174, width: 624, textAlign: 'center',
      fontSize: 35, lineHeight: 1.32, fontWeight: 750, letterSpacing: -0.6,
      transform: 'translateY(' + mix(6, 0, pop) + 'px)', color: '#fff8f1',
      textShadow: '0 3px 15px rgba(20,10,42,0.4)'
    }}>
      {group.map((w, i) => (
        <span key={w.start + '-' + i} style={{
          display: 'inline-block', padding: '2px 7px', margin: '1px 0', borderRadius: 8,
          background: w === active ? 'rgba(25,18,52,0.66)' : 'transparent',
          color: w === active ? '#fff8bb' : '#fff9ef',
          opacity: time >= w.start ? 1 : 0.58
        }}>{w.word} </span>
      ))}
    </div>
  );
}

function Shot({scene, index}: {scene: Scene; index: number}) {
  const f = useCurrentFrame();
  const gold = scene.palette === 'gold';
  const camera = 1 + ease(f / scene.frames) * 0.018;
  const fade = scene.id === 'call_to_action' ? 1 : ease((scene.frames - f) / 7);

  return (
    <AbsoluteFill style={{opacity: fade, background: scene.palette === 'gold' ? '#f5b53d' : scene.palette === 'teal' ? '#115466' : '#271747'}}>
      <svg width="720" height="1280" viewBox="0 0 720 1280" style={{position: 'absolute', inset: 0, overflow: 'hidden'}}>
        <ArtDefs />
        <Backdrop palette={scene.palette} f={f} />
        <g transform={`translate(360 730) scale(${camera}) translate(-360 -730)`}>
          <SceneArt scene={scene} f={f} />
        </g>
        <g fill={gold ? '#6b472e' : '#cebee2'} opacity="0.75" fontSize="16" fontWeight="700" letterSpacing="2.2">
          <text x="48" y="75">LA CIENCIA DEL HELADO</text>
          <text x="672" y="75" textAnchor="end">{String(index + 1).padStart(2, '0')} / {timeline.scenes.length}</text>
        </g>
        <text x="360" y="130" textAnchor="middle" fill={gold ? '#794d2f' : '#beadd5'} fontSize="17" fontWeight="650" letterSpacing="2.5">{scene.chapter}</text>
        <rect x="48" y="1213" width="624" height="3" rx="2" fill={gold ? '#8d5a35' : '#a98fd2'} opacity="0.2" />
        <rect x="48" y="1213" width={624 * clamp((scene.start + f) / timeline.durationInFrames)} height="3" rx="2" fill={gold ? '#7e4d2a' : '#bfb0e3'} opacity="0.6" />
        <text x="48" y="1250" fill={gold ? '#744a2c' : '#9c87b8'} fontSize="13" letterSpacing="1.5">UNA EXPLICACIÓN VISUAL</text>
        <text x="672" y="1250" fill={gold ? '#744a2c' : '#9c87b8'} fontSize="13" textAnchor="end">FÍSICA · QUÍMICA</text>
      </svg>
      <Captions scene={scene} f={f} />
    </AbsoluteFill>
  );
}

const getAsset = (file: string) => {
  const base = file.split('/').pop() || file;
  return staticFile(base);
};

export const Helado2dV2Film: React.FC<{aspectRatio?: '9:16' | '16:9'}> = ({aspectRatio = '9:16'}) => {
  const isHorizontal = aspectRatio === '16:9';
  const [handle] = useState(() => delayRender('Cargando tipografía'));
  useEffect(() => {
    const font = new FontFace('StudioSans', `url(${getAsset('UbuntuSans.ttf')})`, {weight: '100 900'});
    font.load().then(loaded => { document.fonts.add(loaded); continueRender(handle); }).catch(cancelRender);
  }, [handle]);

  return (
    <AbsoluteFill style={{background: '#1f1338', fontFamily: 'StudioSans, sans-serif'}}>
      {isHorizontal ? (
        <div style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'radial-gradient(ellipse at center, #2e1a54 0%, #110924 100%)'
        }}>
          <div style={{
            position: 'relative',
            width: 720,
            height: 1280,
            transform: 'scale(0.84375)',
            boxShadow: '0 0 120px rgba(0,0,0,0.7)',
            borderRadius: 24,
            overflow: 'hidden'
          }}>
            {timeline.scenes.map((scene, i) => (
              <Sequence key={scene.id} from={scene.start} durationInFrames={scene.frames}>
                <Shot scene={scene} index={i} />
                <Audio src={getAsset(scene.audio)} volume={0.95} />
              </Sequence>
            ))}
          </div>
        </div>
      ) : (
        <div style={{position: 'absolute', width: 720, height: 1280, transform: 'scale(1.5)', transformOrigin: 'top left'}}>
          {timeline.scenes.map((scene, i) => (
            <Sequence key={scene.id} from={scene.start} durationInFrames={scene.frames}>
              <Shot scene={scene} index={i} />
              <Audio src={getAsset(scene.audio)} volume={0.95} />
            </Sequence>
          ))}
        </div>
      )}
      <Audio src={getAsset('score.wav')} volume={0.8} />
    </AbsoluteFill>
  );
};

