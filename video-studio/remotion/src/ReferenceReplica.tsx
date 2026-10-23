import React from 'react';
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';

const scenes = [
  { from: 0, to: 135, kind: 'dance', bg: '#f7a21b', text: '¿ah, bien?' },
  { from: 135, to: 255, kind: 'split', bg: '#252060', text: 'el dolor y' },
  { from: 255, to: 390, kind: 'lock', bg: '#147f91', text: 'dos:' },
  { from: 390, to: 540, kind: 'key', bg: '#147f91', text: 'llave.' },
  { from: 540, to: 720, kind: 'person', bg: '#302064', text: 'llaves,' },
  { from: 720, to: 870, kind: 'scale', bg: '#44215d', text: 'x100' },
  { from: 870, to: 1020, kind: 'cup', bg: '#f7a21b', text: 'un café con gloria' },
  { from: 1020, to: 1170, kind: 'burst', bg: '#f7a21b', text: 'desaparece.' },
  { from: 1170, to: 1380, kind: 'lungs', bg: '#302064', text: 'que te hace' },
  { from: 1380, to: 1629, kind: 'dance', bg: '#f7a21b', text: '¡y eso es lo que mata!' },
];

const Bubble = ({ children, x, y, size = 30 }: any) => <div style={{ position: 'absolute', left: x, top: y, fontFamily: 'Arial Black, sans-serif', fontSize: size, color: '#fff', textShadow: '3px 4px 0 #171334', fontWeight: 900 }}>{children}</div>;

function Character({ frame, x = 540, y = 950, jumping = false }: any) {
  const bob = jumping ? Math.sin(frame * 0.18) * 28 : Math.sin(frame * 0.08) * 4;
  const arm = Math.sin(frame * 0.15) * 12;
  return <div style={{ position: 'absolute', left: x - 150, top: y - 350 + bob, width: 300, height: 470, transform: `rotate(${Math.sin(frame * .06) * 2}deg)` }}>
    <div style={{ position: 'absolute', left: 72, top: 0, width: 156, height: 156, borderRadius: '50%', background: '#a95b52', border: '7px solid #171334' }} />
    <div style={{ position: 'absolute', left: 43, top: 8, width: 215, height: 92, borderRadius: '60% 60% 20% 20%', background: '#251334', transform: 'rotate(-5deg)' }} />
    <div style={{ position: 'absolute', left: 89, top: 90, width: 18, height: 10, borderRadius: 10, background: '#171334' }} />
    <div style={{ position: 'absolute', left: 105, top: 155, width: 92, height: 150, borderRadius: '35% 35% 15% 15%', background: '#18ad85', border: '7px solid #171334' }} />
    <div style={{ position: 'absolute', left: 77, top: 166, width: 32, height: 170, background: '#a95b52', border: '7px solid #171334', transform: `rotate(${-24 + arm}deg)`, transformOrigin: 'top' }} />
    <div style={{ position: 'absolute', left: 190, top: 166, width: 32, height: 170, background: '#a95b52', border: '7px solid #171334', transform: `rotate(${24 - arm}deg)`, transformOrigin: 'top' }} />
    <div style={{ position: 'absolute', left: 118, top: 292, width: 34, height: 125, background: '#f1a735', border: '7px solid #171334', transform: 'rotate(8deg)', transformOrigin: 'top' }} />
    <div style={{ position: 'absolute', left: 171, top: 292, width: 34, height: 125, background: '#f1a735', border: '7px solid #171334', transform: 'rotate(-8deg)', transformOrigin: 'top' }} />
    <div style={{ position: 'absolute', left: 87, top: 405, width: 88, height: 30, borderRadius: '50%', background: '#7658bd', border: '7px solid #171334' }} />
    <div style={{ position: 'absolute', left: 174, top: 405, width: 88, height: 30, borderRadius: '50%', background: '#7658bd', border: '7px solid #171334' }} />
  </div>;
}

function Icon({ kind, frame }: any) {
  const pulse = 1 + Math.sin(frame * .12) * .06;
  if (kind === 'lock') return <div style={{ transform: `scale(${pulse})`, width: 300, height: 260, borderRadius: 45, background: '#36c5d9', border: '10px solid #171334', boxShadow: '18px 20px 0 #125d76' }}><div style={{ position: 'absolute', left: 100, top: 100, width: 100, height: 70, background: '#171334', borderRadius: 35 }} /></div>;
  if (kind === 'key') return <div style={{ transform: `rotate(${Math.sin(frame*.08)*5}deg) scale(${pulse})`, fontSize: 270, filter: 'drop-shadow(12px 15px 0 #171334)' }}>🔑</div>;
  if (kind === 'scale') return <div style={{ fontSize: 280, transform: `scale(${pulse})`, filter: 'drop-shadow(10px 14px 0 #171334)' }}>⚖️</div>;
  if (kind === 'cup') return <div style={{ fontSize: 260, transform: `rotate(${Math.sin(frame*.12)*4}deg)`, filter: 'drop-shadow(10px 14px 0 #171334)' }}>☕</div>;
  if (kind === 'lungs') return <div style={{ fontSize: 290, transform: `scale(${pulse})`, filter: 'drop-shadow(10px 14px 0 #171334)' }}>🫁</div>;
  return <div style={{ fontSize: 260 }}>✦</div>;
}

export const ReferenceReplica: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const scene = scenes.find(s => frame >= s.from && frame < s.to) || scenes[scenes.length - 1];
  const local = frame - scene.from;
  const enter = spring({ frame: local, fps: 30, config: { damping: 12, stiffness: 120 } });
  return <AbsoluteFill style={{ background: scene.bg, overflow: 'hidden', fontFamily: 'Arial, sans-serif' }}>
    <div style={{ position: 'absolute', inset: 0, opacity: .22, backgroundImage: 'radial-gradient(#fff 2px, transparent 2px)', backgroundSize: '52px 52px' }} />
    <div style={{ position: 'absolute', inset: 24, border: '8px solid #171334', borderRadius: 36, pointerEvents: 'none' }} />
    <Bubble x={70} y={125} size={34}>{scene.text}</Bubble>
    <div style={{ position: 'absolute', left: 60, top: 250, width: width - 120, height: height - 420, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `translateY(${interpolate(enter, [0, 1], [80, 0])}px) scale(${interpolate(enter, [0, 1], [.7, 1])})` }}>
      {scene.kind === 'dance' || scene.kind === 'person' ? <Character frame={frame} jumping={scene.kind === 'dance'} /> : <Icon kind={scene.kind} frame={frame} />}
      {scene.kind === 'split' && <><div style={{ position: 'absolute', left: 0, width: 10, height: 600, background: '#e9b13b', transform: 'rotate(14deg)' }} /><Bubble x={80} y={180} size={44}>dolor</Bubble><Bubble x={530} y={420} size={44}>placer</Bubble></>}
      {scene.kind === 'burst' && <div style={{ position: 'absolute', fontSize: 250, color: '#fff', transform: `rotate(${local * 2}deg) scale(${1 + local / 200})` }}>✹</div>}
    </div>
    {scene.kind === 'lock' && <><Bubble x={110} y={1160} size={28}>receptor opioide</Bubble><Bubble x={540} y={1190} size={28}>endorfinas</Bubble></>}
    {scene.kind === 'scale' && <Bubble x={460} y={1070} size={42}>x100</Bubble>}
    {scene.kind === 'lungs' && <Bubble x={390} y={1180} size={34}>2 mg</Bubble>}
  </AbsoluteFill>;
};

export const referenceReplicaProps = { durationInFrames: 1630 };
