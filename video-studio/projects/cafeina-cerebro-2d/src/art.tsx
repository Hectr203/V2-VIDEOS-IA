import React from 'react';

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const wave = (f: number, speed = .06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
const seeded = (n: number) => { const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; return a - Math.floor(a); };
type Point = {x: number; y: number};

export function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx=b.x-a.x, dy=b.y-a.y, d=clamp(Math.hypot(dx,dy),1,l1+l2-.01);
  const angle=Math.atan2(dy,dx)+bend*Math.acos(clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1));
  return {x:a.x+Math.cos(angle)*l1,y:a.y+Math.sin(angle)*l1};
}

export const ArtDefs = () => <defs>
  <radialGradient id="bg-purple" cx="48%" cy="30%" r="78%"><stop stopColor="#6641a4"/><stop offset=".52" stopColor="#302052"/><stop offset="1" stopColor="#100d25"/></radialGradient>
  <radialGradient id="bg-teal" cx="50%" cy="35%" r="80%"><stop stopColor="#34b7ad"/><stop offset=".5" stopColor="#14566b"/><stop offset="1" stopColor="#10253e"/></radialGradient>
  <radialGradient id="bg-gold" cx="48%" cy="35%" r="75%"><stop stopColor="#fff2a3"/><stop offset=".46" stopColor="#d99439"/><stop offset="1" stopColor="#592c48"/></radialGradient>
  <radialGradient id="bg-crimson" cx="50%" cy="35%" r="80%"><stop stopColor="#d65d70"/><stop offset=".48" stopColor="#702b50"/><stop offset="1" stopColor="#241b37"/></radialGradient>
  <linearGradient id="skin" x2="1" y2="1"><stop stopColor="#f6c18e"/><stop offset=".56" stopColor="#d78e65"/><stop offset="1" stopColor="#a95e55"/></linearGradient>
  <linearGradient id="hair" x2=".8" y2="1"><stop stopColor="#452c35"/><stop offset=".52" stopColor="#251d31"/><stop offset="1" stopColor="#101629"/></linearGradient>
  <linearGradient id="coat" x2="1" y2="1"><stop stopColor="#c6f6e8"/><stop offset=".48" stopColor="#67bbaa"/><stop offset="1" stopColor="#31677c"/></linearGradient>
  <linearGradient id="gold" x2=".8" y2="1"><stop stopColor="#fff1ae"/><stop offset=".45" stopColor="#ffc459"/><stop offset="1" stopColor="#e56e55"/></linearGradient>
  <radialGradient id="glow"><stop stopColor="#b1fff4" stopOpacity=".62"/><stop offset="1" stopColor="#55e4d0" stopOpacity="0"/></radialGradient>
  <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur in="SourceAlpha" stdDeviation="12"/><feOffset dy="12"/><feComponentTransfer><feFuncA type="linear" slope=".42"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="soft"><feGaussianBlur stdDeviation="18"/></filter>
  <pattern id="grain" width="90" height="90" patternUnits="userSpaceOnUse"><circle cx="9" cy="18" r="1" fill="#fff" opacity=".12"/><circle cx="61" cy="47" r=".8" fill="#fff" opacity=".1"/><circle cx="35" cy="78" r=".7" fill="#fff" opacity=".08"/></pattern>
</defs>;

export function Backdrop({palette,f}:{palette:string;f:number}) {
  return <g><rect width="720" height="1280" fill={`url(#bg-${palette})`}/><ellipse cx={360+wave(f,.012,25)} cy="480" rx="320" ry="260" fill="url(#glow)" opacity=".38"/><rect width="720" height="1280" fill="url(#grain)"/>{Array.from({length:22},(_,i)=><circle key={i} cx={seeded(i)*720} cy={(seeded(i+38)*1280+f*(.18+i%4*.08))%1280} r={1+seeded(i+72)*2.5} fill="#fff3d1" opacity={.12+seeded(i+8)*.3}/>)}</g>;
}

export function Label({x,y,text,color='#fff4d8',size=20}:{x:number;y:number;text:string;color?:string;size?:number}) {
  return <text x={x} y={y} textAnchor="middle" fill={color} fontSize={size} fontWeight="800" letterSpacing="2.5" style={{paintOrder:'stroke',stroke:'rgba(24,18,38,.5)',strokeWidth:5}}>{text}</text>;
}

function Brain({f}:{f:number}) {
  return <g filter="url(#shadow)" transform={`translate(0 ${wave(f,.08,3)})`}>
    <path d="M-125 33Q-151 2-126-26Q-143-66-101-77Q-91-119-47-108Q-15-143 14-112Q58-138 77-103Q126-109 128-68Q164-37 134-5Q155 34 123 55Q115 99 72 92Q43 125 5 97Q-35 124-65 92Q-111 104-113 67Q-148 57-125 33Z" fill="#e1a9cb" stroke="#ffe6db" strokeWidth="8"/>
    <path d="M-7-111Q-13-57-4-14Q-12 34-2 101M-105-68Q-64-58-76-27Q-91-5-60 6M79-96Q43-69 69-45Q98-29 75-6M-96 59Q-61 33-42 62M91 49Q57 24 39 56" fill="none" stroke="#a85383" strokeWidth="9" strokeLinecap="round" opacity=".8"/>
    <ellipse cx="-38" cy="5" rx="7" ry="11" fill="#292239"/><ellipse cx="39" cy="5" rx="7" ry="11" fill="#292239"/><path d="M-21 42Q0 55 22 40" fill="none" stroke="#743b62" strokeWidth="5" strokeLinecap="round"/>
  </g>;
}

function Character({f,mood='calm'}:{f:number;mood?:string}) {
  const blink=(f%137<4)||(f%193>=99&&f%193<102), eye=blink?2:10;
  const torso=wave(f,.075,5), sway=wave(f,.035,3);
  const shoulder={x:305,y:760+torso}, hand={x:450+wave(f,.045,13),y:670+wave(f,.06,10)};
  const elbow=joint(shoulder,hand,102,96,-1);
  return <g transform={`translate(${sway} 0)`}>
    <ellipse cx="352" cy="1050" rx="143" ry="28" fill="#100e24" opacity=".42" filter="url(#soft)"/>
    <path d="M258 1050Q270 921 285 797Q316 758 361 763Q416 770 435 811L459 1050Z" fill="url(#coat)" stroke="#c8fff0" strokeWidth="5" filter="url(#shadow)"/>
    <path d="M326 775L359 840L392 777" fill="#fff0d6" opacity=".84"/><path d="M360 842L370 1027" stroke="#e3fff4" strokeWidth="4" opacity=".55"/>
    <path d={`M302 ${790+torso}L${elbow.x} ${elbow.y}L${hand.x} ${hand.y}`} fill="none" stroke="url(#skin)" strokeWidth="30" strokeLinecap="round" strokeLinejoin="round"/>
    <circle cx={elbow.x} cy={elbow.y} r="14" fill="#e4a17b"/><path d={`M${hand.x-4} ${hand.y}q19-18 34-4q-6 10-18 10q13 3 16 14q-16 6-29-8`} fill="url(#skin)" stroke="#f7c19a" strokeWidth="3"/>
    <path d="M340 741L339 787Q360 808 383 785L379 738Z" fill="url(#skin)"/>
    <ellipse cx="360" cy="665" rx="88" ry="111" fill="url(#skin)" stroke="#ffe0bb" strokeWidth="5" filter="url(#shadow)"/>
    <path d={`M276 662Q258 545 336 535Q361 500 396 531Q463 545 446 665Q430 604 402 586Q367 620 294 596Z`} fill="url(#hair)" stroke="#76515b" strokeWidth="5"/>
    <path d={`M289 606Q274 ${570+wave(f,.04,5,1)} 292 541Q305 518 323 528`} fill="none" stroke="#513746" strokeWidth="16" strokeLinecap="round"/><path d={`M432 601Q449 ${561+wave(f,.04,6,2)} 429 535`} fill="none" stroke="#342638" strokeWidth="19" strokeLinecap="round"/>
    <ellipse cx="329" cy="667" rx="8" ry={eye} fill="#302339"/><ellipse cx="391" cy="667" rx="8" ry={eye} fill="#302339"/><circle cx="331" cy="664" r="2.5" fill="white"/><circle cx="393" cy="664" r="2.5" fill="white"/>
    <path d={mood==='worry'?'M344 714Q360 704 377 714':'M344 710Q360 723 378 709'} fill="none" stroke="#8a4655" strokeWidth="5" strokeLinecap="round"/>
    <circle cx="308" cy="698" r="13" fill="#ef887b" opacity=".28"/><circle cx="411" cy="698" r="13" fill="#ef887b" opacity=".28"/>
  </g>;
}

function Coffee({f}:{f:number}) {
  return <g transform={`translate(0 ${wave(f,.08,5)})`} filter="url(#shadow)">
    <ellipse cx="360" cy="846" rx="111" ry="26" fill="#211529" opacity=".35"/>
    <path d="M282 692Q294 677 426 692L411 816Q405 838 355 839Q304 837 297 815Z" fill="#f1e4d3" stroke="#fff5e8" strokeWidth="7"/>
    <ellipse cx="354" cy="694" rx="74" ry="17" fill="#7c3a35" stroke="#fff5e8" strokeWidth="6"/><ellipse cx="354" cy="693" rx="58" ry="11" fill="#351b2b"/>
    <path d="M422 721Q487 707 481 760Q475 798 415 783" fill="none" stroke="#f7e8d9" strokeWidth="17"/><path d="M422 731Q463 723 459 759Q456 777 418 773" fill="none" stroke="#9a6660" strokeWidth="6"/>
    <path d={`M325 653Q${310+wave(f,.04,10)} 620 331 602`} fill="none" stroke="#fff1d0" strokeWidth="8" strokeLinecap="round" opacity=".55"/><path d={`M372 652Q${388+wave(f,.04,8,2)} 620 370 599`} fill="none" stroke="#fff1d0" strokeWidth="7" strokeLinecap="round" opacity=".43"/>
  </g>;
}

function Molecule({f}:{f:number}) {
  return <g transform="translate(360 687)" filter="url(#shadow)">
    <circle r="145" fill="url(#glow)" opacity=".7"/>
    {Array.from({length:6},(_,i)=>{const a=i*Math.PI/3+wave(f,.018,.12),x=Math.cos(a)*111,y=Math.sin(a)*111;return <g key={i}><path d={`M0 0L${x} ${y}`} stroke="#9af9e9" strokeWidth="11" opacity=".74"/><circle cx={x} cy={y} r="29" fill="url(#gold)" stroke="#fff2c7" strokeWidth="5"/></g>;})}
    <circle r="58" fill="url(#coat)" stroke="#c7fff1" strokeWidth="7"/><text y="12" textAnchor="middle" fill="#123b50" fontSize="29" fontWeight="900">C₈H₁₀N₄O₂</text>
  </g>;
}

function Receptor({f}:{f:number}) {
  const drift=wave(f,.04,12);
  return <g transform="translate(360 700)" filter="url(#shadow)">
    <path d="M-185 132Q-161 61-177 4Q-184-63-129-72Q-91-73-72-42Q-54-7-35-45Q-8-88 31-67Q68-50 61-5Q49 31 83 28Q129 20 149 58Q171 102 144 137Z" fill="url(#coat)" stroke="#d0fff0" strokeWidth="8"/>
    <path d="M-16-141L0-183L16-141L61-150L43-111L69-79L26-78L0-43L-26-78L-69-79L-43-111L-61-150Z" transform={`translate(${drift} 0) rotate(${wave(f,.02,5)})`} fill="url(#gold)" stroke="#fff0bf" strokeWidth="6"/>
    <path d="M-48-13Q0-43 48-13" fill="none" stroke="#185d67" strokeWidth="9" strokeLinecap="round"/>
  </g>;
}

function Clock({f}:{f:number}) {
  return <g transform="translate(360 695)" filter="url(#shadow)">
    <circle r="139" fill="#182c48" stroke="#e9d7a1" strokeWidth="13"/><circle r="118" fill="none" stroke="#afdfd2" strokeWidth="3" strokeDasharray="3 17"/>
    {Array.from({length:12},(_,i)=><path key={i} d="M0-111v14" transform={`rotate(${i*30})`} stroke="#fff0bd" strokeWidth="5"/>)}
    <path d={`M0 0L${75*Math.sin(f*.006)} ${-78*Math.cos(f*.006)}`} stroke="#ffcd66" strokeWidth="8" strokeLinecap="round"/><path d="M0 0L62 48" stroke="#84eadc" strokeWidth="8" strokeLinecap="round"/><circle r="11" fill="#fff1bd"/>
  </g>;
}

function Waveform({f}:{f:number}) {
  const points=Array.from({length:53},(_,i)=>`${i*14},${120+Math.sin(i*.49+f*.09)*34+Math.sin(i*.17-f*.04)*12}`).join(' ');
  return <g transform="translate(0 655)" filter="url(#shadow)"><path d="M42 122Q360 35 678 122V237Q360 324 42 237Z" fill="#151c37" stroke="#94f3dd" strokeWidth="6" opacity=".95"/><polyline points={points} fill="none" stroke="url(#gold)" strokeWidth="9" strokeLinecap="round" strokeLinejoin="round"/><circle cx="360" cy="178" r="120" fill="none" stroke="#fff0b6" strokeWidth="3" strokeDasharray="5 13" opacity=".6"/></g>;
}

function SunMoon({f}:{f:number}) {
  return <g transform="translate(360 690)" filter="url(#shadow)"><circle cx="-90" cy="-12" r="95" fill="url(#gold)"/><path d="M47-104A105 105 0 1 0 123 49A86 86 0 0 1 47-104Z" fill="#a5deef" stroke="#e5fbff" strokeWidth="6"/><path d={`M-178 125Q0 ${105+wave(f,.04,10)} 176 125`} fill="none" stroke="#d0f5de" strokeWidth="8"/><circle cx="-118" cy="-43" r="6" fill="#885235"/><circle cx="-62" cy="-43" r="6" fill="#885235"/></g>;
}

function Graphic({kind,f}:{kind:string;f:number}) {
  switch(kind){
    case 'brain': return <><g transform="translate(0 60) scale(.72)"><Brain f={f}/></g><g transform="translate(-174 192) scale(.34)"><Character f={f}/></g></>;
    case 'cup': return <Coffee f={f}/>;
    case 'molecule': return <Molecule f={f}/>;
    case 'receptor': return <Receptor f={f}/>;
    case 'clock': return <Clock f={f}/>;
    case 'wave': return <Waveform f={f}/>;
    case 'cycle': return <><SunMoon f={f}/><g transform="translate(0 250) scale(.48)"><Clock f={f}/></g></>;
    case 'character': return <Character f={f}/>;
    case 'hook': return <><g transform="translate(0 75) scale(.72)"><Brain f={f}/></g><g transform="translate(142 214) scale(.57)"><Character f={f} mood="worry"/></g><path d="M-145-160Q-96-218-43-177" fill="none" stroke="#ffe18e" strokeWidth="7" strokeLinecap="round"/></>;
    default: return <g/>;
  }
}

export function SceneArt({kind,f,mood}:{kind:string;f:number;mood?:string}) {
  const float=wave(f,.035,3);
  return <g transform={`translate(0 ${float})`}><Graphic kind={kind} f={f} /></g>;
}
