import React from 'react';

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const wave = (f: number, speed = .06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
export const seeded = (n: number) => { const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; return a - Math.floor(a); };
type Point = {x: number; y: number};

export const ArtDefs = () => <defs>
  <radialGradient id="bg-purple" cx="42%" cy="34%" r="80%"><stop stopColor="#6342a4"/><stop offset=".5" stopColor="#34205f"/><stop offset="1" stopColor="#160e35"/></radialGradient>
  <radialGradient id="bg-teal" cx="48%" cy="30%" r="80%"><stop stopColor="#2caead"/><stop offset=".55" stopColor="#116476"/><stop offset="1" stopColor="#112c52"/></radialGradient>
  <radialGradient id="bg-gold" cx="50%" cy="45%" r="65%"><stop stopColor="#fffab0"/><stop offset=".42" stopColor="#ffe35f"/><stop offset="1" stopColor="#f4a72c"/></radialGradient>
  <linearGradient id="skin" x1="0" x2="1" y2=".5"><stop stopColor="#e9a05d"/><stop offset=".5" stopColor="#c97943"/><stop offset="1" stopColor="#b55b38"/></linearGradient>
  <linearGradient id="skin-face" x1=".1" y1="0" x2=".8" y2="1"><stop stopColor="#e9a363"/><stop offset="1" stopColor="#c16a42"/></linearGradient>
  <linearGradient id="hair" x1="0" x2=".9" y2="1"><stop stopColor="#492344"/><stop offset=".5" stopColor="#301c35"/><stop offset="1" stopColor="#20162c"/></linearGradient>
  <linearGradient id="shirt" x1="0" x2="1" y2=".5"><stop stopColor="#36d5aa"/><stop offset=".6" stopColor="#16bb91"/><stop offset="1" stopColor="#119a80"/></linearGradient>
  <linearGradient id="cyan" x1="0" x2="1" y2="1"><stop stopColor="#85f9ee"/><stop offset=".5" stopColor="#31d1e5"/><stop offset="1" stopColor="#1a9cca"/></linearGradient>
  <linearGradient id="pink" x1="0" x2=".8" y2="1"><stop stopColor="#ff9cdb"/><stop offset=".5" stopColor="#f45aae"/><stop offset="1" stopColor="#c63189"/></linearGradient>
  <linearGradient id="key-orange" x1="0" x2="0" y2="1"><stop stopColor="#ffd56d"/><stop offset=".5" stopColor="#ffaf34"/><stop offset="1" stopColor="#ed7a29"/></linearGradient>
  <linearGradient id="key-purple" x1="0" x2=".5" y2="1"><stop stopColor="#ddacff"/><stop offset=".5" stopColor="#b97cf1"/><stop offset="1" stopColor="#8458d3"/></linearGradient>
  <radialGradient id="aura"><stop stopColor="#65f4ef" stopOpacity=".55"/><stop offset=".55" stopColor="#65f4ef" stopOpacity=".15"/><stop offset="1" stopColor="#65f4ef" stopOpacity="0"/></radialGradient>
  <radialGradient id="warm-aura"><stop stopColor="#fff7ac" stopOpacity=".8"/><stop offset=".5" stopColor="#ffd959" stopOpacity=".3"/><stop offset="1" stopColor="#ffd959" stopOpacity="0"/></radialGradient>
  <filter id="soft-glow" x="-75%" y="-75%" width="250%" height="250%"><feGaussianBlur stdDeviation="7"/></filter>
  <filter id="drop" x="-30%" y="-30%" width="160%" height="175%"><feDropShadow dx="0" dy="13" stdDeviation="10" floodColor="#120825" floodOpacity=".23"/></filter>
  <filter id="small-drop" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="6" stdDeviation="4" floodColor="#170929" floodOpacity=".22"/></filter>
  <pattern id="dust" width="83" height="83" patternUnits="userSpaceOnUse"><circle cx="8" cy="12" r=".8" fill="white" opacity=".12"/><circle cx="41" cy="62" r=".7" fill="white" opacity=".09"/></pattern>
</defs>;

export function Spark({x, y, size = 12, opacity = 1, color = '#fff8d9'}: {x: number; y: number; size?: number; opacity?: number; color?: string}) {
  return <path d={`M ${x} ${y-size} Q ${x+2} ${y-2} ${x+size} ${y} Q ${x+2} ${y+2} ${x} ${y+size} Q ${x-2} ${y+2} ${x-size} ${y} Q ${x-2} ${y-2} ${x} ${y-size}`} fill={color} opacity={opacity}/>;
}

export function Backdrop({palette, f}: {palette: string; f: number}) {
  const gold = palette === 'gold';
  return <g>
    <rect width="720" height="1280" fill={`url(#bg-${palette})`}/>
    {gold ? <>
      {Array.from({length: 14}, (_, i) => {
        const y = i * 108 - 110 + wave(f, .018, 14, i);
        return <path key={i} d={`M -90 ${y} C ${130+wave(f,.012,60,i)} ${y-140} 310 ${y+210} 430 ${y+90} S 650 ${y-90} 820 ${y+120}`} stroke={i%2 ? '#ef8527' : '#ffc34c'} strokeWidth={18+i%4*7} opacity=".3" fill="none"/>;
      })}
      <ellipse cx="360" cy="660" rx="350" ry="530" fill="url(#warm-aura)"/>
    </> : <>
      {Array.from({length: 17}, (_, i) => {
        const x = seeded(i+11)*850-80, y=seeded(i+31)*1500-100;
        return <path key={i} transform={`translate(${x + wave(f,.012,12,i)} ${y+wave(f,.009,18,i+2)}) rotate(${i*31+wave(f,.008,8)})`} d="M-100-60 Q-130 0-73 82 Q0 130 81 59 Q130-18 42-88 Q-35-130-100-60" fill={i%2?'#b69bff':'#83c7da'} opacity={palette==='teal'?.035:.045} />;
      })}
      {palette === 'teal' && Array.from({length:9},(_,i)=><path key={i} d={`M-80 ${360+i*120} Q280 ${220+i*130} 800 ${500+i*90}`} fill="none" stroke="#6deedb" opacity=".05" strokeWidth="2"/>)}
    </>}
    {Array.from({length: 35}, (_, i) => {
      const x=seeded(i+80)*720, y=(seeded(i+140)*1400-f*(.1+seeded(i)*.3)+14000)%1400-60;
      return gold && i%3===0 ? <Spark key={i} x={x} y={y} size={4+seeded(i)*8} opacity={.2+Math.abs(wave(f,.03,.45,i))}/> : <circle key={i} cx={x} cy={y} r={1+seeded(i)*3.5} fill={gold?'#fff8be':'#bef3fc'} opacity={.08+seeded(i)*.15}/>;
    })}
    <rect width="720" height="1280" fill="url(#dust)"/>
  </g>;
}

export function Label({x, y, text, color = '#effdff', size = 23}: {x: number; y: number; text: string; color?: string; size?: number}) {
  const w = text.length * size * .54 + 30;
  return <g transform={`translate(${x} ${y})`}><rect x={-w/2} y={-size-7} width={w} height={size+20} rx="10" fill="#1b173a" opacity=".85"/><text textAnchor="middle" fill={color} fontSize={size} fontWeight="750">{text}</text></g>;
}

export function Face({f, mood = 'happy', scale = 1}: {f: number; mood?: 'happy'|'pain'|'sleep'|'worry'|'dead'; scale?: number}) {
  const blink = f%133 > 125 ? clamp(Math.abs(f%133-129)/4) : 1;
  const closed = mood==='sleep'||mood==='dead';
  return <g transform={`scale(${scale})`}>
    {[-1,1].map(side=><g key={side} transform={`translate(${side*25} 0)`}>
      {closed ? <path d="M-11-2 Q0 9 11-2" stroke="#32223d" strokeWidth="5" strokeLinecap="round" fill="none"/> : <g transform={`scale(1 ${Math.max(.06,blink)})`}>
        <ellipse rx="12" ry="15" fill="#fffbed"/>
        <ellipse cx={side===-1?2:0} cy="2" rx="7" ry="10" fill="#30243c"/>
        <circle cx="-2" cy="-3" r="3" fill="white"/>
      </g>}
      <path d={mood==='pain'?'M-12-27 Q0-25 13-16':mood==='worry'?'M-12-18 Q0-26 13-27':'M-12-24 Q0-30 12-25'} transform={side===1?'scale(-1 1)':undefined} stroke="#3b223e" strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      <ellipse cy="22" cx={side*6} rx="11" ry="6" fill="#ef7899" opacity=".45"/>
    </g>)}
    {mood==='dead' ? <path d="M-8 34 H8" stroke="#514064" strokeWidth="4" strokeLinecap="round"/> : mood==='pain'||mood==='worry' ? <path d="M-10 34 Q0 22 10 34" fill="none" stroke="#5c2941" strokeWidth="4" strokeLinecap="round"/> : <>
      <path d="M-16 28 Q0 42 16 28 Q12 52 0 51 Q-13 50-16 28" fill="#682a4b"/>
      <path d="M-9 44 Q0 38 9 44 Q0 54-9 44" fill="#f27b9c"/>
    </>}
  </g>;
}

function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx=b.x-a.x, dy=b.y-a.y;
  const d=clamp(Math.hypot(dx,dy),1,l1+l2-.01);
  const angle=Math.atan2(dy,dx)+bend*Math.acos(clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1));
  return {x:a.x+Math.cos(angle)*l1,y:a.y+Math.sin(angle)*l1};
}

export function Person({f, pose = 'idle', scale = 1, x = 360, y = 760, opacity = 1}: {f:number;pose?:'idle'|'pain'|'float'|'faint'|'relief';scale?:number;x?:number;y?:number;opacity?:number}) {
  const floating = pose==='float', faint=pose==='faint', hurt=pose==='pain';
  const bob=wave(f,.055,floating?16:3), sway=wave(f,.032,floating?3:1.4);
  const breathe=wave(f,.075,.009);
  const handL={x:floating?-188+wave(f,.065,15):hurt?-10:-97+wave(f,.05,4),y:floating?-280+wave(f,.065,11):hurt?130:113};
  const handR={x:floating?175+wave(f,.065,13,1):hurt?5:101+wave(f,.05,4,2),y:floating?-294+wave(f,.065,13,1):hurt?128:110};
  const footL={x:floating?-73+wave(f,.06,19):-57,y:floating?300+wave(f,.06,12):333};
  const footR={x:floating?141+wave(f,.06,19,1):52,y:floating?250+wave(f,.06,15,1):333};
  const skin='#ce804a';
  function arm(side: number, end: Point) {
    const a={x:side*65,y:-102}, b=joint(a,end,115,120,side);
    return <g>
      <path d={`M${a.x} ${a.y} Q${b.x} ${b.y} ${b.x} ${b.y} L${end.x} ${end.y}`} stroke="#a85636" strokeWidth="34" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <path d={`M${a.x-3} ${a.y-3} L${b.x-3} ${b.y-3} L${end.x-3} ${end.y-3}`} stroke={skin} strokeWidth="28" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <ellipse cx={end.x} cy={end.y-3} rx="18" ry="22" fill={skin}/>
      <path d={`M${end.x-8} ${end.y-9} l1-10 m7 9 1-10 m6 11 1-9`} stroke="#a95f3b" strokeWidth="2" strokeLinecap="round" fill="none"/>
      <circle cx={b.x-3} cy={b.y-3} r="7" fill="#e8a36b" opacity=".32"/>
    </g>;
  }
  function leg(side: number, end: Point) {
    const hip={x:side*37,y:80}, knee=joint(hip,end,132,128,side);
    return <g>
      <path d={`M${hip.x} ${hip.y} L${knee.x} ${knee.y} L${end.x} ${end.y-19}`} stroke="#a95936" strokeWidth="40" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d={`M${hip.x-4} ${hip.y} L${knee.x-4} ${knee.y} L${end.x-4} ${end.y-19}`} stroke="#d98d4c" strokeWidth="30" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <ellipse cx={knee.x-4} cy={knee.y} rx="12" ry="8" fill="#efb16f" opacity=".48"/>
      <g transform={`translate(${end.x} ${end.y}) rotate(${floating?side*12:side*5})`}>
        <path d="M-19-43 L19-43 20-6-20-6Z" fill="#fff8dd"/>
        <path d="M-19-35 H19 M-19-25 H19" stroke="#27bba1" strokeWidth="5"/>
        <path d="M-21-11 Q-6-22 16-11 L28 10 Q33 27 13 32 L-18 29 Q-29 18-21-11" fill="#6e4fd3"/>
        <path d="M-21-9 Q-5-17 10-6 L14 16 Q-7 27-22 14Z" fill="#9c79ed"/>
        <path d="M-24 19 Q0 33 27 20 L26 29 Q0 40-22 29Z" fill="#d6c6ff"/>
        <path d="M-12-6 L7-5 M-12 2 L9 3 M-11 10 L10 11" fill="none" stroke="#e8dbff" strokeWidth="3" strokeLinecap="round"/>
      </g>
    </g>;
  }
  return <g opacity={opacity} transform={`translate(${x} ${y+bob}) rotate(${faint?30+sway:sway}) scale(${scale})`}>
    {/* Independent locks trail the head with a delayed phase. */}
    <g fill="url(#hair)">
      <path d="M-73-239 Q-115-200-107-95 Q-125-43-86-25 L88-26 Q121-43 103-107 Q109-220 62-251Z"/>
      {floating&&Array.from({length:7},(_,i)=><path key={i} d={`M${(i-3)*21} -208 Q${(i-3)*48} -300 ${(i-3)*50+wave(f-8,.065,18,i)} ${-395+Math.abs(i-3)*22} Q${(i-3)*58+wave(f-8,.065,18,i)} ${-435+Math.abs(i-3)*24} ${(i-3)*68-22} ${-395+Math.abs(i-3)*18} Q${(i-3)*35-25} -275 ${(i-3)*24-24} -208Z`}/>)}
    </g>
    {arm(-1,handL)}{arm(1,handR)}
    {leg(-1,footL)}{leg(1,footR)}
    <g transform={`scale(1 ${1+breathe})`}>
      <path d="M-48-127 Q-67-122-85-108 L-94-72 Q-76-58-60-68 L-59 59 Q0 83 61 56 L59-69 Q78-58 95-78 L81-110 Q63-123 46-128Z" fill="url(#shirt)"/>
      <path d="M-47-117 Q-24-96-27-29 L-29 38" stroke="#72e8c6" strokeWidth="17" opacity=".45" fill="none" strokeLinecap="round"/>
      <path d="M55-93 Q42-36 52 51" fill="none" stroke="#0b987d" strokeWidth="6" opacity=".5"/>
      <path d="M-55 57 Q0 74 58 56 L61 105 Q35 122 6 107 L0 96-6 108 Q-34 119-58 106Z" fill="#363e9b"/>
      <path d="M-55 57 Q0 72 58 56" stroke="#ff7465" strokeWidth="10" fill="none"/>
      <path d="M-53 98 L-13 104 M16 103 55 97" stroke="#6169ce" strokeWidth="5"/>
      <path d="M-20-162 L-20-125 Q0-103 22-125 L22-163Z" fill="url(#skin)"/>
    </g>
    <g transform={`translate(0 -219) rotate(${wave(f-6,.04,floating?4:1.6)})`}>
      <ellipse cx="-69" cy="5" rx="16" ry="22" fill="#b56942"/>
      <ellipse cx="69" cy="5" rx="16" ry="22" fill="#b56942"/>
      <path d="M-70-31 Q-67-83 0-83 Q68-83 72-29 L65 22 Q56 76 0 83 Q-58 74-66 23Z" fill="url(#skin-face)"/>
      <path d="M-72-9 Q-94-66-42-92 Q10-121 61-81 Q86-60 74-10 Q43-37 33-67 Q-17-29-72-9" fill="url(#hair)"/>
      <path d="M-61-57 Q-22-100 28-84" stroke="#67415c" strokeWidth="8" opacity=".5" fill="none" strokeLinecap="round"/>
      <Face f={f} mood={faint?'sleep':floating?'sleep':hurt?'pain':pose==='relief'?'happy':'worry'} scale={1.1}/>
      <path d="M-2 13 Q-8 28 5 24" stroke="#a95539" strokeWidth="3" fill="none" strokeLinecap="round"/>
    </g>
    {hurt&&<g transform="translate(58 216)"><circle r={38+wave(f,.11,7)} fill="#ff4d96" opacity=".16"/><path d="M-27-26-39-40 M15-35 19-53 M34-7 53-13 M22 26 36 40" stroke="#ff80bc" strokeWidth="4" fill="none" strokeLinecap="round"/></g>}
  </g>;
}

export function Pain({f, x=0,y=0,scale=1,opacity=1}: {f:number;x?:number;y?:number;scale?:number;opacity?:number}) {
  const points=Array.from({length:24},(_,i)=>{const a=i/24*Math.PI*2-Math.PI/2,r=i%2?65:92;return `${Math.cos(a)*r},${Math.sin(a)*r}`;}).join(' ');
  return <g transform={`translate(${x} ${y}) rotate(${wave(f,.06,3)}) scale(${scale})`} opacity={opacity}>
    <polygon points={points} fill="#087fae" transform="translate(5 10)"/>
    <polygon points={points} fill="url(#cyan)"/>
    <path d="M-53-33 Q-28-60-9-49" stroke="#c6fffa" strokeWidth="8" fill="none" strokeLinecap="round" opacity=".5"/>
    <Face f={f} mood="pain" scale={.9}/>
  </g>;
}

export function Joy({f, x=0,y=0,scale=1}: {f:number;x?:number;y?:number;scale?:number}) {
  return <g transform={`translate(${x} ${y}) scale(${scale})`}>
    <circle r="87" fill="#dc772b" cy="7"/><circle r="84" fill="url(#key-orange)"/>
    <circle r="68" fill="none" stroke="#ffd77b" strokeWidth="4" opacity=".5"/>
    <ellipse cx="-32" cy="-39" rx="23" ry="18" fill="#fff6bc" opacity=".5" transform="rotate(-20)"/>
    <Face f={f} mood="sleep" scale={.9}/>
  </g>;
}

export function Key({x=0,y=0,scale=1,angle=0,color='purple',face=false,f=0}: {x?:number;y?:number;scale?:number;angle?:number;color?:'purple'|'orange'|'cyan';face?:boolean;f?:number}) {
  const fill=color==='cyan'?'url(#cyan)':`url(#key-${color})`;
  const shape='M30-16 H-112 V-42 H-89 V-16 H-65 V-36 H-43 V-16 H-20 V-37 H2 V-16 H30 A48 48 0 1 1 30 16 H-112 V-16Z';
  return <g transform={`translate(${x} ${y}) rotate(${angle}) scale(${scale})`}>
    <path d={shape} fill={color==='cyan'?'#1487b0':color==='orange'?'#c86426':'#7151ac'} transform="translate(0 7)"/>
    <path d={shape} fill={fill}/>
    <path d="M-107-12 H31" fill="none" stroke="white" opacity=".45" strokeWidth="5" strokeLinecap="round"/>
    {face?<g transform="translate(74 -2)"><Face f={f} scale={.47} mood="happy"/></g>:<><circle cx="74" r="20" fill={color==='cyan'?'#225b87':'#6f42a0'}/><path d="M62-14 Q74-24 88-12" stroke="#f8e6ff" opacity=".6" strokeWidth="4" fill="none"/></>}
  </g>;
}

export function Receptor({x=0,y=0,scale=1,active=0}: {x?:number;y?:number;scale?:number;active?:number}) {
  return <g transform={`translate(${x} ${y}) scale(${scale})`}>
    {active>0&&<circle r="180" fill="url(#aura)" opacity={active}/>}
    <circle cx="10" cy="18" r="108" fill="#176d87"/>
    <circle r="108" fill="url(#cyan)"/>
    <path d="M-86 48 Q-25 111 61 69" fill="none" stroke="#0b95b9" strokeWidth="12" opacity=".5"/>
    <ellipse cx="-42" cy="-54" rx="27" ry="20" fill="#ccfff4" opacity=".35" transform="rotate(-15)"/>
    <path d="M-18-24 A32 32 0 1 0-18 24 H54 Q64 24 64 14 V-14 Q64-24 54-24Z" fill="#124466"/>
    <path d="M-20-26 H53" fill="none" stroke="#b6fff9" strokeWidth="3" opacity=".65"/>
    {active>0&&<path d="M-18-24 A32 32 0 1 0-18 24 H54 Q64 24 64 14 V-14 Q64-24 54-24Z" fill="#fff284" opacity={active*.85}/>}
  </g>;
}

export function Brain({f, x=0,y=0,scale=1,stopped=false}: {f:number;x?:number;y?:number;scale?:number;stopped?:boolean}) {
  return <g transform={`translate(${x} ${y}) scale(${scale})`}>
    <path d="M-91 35 Q-115 17-100-13 Q-110-42-83-54 Q-80-82-51-78 Q-27-104 0-86 Q26-104 50-79 Q81-85 85-55 Q113-47 103-17 Q120 11 99 33 Q104 59 78 65 Q53 88 29 68 Q0 87-25 68 Q-56 88-76 64 Q-105 63-91 35Z" fill={stopped?'#8e89ba':'#c73083'} transform="translate(0 7)"/>
    <path d="M-91 35 Q-115 17-100-13 Q-110-42-83-54 Q-80-82-51-78 Q-27-104 0-86 Q26-104 50-79 Q81-85 85-55 Q113-47 103-17 Q120 11 99 33 Q104 59 78 65 Q53 88 29 68 Q0 87-25 68 Q-56 88-76 64 Q-105 63-91 35Z" fill={stopped?'#a8a6ce':'url(#pink)'}/>
    <g stroke={stopped?'#807da9':'#cf458e'} strokeWidth="5" fill="none" strokeLinecap="round">
      <path d="M0-77 Q-9-42 0-20 M-17-67 Q-42-78-45-48 Q-62-60-71-36 M-76-19 Q-57-26-57-7 M22-74 Q45-65 36-41 Q62-51 71-28 M80-7 Q64-16 62 3"/>
    </g>
    <path d="M-84-40 Q-75-59-58-58 M-39-73 Q-26-85-16-76" stroke="#ffc0e1" strokeWidth="7" fill="none" strokeLinecap="round" opacity=".6"/>
    <g transform="translate(0 12)"><Face f={f} mood={stopped?'dead':'happy'} scale={1.05}/></g>
  </g>;
}

export function Lungs({f,x=360,y=840,scale=1,slow=0}: {f:number;x?:number;y?:number;scale?:number;slow?:number}) {
  const stopped=slow>.95;
  const breath=stopped?0:Math.sin(f*.065*(1-slow*.65))*.037*(1-slow);
  return <g transform={`translate(${x} ${y}) scale(${scale})`}>
    <g stroke="#a58bd7" strokeWidth="6" opacity=".12" fill="none">{[0,1,2,3].map(i=><path key={i} d={`M-220 ${-140+i*60} Q0 ${-290+i*60} 220 ${-140+i*60}`}/>)}</g>
    <path d="M0-265 V-103 Q0-60-62-28 M0-103 Q0-60 62-28" fill="none" stroke={stopped?'#8b88b3':'#e9bc66'} strokeWidth="24" strokeLinecap="round"/>
    <path d="M-4-265 V-106" stroke={stopped?'#a5a1c4':'#ffe29c'} strokeWidth="8" strokeLinecap="round"/>
    {[-1,1].map(side=><g key={side} transform={`translate(${side*95} 0) scale(${side*(1+breath)} ${1+breath*.7})`}>
      <path d="M-54-126 Q-38-190 20-154 Q80-115 101 29 Q119 150 31 155 Q-54 151-55 94Z" fill={stopped?'#77769a':'#ad246b'} transform="translate(0 8)"/>
      <path d="M-54-126 Q-38-190 20-154 Q80-115 101 29 Q119 150 31 155 Q-54 151-55 94Z" fill={stopped?'#a09cc2':'url(#pink)'}/>
      <path d="M-51 79 Q27 136 99 63 L94 106 Q73 160 26 155 Q-55 153-51 79" fill={stopped?'#817da7':'#d4358d'} opacity=".7"/>
      <ellipse cx="14" cy="-91" rx="23" ry="30" fill="white" opacity=".2" transform="rotate(-15)"/>
      <g transform={`translate(6 2) scale(${side*.9} .9)`}><Face f={f} mood={stopped?'dead':slow>.4?'worry':'happy'}/></g>
    </g>)}
  </g>;
}

export function Cup({f}: {f:number}) {
  return <g transform={`translate(360 ${685+wave(f,.04,9)}) rotate(${wave(f,.04,3)})`}>
    <ellipse cy="220" rx="135" ry="21" fill="#d77f35" opacity=".2"/>
    <path d="M100-15 Q198-43 174 63 Q160 103 110 84" stroke="#bc3579" strokeWidth="28" fill="none"/>
    <path d="M-127-51 Q-122 158-12 184 Q100 205 129-51Z" fill="#c82f7c"/>
    <path d="M-112-41 Q-97 134-14 160 Q58 179 96-44Z" fill="#f264a6"/>
    <ellipse cy="-50" rx="129" ry="30" fill="#b77549"/>
    <ellipse cy="-54" rx="120" ry="23" fill="#56302b"/>
    <path d="M-82 0 Q-78 61-57 85" stroke="#ff9dcc" strokeWidth="17" fill="none" opacity=".65" strokeLinecap="round"/>
    {[-1,0,1].map((i)=><path key={i} d={`M${i*55} -100 C${i*55-40+wave(f,.07,12,i)} -145 ${i*55+40} -164 ${i*55+wave(f,.06,20,i)} -210`} stroke="#fffbe0" strokeWidth="8" fill="none" strokeLinecap="round" opacity={.5+wave(f,.05,.15,i)}/>)}
    <Spark x={35} y={25} size={19} opacity={.7+wave(f,.09,.3)}/>
  </g>;
}

export function Headphones({f}: {f:number}) {
  return <g transform={`translate(360 ${690+wave(f,.08,8)}) rotate(${wave(f,.08,5)})`}>
    <path d="M-145 52 V-36 A145 145 0 0 1 145-36 V52" stroke="#6934c5" strokeWidth="37" fill="none"/>
    <path d="M-145 17 V-36 A145 145 0 0 1 145-36 V17" stroke="#b68bff" strokeWidth="12" fill="none"/>
    {[-1,1].map(side=><g key={side} transform={`translate(${side*137} 45)`}><rect x="-38" y="-57" width="76" height="131" rx="31" fill="#6125b4"/><rect x="-27" y="-53" width="43" height="117" rx="21" fill="#9658f0"/><path d="M-17-28 V23" stroke="#c4a3ff" strokeWidth="7" strokeLinecap="round"/></g>)}
    {[0,1,2,3,4].map(i=><g key={i} transform={`translate(${Math.cos(i*1.4)*220} ${-120+Math.sin(i*1.4)*170-wave(f,.06,12,i)}) rotate(${i*12-20})`} fill="#9a4bd7"><path d="M0 0 V-52 L34-61 V-10 H25 V-47 L9-42 V0Z"/><ellipse cx="-4" cy="2" rx="15" ry="10" transform="rotate(-20)"/><ellipse cx="23" cy="-9" rx="15" ry="10" transform="rotate(-20)"/></g>)}
  </g>;
}
