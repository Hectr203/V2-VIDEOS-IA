import React from 'react';

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const wave = (f: number, speed = 0.06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
export const seeded = (n: number) => { const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; return a - Math.floor(a); };
type Point = { x: number; y: number };

export const ArtDefs = () => <defs>
  {/* Fondos */}
  <radialGradient id="bg-purple" cx="42%" cy="34%" r="80%"><stop stopColor="#583594"/><stop offset=".5" stopColor="#2c1a53"/><stop offset="1" stopColor="#130a2a"/></radialGradient>
  <radialGradient id="bg-teal" cx="48%" cy="30%" r="80%"><stop stopColor="#2caead"/><stop offset=".55" stopColor="#116476"/><stop offset="1" stopColor="#102542"/></radialGradient>
  <radialGradient id="bg-gold" cx="50%" cy="45%" r="65%"><stop stopColor="#fff8b5"/><stop offset=".42" stopColor="#fedb56"/><stop offset="1" stopColor="#f39d24"/></radialGradient>
  {/* Sabores y elementos */}
  <linearGradient id="cream-vanilla" x1="0" x2="0" y2="1"><stop stopColor="#fffdf0"/><stop offset=".6" stopColor="#fffae0"/><stop offset="1" stopColor="#f7ebc1"/></linearGradient>
  <linearGradient id="cream-strawberry" x1="0" x2="0" y2="1"><stop stopColor="#ffb0cf"/><stop offset=".6" stopColor="#fa7ba7"/><stop offset="1" stopColor="#de4a81"/></linearGradient>
  <linearGradient id="cream-chocolate" x1="0" x2="0" y2="1"><stop stopColor="#966046"/><stop offset=".6" stopColor="#693b25"/><stop offset="1" stopColor="#482515"/></linearGradient>
  <linearGradient id="cream-mint" x1="0" x2="0" y2="1"><stop stopColor="#affce1"/><stop offset=".6" stopColor="#5fe8be"/><stop offset="1" stopColor="#2fb38d"/></linearGradient>
  <linearGradient id="cone-waffle" x1="0" x2="1" y2="1"><stop stopColor="#fbd38d"/><stop offset=".5" stopColor="#e29f45"/><stop offset="1" stopColor="#b77322"/></linearGradient>
  <linearGradient id="ice-blue" x1="0" x2="1" y2="1"><stop stopColor="#d2f8ff"/><stop offset=".5" stopColor="#81e4fa"/><stop offset="1" stopColor="#3bb9e2"/></linearGradient>
  {/* Personaje */}
  <linearGradient id="skin" x1="0" x2="1" y2=".5"><stop stopColor="#f6be8a"/><stop offset=".5" stopColor="#e29e62"/><stop offset="1" stopColor="#c57b40"/></linearGradient>
  <linearGradient id="skin-face" x1=".1" y1="0" x2=".8" y2="1"><stop stopColor="#fcd3a5"/><stop offset="1" stopColor="#d9894e"/></linearGradient>
  <linearGradient id="hair" x1="0" x2=".9" y2="1"><stop stopColor="#512c49"/><stop offset=".5" stopColor="#351930"/><stop offset="1" stopColor="#1f0c1c"/></linearGradient>
  <linearGradient id="shirt" x1="0" x2="1" y2=".5"><stop stopColor="#38e2b8"/><stop offset=".6" stopColor="#19be98"/><stop offset="1" stopColor="#109a7a"/></linearGradient>
  {/* Auras y sombras */}
  <radialGradient id="aura"><stop stopColor="#65f4ef" stopOpacity=".55"/><stop offset=".55" stopColor="#65f4ef" stopOpacity=".15"/><stop offset="1" stopColor="#65f4ef" stopOpacity="0"/></radialGradient>
  <radialGradient id="warm-aura"><stop stopColor="#fff8b5" stopOpacity=".8"/><stop offset=".5" stopColor="#fedb56" stopOpacity=".3"/><stop offset="1" stopColor="#fedb56" stopOpacity="0"/></radialGradient>
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
        return <path key={i} transform={`translate(${x + wave(f,.012,12,i)} ${y+wave(f,.009,18,i+2)}) rotate(${i*31+wave(f,.008,8)})`} d="M-100-60 Q-130 0-73 82 Q0 130 81 59 Q130-18 42-88 Q-35-130-100-60" fill={i%2?'#d3b5ff':'#8de5f5'} opacity={palette==='teal'?.04:.05} />;
      })}
    </>}
    {Array.from({length: 32}, (_, i) => {
      const x=seeded(i+80)*720, y=(seeded(i+140)*1400-f*(.12+seeded(i)*.3)+14000)%1400-60;
      return gold && i%3===0 ? <Spark key={i} x={x} y={y} size={4+seeded(i)*8} opacity={.2+Math.abs(wave(f,.03,.45,i))}/> : <circle key={i} cx={x} cy={y} r={1+seeded(i)*3.5} fill={gold?'#fff8be':'#cbf7ff'} opacity={.09+seeded(i)*.16}/>;
    })}
    <rect width="720" height="1280" fill="url(#dust)"/>
  </g>;
}

export function Label({x, y, text, color = '#effdff', size = 23}: {x: number; y: number; text: string; color?: string; size?: number}) {
  const w = text.length * size * .54 + 32;
  return <g transform={`translate(${x} ${y})`}><rect x={-w/2} y={-size-8} width={w} height={size+22} rx="11" fill="#181335" opacity=".88"/><text textAnchor="middle" fill={color} fontSize={size} fontWeight="750">{text}</text></g>;
}

export function Face({f, mood = 'happy', scale = 1}: {f: number; mood?: 'happy'|'pain'|'sleep'|'worry'|'shock'|'lick'; scale?: number}) {
  const blink = f%133 > 125 ? clamp(Math.abs(f%133-129)/4) : 1;
  const closed = mood==='sleep';
  return <g transform={`scale(${scale})`}>
    {[-1,1].map(side=><g key={side} transform={`translate(${side*25} 0)`}>
      {closed ? <path d="M-11-2 Q0 9 11-2" stroke="#32223d" strokeWidth="5" strokeLinecap="round" fill="none"/> : mood==='shock' ? <g>
        <circle r="14" fill="#fffbed"/><circle cx={side*2} cy="0" r="8" fill="#30243c"/><circle cx="-2" cy="-3" r="3" fill="white"/>
      </g> : <g transform={`scale(1 ${Math.max(.06,blink)})`}>
        <ellipse rx="12" ry="15" fill="#fffbed"/>
        <ellipse cx={side===-1?2:0} cy="2" rx="7" ry="10" fill="#30243c"/>
        <circle cx="-2" cy="-3" r="3" fill="white"/>
      </g>}
      <path d={mood==='pain'?'M-12-27 Q0-25 13-16':mood==='worry'?'M-12-18 Q0-26 13-27':mood==='shock'?'M-14-28 Q0-32 14-25':'M-12-24 Q0-30 12-25'} transform={side===1?'scale(-1 1)':undefined} stroke="#3b223e" strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      <ellipse cy="22" cx={side*6} rx="11" ry="6" fill="#ef7899" opacity=".45"/>
    </g>)}
    {mood==='pain' ? <path d="M-12 34 Q0 18 12 34" fill="none" stroke="#5c2941" strokeWidth="4" strokeLinecap="round"/> : mood==='shock' ? <ellipse cy="36" rx="10" ry="14" fill="#682a4b"/> : mood==='lick' ? <g>
      <path d="M-16 28 Q0 42 16 28" stroke="#682a4b" strokeWidth="5" fill="none" strokeLinecap="round"/>
      <path d={`M-8 32 Q0 ${46+wave(f,.15,6)} 8 32 Q0 52-8 32`} fill="#ff769c"/>
    </g> : <>
      <path d="M-16 28 Q0 42 16 28 Q12 52 0 51 Q-13 50-16 28" fill="#682a4b"/>
      <path d="M-9 44 Q0 38 9 44 Q0 54-9 44" fill="#f27b9c"/>
    </>}
  </g>;
}

export function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx=b.x-a.x, dy=b.y-a.y;
  const d=clamp(Math.hypot(dx,dy),1,l1+l2-.01);
  const angle=Math.atan2(dy,dx)+bend*Math.acos(clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1));
  return {x:a.x+Math.cos(angle)*l1,y:a.y+Math.sin(angle)*l1};
}

export function Person({f, pose = 'idle', scale = 1, x = 360, y = 760, opacity = 1}: {f:number;pose?:'idle'|'eat'|'freeze'|'jump'|'cheer';scale?:number;x?:number;y?:number;opacity?:number}) {
  const jumping = pose==='jump'||pose==='cheer', freezing = pose==='freeze', eating=pose==='eat';
  const bob=wave(f,.055,jumping?18:3), sway=wave(f,.032,jumping?3:1.4);
  const shiver=freezing?wave(f,.35,5):0;
  const breathe=wave(f,.075,.009);
  const handL={x:freezing?-55:eating?-40:jumping?-165:-97,y:freezing?-200:eating?-60:jumping?-240:113};
  const handR={x:freezing?55:eating?110:jumping?165:101,y:freezing?-200:eating?-40:jumping?-240:110};
  const footL={x:jumping?-70+wave(f,.06,12):-57,y:jumping?290:333};
  const footR={x:jumping?70+wave(f,.06,12,1):52,y:jumping?290:333};
  const skin='#ce804a';

  function arm(side: number, end: Point) {
    const a={x:side*65,y:-102}, b=joint(a,end,115,120,side);
    return <g>
      <path d={`M${a.x} ${a.y} Q${b.x} ${b.y} ${b.x} ${b.y} L${end.x} ${end.y}`} stroke="#a85636" strokeWidth="34" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <path d={`M${a.x-3} ${a.y-3} L${b.x-3} ${b.y-3} L${end.x-3} ${end.y-3}`} stroke={skin} strokeWidth="28" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <ellipse cx={end.x} cy={end.y-3} rx="18" ry="22" fill={skin}/>
    </g>;
  }
  function leg(side: number, end: Point) {
    const hip={x:side*37,y:80}, knee=joint(hip,end,132,128,side);
    return <g>
      <path d={`M${hip.x} ${hip.y} L${knee.x} ${knee.y} L${end.x} ${end.y-19}`} stroke="#a95936" strokeWidth="40" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d={`M${hip.x-4} ${hip.y} L${knee.x-4} ${knee.y} L${end.x-4} ${end.y-19}`} stroke="#d98d4c" strokeWidth="30" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <g transform={`translate(${end.x} ${end.y})`}>
        <path d="M-19-43 L19-43 20-6-20-6Z" fill="#fff8dd"/>
        <path d="M-21-11 Q-6-22 16-11 L28 10 Q33 27 13 32 L-18 29 Q-29 18-21-11" fill="#e8618e"/>
      </g>
    </g>;
  }

  return <g opacity={opacity} transform={`translate(${x+shiver} ${y+bob}) rotate(${sway}) scale(${scale})`}>
    <g fill="url(#hair)">
      <path d="M-73-239 Q-115-200-107-95 Q-125-43-86-25 L88-26 Q121-43 103-107 Q109-220 62-251Z"/>
      {jumping&&Array.from({length:7},(_,i)=><path key={i} d={`M${(i-3)*21} -208 Q${(i-3)*48} -300 ${(i-3)*50+wave(f-8,.065,18,i)} ${-395+Math.abs(i-3)*22} Q${(i-3)*58+wave(f-8,.065,18,i)} ${-435+Math.abs(i-3)*24} ${(i-3)*68-22} ${-395+Math.abs(i-3)*18} Q${(i-3)*35-25} -275 ${(i-3)*24-24} -208Z`}/>)}
    </g>
    {arm(-1,handL)}{arm(1,handR)}
    {leg(-1,footL)}{leg(1,footR)}
    <g transform={`scale(1 ${1+breathe})`}>
      <path d="M-48-127 Q-67-122-85-108 L-94-72 Q-76-58-60-68 L-59 59 Q0 83 61 56 L59-69 Q78-58 95-78 L81-110 Q63-123 46-128Z" fill="url(#shirt)"/>
      <path d="M-55 57 Q0 74 58 56 L61 105 Q35 122 6 107 L0 96-6 108 Q-34 119-58 106Z" fill="#ff648a"/>
    </g>
    <g transform={`translate(0 -219) rotate(${wave(f-6,.04,jumping?5:1.6)})`}>
      <ellipse cx="-69" cy="5" rx="16" ry="22" fill="#b56942"/><ellipse cx="69" cy="5" rx="16" ry="22" fill="#b56942"/>
      <path d="M-70-31 Q-67-83 0-83 Q68-83 72-29 L65 22 Q56 76 0 83 Q-58 74-66 23Z" fill="url(#skin-face)"/>
      <path d="M-72-9 Q-94-66-42-92 Q10-121 61-81 Q86-60 74-10 Q43-37 33-67 Q-17-29-72-9" fill="url(#hair)"/>
      <Face f={f} mood={freezing?'pain':eating?'lick':jumping?'happy':'happy'} scale={1.1}/>
    </g>
    {eating&&<g transform="translate(130 -140) rotate(-25)"><IceCreamCone f={f} scale={.65}/></g>}
  </g>;
}

// Ilustración: Tina de helado abierta en dos mitades con burbujas de aire (50% aire)
export function IceCreamTub({f, split = 0}: {f: number; split?: number}) {
  return <g transform={`translate(360 ${700+wave(f,.04,6)})`}>
    <ellipse cy="210" rx="170" ry="28" fill="#1b1236" opacity=".3"/>
    {/* Bote abierto */}
    <g transform={`translate(${-split*75} 0)`}>
      <path d="M-150-130 L-130 180 Q-70 195 0 195 L0-130Z" fill="#e84a73"/>
      <path d="M-140-120 L-122 170 Q-65 185 0 185 L0-120Z" fill="url(#cream-vanilla)"/>
    </g>
    <g transform={`translate(${split*75} 0)`}>
      <path d="M0-130 L0 195 Q70 195 130 180 L150-130Z" fill="#e84a73"/>
      <path d="M0-120 L0 185 Q65 185 122 170 L140-120Z" fill="url(#cream-strawberry)"/>
    </g>
    {/* Burbujas de aire flotando en medio si se abre */}
    {split > 0.05 && <g opacity={split}>
      {Array.from({length: 18}, (_, i) => {
        const angle = i * 20;
        const r = 40 + seeded(i) * 90;
        const bx = Math.cos(angle) * r, by = Math.sin(angle) * r * 1.3 - 20 + wave(f, .07, 7, i);
        return <g key={i} transform={`translate(${bx} ${by})`}>
          <circle r={8 + seeded(i+4)*14} fill="#ffffff" opacity=".8"/>
          <circle cx="-3" cy="-3" r={3 + seeded(i)*4} fill="#b4f4ff"/>
        </g>;
      })}
    </g>}
    <rect x="-160" y="-145" width="320" height="28" rx="10" fill="#f87599"/>
  </g>;
}

// Ilustración: Cono de helado con bolas de helado
export function IceCreamCone({f, scale = 1}: {f: number; scale?: number}) {
  const drip = wave(f, .05, 5);
  return <g transform={`scale(${scale})`}>
    {/* Barquillo */}
    <path d="M-55 40 L55 40 L0 230Z" fill="url(#cone-waffle)"/>
    {/* Textura de rejilla */}
    {[-25, -5, 15, 35].map((y, i) => <line key={i} x1={-45 + i*10} y1={y} x2={45 - i*10} y2={y + 35} stroke="#8f5112" strokeWidth="2.5" opacity=".4"/>)}
    {[-25, -5, 15, 35].map((y, i) => <line key={i} x1={45 - i*10} y1={y} x2={-45 + i*10} y2={y + 35} stroke="#8f5112" strokeWidth="2.5" opacity=".4"/>)}
    {/* Bola chocolate */}
    <circle cx="0" cy="15" r="58" fill="url(#cream-chocolate)"/>
    {/* Bola fresa */}
    <circle cx="-25" cy="-35" r="54" fill="url(#cream-strawberry)"/>
    {/* Bola vainilla superior */}
    <circle cx="15" cy="-75" r="56" fill="url(#cream-vanilla)"/>
    {/* Gota derritiéndose */}
    <path d={`M-32 30 Q-34 ${65+drip} -30 ${75+drip} Q-26 ${65+drip} -28 30`} fill="#fa7ba7"/>
  </g>;
}

// Ilustración: Bloque de roca vs cuchara doblada
export function FrozenRock({f}: {f:number}) {
  return <g transform={`translate(360 690) rotate(${wave(f,.02,2)})`}>
    <ellipse cy="190" rx="190" ry="32" fill="#160e35" opacity=".4"/>
    {/* Roca de hielo impenetrable */}
    <polygon points="-160,140 -190,40 -130,-90 -20,-160 120,-140 180,-20 160,130 40,170" fill="url(#ice-blue)" stroke="#c2f5ff" strokeWidth="6"/>
    <path d="M-110 -20 L-40 40 L50 -30 M-40 40 L-10 120" stroke="#ffffff" strokeWidth="4" fill="none" opacity=".7"/>
    {/* Cuchara doblada con chispas */}
    <g transform="translate(20 -80) rotate(-35)">
      <path d="M-10-180 L10-180 L8-20 Q8 10 35 15 L70 20 Q80 22 75 35 Q65 42 40 35 L5 25 Q-10 20-10-20Z" fill="#cfd6ea"/>
      <ellipse cx="60" cy="27" rx="32" ry="20" fill="#e8eeff" transform="rotate(15 60 27)"/>
      <Spark x={35} y={15} size={25+wave(f,.1,8)} color="#fff890"/>
    </g>
  </g>;
}

// Ilustración: Los tres ingredientes
export function ThreeIngredients({f}: {f: number}) {
  return <g transform="translate(360 690)">
    {/* 1. Agua (gota cristalina) */}
    <g transform={`translate(-180 ${wave(f,.06,12)})`}>
      <path d="M0-110 C45-30 65 30 0 75 C-65 30-45-30 0-110Z" fill="url(#ice-blue)"/>
      <circle cx="-16" cy="15" r="10" fill="white" opacity=".6"/>
      <Label x={0} y={115} text="AGUA" size={19} color="#bcf5ff"/>
    </g>
    {/* 2. Crema / Grasa */}
    <g transform={`translate(0 ${wave(f,.06,12,1.5)})`}>
      <ellipse rx="68" ry="74" fill="url(#cream-vanilla)"/>
      <circle cx="20" cy="-20" r="18" fill="#ffeaa2" opacity=".7"/>
      <Label x={0} y={115} text="GRASA" size={19} color="#ffe89a"/>
    </g>
    {/* 3. Azúcar (cubos brillantes) */}
    <g transform={`translate(180 ${wave(f,.06,12,3)})`}>
      <g transform="rotate(22)">
        <polygon points="-35,-20 0,-40 35,-20 0,0" fill="#ffffff"/>
        <polygon points="-35,-20 0,0 0,40 -35,20" fill="#e0e8f7"/>
        <polygon points="35,-20 0,0 0,40 35,20" fill="#ccd9ee"/>
      </g>
      <Spark x={25} y={-35} size={15+wave(f,.08,5)} color="#ffffff"/>
      <Label x={0} y={115} text="AZÚCAR" size={19} color="#ffffff"/>
    </g>
  </g>;
}

// Ilustración: Emulsionante uniendo agua y grasa
export function EmulsionBridge({f}: {f:number}) {
  return <g transform="translate(360 690)">
    {/* Gota de agua a la izquierda */}
    <ellipse cx="-160" cy="0" rx="90" ry="110" fill="url(#ice-blue)"/>
    <text x="-160" y="10" textAnchor="middle" fill="#0c4f69" fontSize="26" fontWeight="800">AGUA</text>
    {/* Gota de grasa a la derecha */}
    <ellipse cx="160" cy="0" rx="90" ry="110" fill="url(#cream-vanilla)"/>
    <text x="160" y="10" textAnchor="middle" fill="#6c4d15" fontSize="26" fontWeight="800">GRASA</text>
    {/* Moléculas emulsionantes como puente en medio */}
    {[-50, 0, 50].map((y, i) => {
      const px = wave(f, .05, 10, i);
      return <g key={i} transform={`translate(${px} ${y})`}>
        {/* Cabeza hidrófila (ama el agua) */}
        <circle cx="-55" cy="0" r="18" fill="#3cd5c8"/>
        {/* Cola lipófila (ama la grasa) */}
        <path d="M-37 0 Q-15 -12 0 0 Q15 12 37 0 L55 0" stroke="#f4b33b" strokeWidth="8" fill="none" strokeLinecap="round"/>
        <circle cx="55" cy="0" r="12" fill="#e28f1e"/>
      </g>;
    })}
    <Label x={0} y={160} text="EMULSIONANTES: EL ENLACE" size={20} color="#affced"/>
  </g>;
}

// Ilustración: Freezer continuo con cuchillas giratorias
export function ChurningMachine({f}: {f:number}) {
  const rot = f * 8;
  return <g transform="translate(360 680)">
    <ellipse cy="210" rx="190" ry="32" fill="#130b2c" opacity=".4"/>
    {/* Cilindro de acero refrigerado */}
    <rect x="-180" y="-140" width="360" height="280" rx="40" fill="#243452" stroke="#486f99" strokeWidth="6"/>
    <rect x="-160" y="-120" width="320" height="240" rx="25" fill="#0f192b"/>
    {/* Frost exterior */}
    <text x="0" y="-160" textAnchor="middle" fill="#84f0ff" fontSize="32" fontWeight="850">-30°C CONGELADOR</text>
    {/* Eje central giratorio con cuchillas */}
    <circle r="45" fill="#4d6486"/>
    {[0, 90, 180, 270].map((deg, i) => (
      <g key={i} transform={`rotate(${deg + rot})`}>
        <rect x="35" y="-12" width="105" height="24" rx="6" fill="#a4bedb"/>
        <polygon points="140,-18 155,0 140,18" fill="#d9ebff"/>
      </g>
    ))}
    {/* Helado arremolinado dentro */}
    <circle r="120" fill="none" stroke="url(#cream-vanilla)" strokeWidth="18" strokeDasharray="60 35" opacity=".7" transform={`rotate(${-rot*.5})`}/>
  </g>;
}

// Ilustración: Microcristales bajo microscopio
export function MicroscopeView({f}: {f:number}) {
  return <g transform="translate(360 670)">
    {/* Círculo del ocular */}
    <circle r="210" fill="#120c2d" stroke="#5b488a" strokeWidth="12"/>
    <circle r="200" fill="#1f1847"/>
    {/* Red de microcristales diminutos suaves */}
    {Array.from({length: 28}, (_, i) => {
      const a = i * 28 + wave(f, .03, 8, i);
      const dist = 30 + (i * 23) % 150;
      const x = Math.cos(a) * dist, y = Math.sin(a) * dist;
      return <polygon key={i} points={`${x-8},${y-8} ${x+8},${y-8} ${x},${y+10}`} fill="#a4f0ff" opacity=".8" transform={`rotate(${f*1.2+i*40} ${x} ${y})`}/>;
    })}
    {/* Microburbujas de aire circundantes */}
    {Array.from({length: 12}, (_, i) => {
      const bx = Math.cos(i*1.8)*130, by = Math.sin(i*1.8)*130;
      return <circle key={i} cx={bx} cy={by} r={14+i%3*4} fill="#ffffff" opacity=".4"/>;
    })}
    <Label x={0} y={245} text="CRISTALES < 50 MICRAS (CREMOSO)" size={20} color="#a6f4ff"/>
  </g>;
}

// Ilustración: Cerebro con congelación (Brain Freeze)
export function BrainFreezeArt({f}: {f:number}) {
  const bolt = f % 6 < 3;
  return <g transform="translate(360 670)">
    {/* Cerebro helado */}
    <g transform={`scale(${1 + wave(f,.1,.03)})`}>
      <path d="M-91 35 Q-115 17-100-13 Q-110-42-83-54 Q-80-82-51-78 Q-27-104 0-86 Q26-104 50-79 Q81-85 85-55 Q113-47 103-17 Q120 11 99 33 Q104 59 78 65 Q53 88 29 68 Q0 87-25 68 Q-56 88-76 64 Q-105 63-91 35Z" fill="url(#ice-blue)" stroke="#ffffff" strokeWidth="6"/>
      <Face f={f} mood="pain" scale={1.1}/>
    </g>
    {/* Rayos de choque del paladar al cerebro */}
    {bolt && <path d="M-60 170 L-20 90 L-40 60 L0 -20 M60 170 L20 90 L40 60 L0 -20" stroke="#fff868" strokeWidth="6" fill="none" strokeLinecap="round"/>}
    <text x="0" y="240" textAnchor="middle" fill="#ffb4ce" fontSize="28" fontWeight="850">VASOS SANGUÍNEOS CONTRAÍDOS</text>
  </g>;
}

// Ilustración: Copa Gourmet y Temperatura Ideal -14°C
export function IdealServing({f}: {f:number}) {
  return <g transform="translate(360 680)">
    <ellipse cy="210" rx="160" ry="26" fill="#1b1236" opacity=".3"/>
    {/* Copa de cristal elegante */}
    <path d="M-90 -10 Q-90 120 0 130 Q90 120 90 -10Z" fill="none" stroke="#b4e6fa" strokeWidth="8"/>
    <path d="M0 130 V190 M-45 190 H45" stroke="#b4e6fa" strokeWidth="8" strokeLinecap="round"/>
    {/* Bolas de helado dentro */}
    <circle cx="-35" cy="15" r="50" fill="url(#cream-strawberry)"/>
    <circle cx="35" cy="15" r="50" fill="url(#cream-chocolate)"/>
    <circle cx="0" cy="-25" r="54" fill="url(#cream-vanilla)"/>
    {/* Vainilla cereza */}
    <circle cx="0" cy="-85" r="16" fill="#e82c58"/>
    <path d="M0 -101 Q15 -125 35 -115" stroke="#71321d" strokeWidth="4" fill="none"/>
    {/* Termómetro de degustación */}
    <g transform="translate(140 -40)">
      <rect x="-18" y="-90" width="36" height="150" rx="18" fill="#18233c" stroke="#5d83b4" strokeWidth="4"/>
      <rect x="-10" y="-30" width="20" height="80" rx="10" fill="#31d2e5"/>
      <circle cy="50" r="22" fill="#31d2e5"/>
      <text x="50" y="10" fill="#75efff" fontSize="30" fontWeight="850">-14°C</text>
    </g>
  </g>;
}
