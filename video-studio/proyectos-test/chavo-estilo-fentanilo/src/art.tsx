import React from 'react';

export const clamp = (n: number, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
export const ease = (n: number) => { const t = clamp(n); return t * t * (3 - 2 * t); };
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const wave = (f: number, speed = .06, amount = 1, phase = 0) => Math.sin(f * speed + phase) * amount;
export const seeded = (n: number) => { const a = Math.sin(n * 127.1 + 311.7) * 43758.5453; return a - Math.floor(a); };
type Point = {x: number; y: number};

function joint(a: Point, b: Point, l1: number, l2: number, bend: number): Point {
  const dx=b.x-a.x, dy=b.y-a.y;
  const d=clamp(Math.hypot(dx,dy),1,l1+l2-.01);
  const angle=Math.atan2(dy,dx)+bend*Math.acos(clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1));
  return {x:a.x+Math.cos(angle)*l1,y:a.y+Math.sin(angle)*l1};
}

/* ════════════════════════════════════════════════════════════════
   Art Defs — gradients, patterns, filters in fentanilo style
   ════════════════════════════════════════════════════════════════ */
export const ArtDefs = () => <defs>
  {/* Backgrounds */}
  <radialGradient id="bg-vecindad" cx="50%" cy="38%" r="75%"><stop stopColor="#ffc85a"/><stop offset=".45" stopColor="#f29f2e"/><stop offset="1" stopColor="#c97418"/></radialGradient>
  <radialGradient id="bg-barrel" cx="42%" cy="50%" r="60%"><stop stopColor="#6c4727"/><stop offset=".5" stopColor="#4a2f18"/><stop offset="1" stopColor="#2a1a0c"/></radialGradient>

  {/* Skin — warm Latin skin tone with gradient like fentanilo */}
  <linearGradient id="chavo-skin" x1="0" x2="1" y2=".5"><stop stopColor="#fad7bd"/><stop offset=".5" stopColor="#dba785"/><stop offset="1" stopColor="#c48a6a"/></linearGradient>
  <linearGradient id="chavo-skin-face" x1=".1" y1="0" x2=".8" y2="1"><stop stopColor="#fce4cd"/><stop offset="1" stopColor="#d4996e"/></linearGradient>

  {/* Hair */}
  <linearGradient id="chavo-hair" x1="0" x2=".9" y2="1"><stop stopColor="#2a1e14"/><stop offset=".5" stopColor="#1e150f"/><stop offset="1" stopColor="#0f0b08"/></linearGradient>

  {/* Hat plaid — the iconic Chavo ushanka */}
  <pattern id="chavo-plaid" width="28" height="28" patternUnits="userSpaceOnUse" patternTransform="rotate(-4)">
    <rect width="28" height="28" fill="#697268"/>
    <rect x="0" y="0" width="14" height="14" fill="#383d37"/>
    <rect x="14" y="14" width="14" height="14" fill="#383d37"/>
    <rect x="14" y="0" width="14" height="14" fill="#9da79c" opacity=".9"/>
    <rect x="0" y="14" width="14" height="14" fill="#9da79c" opacity=".9"/>
    <line x1="0" y1="14" x2="28" y2="14" stroke="#20241f" strokeWidth="1.4"/>
    <line x1="14" y1="0" x2="14" y2="28" stroke="#20241f" strokeWidth="1.4"/>
  </pattern>

  {/* Shirt stripes */}
  <linearGradient id="chavo-shirt-brown" x1="0" x2="1" y2=".5"><stop stopColor="#6a482c"/><stop offset=".6" stopColor="#5a3d24"/><stop offset="1" stopColor="#3d2717"/></linearGradient>

  {/* Suspender red-orange */}
  <linearGradient id="chavo-suspender" x1="0" x2="0" y1="0" y2="1"><stop stopColor="#f0523f"/><stop offset="1" stopColor="#b82f1f"/></linearGradient>

  {/* Shorts */}
  <linearGradient id="chavo-pants" x1="0" x2="1" y2=".5"><stop stopColor="#e2ddd5"/><stop offset="1" stopColor="#b5afa5"/></linearGradient>

  {/* Barrel wood */}
  <linearGradient id="barrel-wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stopColor="#4a2f18"/><stop offset="35%" stopColor="#8a5e35"/><stop offset="70%" stopColor="#6c4727"/><stop offset="100%" stopColor="#4a2f18"/></linearGradient>

  {/* Filters */}
  <filter id="drop" x="-30%" y="-30%" width="160%" height="175%"><feDropShadow dx="0" dy="10" stdDeviation="8" floodColor="#2a1407" floodOpacity=".22"/></filter>
  <filter id="small-drop" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="5" stdDeviation="3" floodColor="#2a1407" floodOpacity=".18"/></filter>
  <filter id="soft-glow" x="-75%" y="-75%" width="250%" height="250%"><feGaussianBlur stdDeviation="6"/></filter>

  {/* Dust overlay */}
  <pattern id="dust" width="83" height="83" patternUnits="userSpaceOnUse"><circle cx="8" cy="12" r=".8" fill="white" opacity=".1"/><circle cx="41" cy="62" r=".7" fill="white" opacity=".08"/></pattern>
</defs>;


/* ════════════════════════════════════════════════════════════════
   Spark — same sparkle accent from fentanilo
   ════════════════════════════════════════════════════════════════ */
export function Spark({x, y, size = 12, opacity = 1, color = '#fff8d9'}: {x: number; y: number; size?: number; opacity?: number; color?: string}) {
  return <path d={`M ${x} ${y-size} Q ${x+2} ${y-2} ${x+size} ${y} Q ${x+2} ${y+2} ${x} ${y+size} Q ${x-2} ${y+2} ${x-size} ${y} Q ${x-2} ${y-2} ${x} ${y-size}`} fill={color} opacity={opacity}/>;
}


/* ════════════════════════════════════════════════════════════════
   Backdrop — warm vecindad setting (fentanilo palette)
   ════════════════════════════════════════════════════════════════ */
export function Backdrop({f}: {f: number}) {
  return <g>
    <rect width="720" height="1280" fill="url(#bg-vecindad)"/>
    {/* Subtle warm wave lines */}
    {Array.from({length: 10}, (_, i) => {
      const y = i * 140 - 80 + wave(f, .015, 12, i);
      return <path key={i} d={`M -60 ${y} C ${100+wave(f,.01,50,i)} ${y-100} 320 ${y+160} 440 ${y+70} S 640 ${y-70} 800 ${y+90}`} stroke={i%2 ? '#e8852a' : '#ffc34c'} strokeWidth={14+i%3*6} opacity=".18" fill="none"/>;
    })}
    {/* Floor line */}
    <rect x="0" y="900" width="720" height="380" fill="#a86a25" opacity=".45"/>
    <line x1="0" y1="900" x2="720" y2="900" stroke="#6b3e15" strokeWidth="4" opacity=".5"/>
    {/* Floating warm particles */}
    {Array.from({length: 25}, (_, i) => {
      const px=seeded(i+30)*720, py=(seeded(i+80)*1400-f*(.08+seeded(i)*.2)+14000)%1400-60;
      return i%4===0
        ? <Spark key={i} x={px} y={py} size={3+seeded(i)*6} opacity={.15+Math.abs(wave(f,.025,.35,i))}/>
        : <circle key={i} cx={px} cy={py} r={1+seeded(i)*3} fill="#fff8be" opacity={.06+seeded(i)*.12}/>;
    })}
    <rect width="720" height="1280" fill="url(#dust)"/>
  </g>;
}


/* ════════════════════════════════════════════════════════════════
   ChavoFace — expressive face in fentanilo gradient style
   ════════════════════════════════════════════════════════════════ */
export function ChavoFace({f, mood = 'neutral', scale = 1}: {f: number; mood?: 'neutral'|'talk'|'smile'|'crying'|'scared'|'determined'; scale?: number}) {
  const blink = f%120 > 113 ? clamp(Math.abs(f%120-116)/3) : 1;
  const closed = mood === 'crying';
  const isTalking = mood === 'talk';
  const mouthOpen = isTalking ? Math.abs(wave(f, .35, 5)) : 0;

  return <g transform={`scale(${scale})`}>
    {/* Eyes — pill-shaped white sclera with dark pupils, fentanilo style */}
    {[-1,1].map(side=><g key={side} transform={`translate(${side*26} 0)`}>
      {closed ? <path d="M-11-2 Q0 8 11-2" stroke="#30243c" strokeWidth="4.5" strokeLinecap="round" fill="none"/> : <g transform={`scale(1 ${Math.max(.06,blink)})`}>
        <ellipse rx="13" ry="16" fill="#fffbed"/>
        <ellipse cx={side===-1?2:0} cy="2" rx="7.5" ry="11" fill="#1e150f"/>
        <circle cx="-2" cy="-4" r="3.5" fill="white"/>
      </g>}
      {/* Eyebrows — thick and expressive */}
      <path d={mood==='scared'?'M-12-25 Q0-18 12-28':mood==='determined'?'M-12-28 Q0-32 12-24':mood==='crying'?'M-12-18 Q0-28 12-18':'M-12-24 Q0-30 12-25'} transform={side===1?'scale(-1 1)':undefined} stroke="#2a1e14" strokeWidth="5" fill="none" strokeLinecap="round"/>
      {/* Cheek blush */}
      <ellipse cy="22" cx={side*5} rx="10" ry="5.5" fill="#ef7899" opacity=".35"/>
    </g>)}
    {/* Nose — small rounded line, fentanilo style */}
    <path d="M-2 13 Q-7 26 5 22" stroke="#b5704a" strokeWidth="3" fill="none" strokeLinecap="round"/>
    {/* Mouth */}
    {mood==='crying' ? <path d="M-10 34 Q0 22 10 34" fill="none" stroke="#5c2941" strokeWidth="4" strokeLinecap="round"/> :
     mood==='smile' ? <>
      <path d="M-14 28 Q0 40 14 28 Q10 50 0 49 Q-11 48-14 28" fill="#682a4b"/>
      <path d="M-8 42 Q0 36 8 42 Q0 52-8 42" fill="#f27b9c"/>
     </> :
     isTalking ? <ellipse cx="0" cy={34} rx={8+mouthOpen} ry={3+mouthOpen*1.2} fill="#682a4b" stroke="#4a1d33" strokeWidth="2"/> :
     <path d="M-9 32 Q0 37 9 32" fill="none" stroke="#5c3a2a" strokeWidth="3.5" strokeLinecap="round"/>}
    {/* Tears when crying */}
    {mood==='crying' && <>
      <ellipse cx="-18" cy={28+(f*3.5)%50} rx="3" ry="5" fill="#87d4f5" opacity={.7-((f*3.5)%50)/80}/>
      <ellipse cx="18" cy={32+(f*3.2)%45} rx="2.5" ry="4.5" fill="#87d4f5" opacity={.6-((f*3.2)%45)/70}/>
    </>}
  </g>;
}


/* ════════════════════════════════════════════════════════════════
   CHAVO DEL 8 — full articulated character, fentanilo art style
   ════════════════════════════════════════════════════════════════ */
export type ChavoPose = 'idle' | 'seated' | 'barrel_peek' | 'eso_eso';

export function Chavo({f, pose = 'idle', mood = 'neutral', scale = 1, x = 360, y = 760, opacity = 1, showBarrel = false}: {
  f: number; pose?: ChavoPose; mood?: 'neutral'|'talk'|'smile'|'crying'|'scared'|'determined';
  scale?: number; x?: number; y?: number; opacity?: number; showBarrel?: boolean;
}) {
  const seated = pose === 'seated';
  const peekBarrel = pose === 'barrel_peek';
  const bob = wave(f, .055, seated ? 1.5 : 3), sway = wave(f, .032, seated ? 0.8 : 1.4);
  const breathe = wave(f, .075, .009);
  const cryTremble = mood === 'crying' ? wave(f, .45, 2) : 0;

  // IK endpoints for standing/idle
  const handL = {x: seated ? -60 : -97+wave(f,.05,4), y: seated ? 80 : 113};
  const handR = {x: seated ? 85 : 101+wave(f,.05,4,2), y: seated ? 75 : 110};
  const footL = {x: seated ? -65 : -57, y: seated ? 260 : 333};
  const footR = {x: seated ? 80 : 52, y: seated ? 230 : 333};
  const skin = '#ce804a';

  function arm(side: number, end: Point) {
    const a = {x: side*55, y: -102}, b = joint(a, end, 100, 108, side);
    return <g>
      <path d={`M${a.x} ${a.y} Q${b.x} ${b.y} ${b.x} ${b.y} L${end.x} ${end.y}`} stroke="#a85636" strokeWidth="32" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <path d={`M${a.x-2} ${a.y-2} L${b.x-2} ${b.y-2} L${end.x-2} ${end.y-2}`} stroke={skin} strokeWidth="26" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      <ellipse cx={end.x} cy={end.y-3} rx="17" ry="20" fill={skin}/>
      <path d={`M${end.x-7} ${end.y-8} l1-9 m6 8 1-9 m5 10 1-8`} stroke="#a95f3b" strokeWidth="2" strokeLinecap="round" fill="none"/>
      <circle cx={b.x-2} cy={b.y-2} r="6" fill="#e8a36b" opacity=".28"/>
    </g>;
  }

  function leg(side: number, end: Point) {
    const hip = {x: side*37, y: 80}, knee = joint(hip, end, 120, 115, side);
    return <g>
      <path d={`M${hip.x} ${hip.y} L${knee.x} ${knee.y} L${end.x} ${end.y-16}`} stroke="#a95936" strokeWidth="38" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <path d={`M${hip.x-3} ${hip.y} L${knee.x-3} ${knee.y} L${end.x-3} ${end.y-16}`} stroke="#d98d4c" strokeWidth="28" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      <ellipse cx={knee.x-3} cy={knee.y} rx="10" ry="7" fill="#efb16f" opacity=".42"/>
      {/* Shoe / sandal */}
      <g transform={`translate(${end.x} ${end.y}) rotate(${side*4})`}>
        <path d="M-16-12 Q-4-18 12-12 L22 6 Q26 18 8 22 L-14 20 Q-22 12-16-12" fill="#6e4a2c"/>
        <path d="M-16-10 Q-3-14 8-8 L10 12 Q-5 20-17 10Z" fill="#8c6340"/>
        <path d="M-18 14 Q0 24 22 14 L20 20 Q0 28-16 20Z" fill="#c4a478"/>
      </g>
    </g>;
  }

  return <g opacity={opacity} transform={`translate(${x} ${y+bob}) rotate(${sway+cryTremble}) scale(${scale})`} filter="url(#drop)">
    {/* ── Barrel ── */}
    {showBarrel && <g transform={`translate(${seated ? -180 : -160}, ${seated ? -60 : -40})`}>
      <ellipse cx="0" cy="310" rx="100" ry="22" fill="#000" opacity=".25"/>
      <path d="M -75,-200 Q -105,40 -78,300 L 78,300 Q 105,40 75,-200 Z" fill="url(#barrel-wood)" stroke="#161514" strokeWidth="5" strokeLinejoin="round"/>
      <path d="M -42,-200 Q -65,40 -45,300" stroke="#351f0f" strokeWidth="3" fill="none" opacity=".55"/>
      <path d="M 15,-200 Q 22,40 15,300" stroke="#351f0f" strokeWidth="3" fill="none" opacity=".55"/>
      <path d="M 42,-200 Q 65,40 45,300" stroke="#351f0f" strokeWidth="3" fill="none" opacity=".55"/>
      {/* Metal hoops */}
      <path d="M -78,-145 Q 0,-125 78,-145" stroke="#1a1816" strokeWidth="18" fill="none" strokeLinecap="round"/>
      <path d="M -92,-30 Q 0,-5 92,-30" stroke="#1a1816" strokeWidth="20" fill="none" strokeLinecap="round"/>
      <path d="M -92,120 Q 0,145 92,120" stroke="#1a1816" strokeWidth="20" fill="none" strokeLinecap="round"/>
      <path d="M -80,250 Q 0,272 80,250" stroke="#1a1816" strokeWidth="20" fill="none" strokeLinecap="round"/>
      {/* Barrel mouth */}
      <ellipse cx="0" cy="-200" rx="75" ry="17" fill="#361f10" stroke="#161514" strokeWidth="5"/>
      <ellipse cx="0" cy="-200" rx="64" ry="11" fill="#180e07"/>
    </g>}

    {/* ── Hair backing ── */}
    <g fill="url(#chavo-hair)">
      <path d="M-65-230 Q-100-195-95-90 Q-110-40-76-22 L78-23 Q110-40 95-100 Q98-210 55-242Z"/>
    </g>

    {/* ── Arms and Legs ── */}
    {arm(-1, handL)}{arm(1, handR)}
    {!peekBarrel && <>{leg(-1, footL)}{leg(1, footR)}</>}

    {/* ── Torso ── */}
    <g transform={`scale(1 ${1+breathe})`}>
      {/* Shirt body — striped: alternating brown and cream */}
      <path d="M-48-127 Q-62-122-78-108 L-84-72 Q-70-58-54-68 L-53 55 Q0 78 55 52 L53-69 Q72-58 88-78 L74-110 Q58-123 42-128Z" fill="url(#chavo-shirt-brown)"/>
      {/* Horizontal stripes — cream bands */}
      <clipPath id="shirt-clip"><path d="M-48-127 Q-62-122-78-108 L-84-72 Q-70-58-54-68 L-53 55 Q0 78 55 52 L53-69 Q72-58 88-78 L74-110 Q58-123 42-128Z"/></clipPath>
      <g clipPath="url(#shirt-clip)">
        {[-105,-80,-55,-30,-5,20,45].map((yy,i) => i%2===0 ?
          <rect key={i} x="-95" y={yy} width="190" height="25" fill="#eae5dc" opacity=".85"/> : null
        )}
      </g>
      {/* Shirt highlight fold */}
      <path d="M-43-110 Q-22-90-24-28 L-26 35" stroke="#8c6840" strokeWidth="12" opacity=".25" fill="none" strokeLinecap="round"/>

      {/* Suspenders — red-orange diagonal straps */}
      <path d="M-35-125 L-15 55" stroke="url(#chavo-suspender)" strokeWidth="14" strokeLinecap="round"/>
      <path d="M38-120 L18 52" stroke="url(#chavo-suspender)" strokeWidth="14" strokeLinecap="round"/>
      {/* Suspender belt line */}
      <path d="M-53 55 Q0 72 55 52" stroke="#e84534" strokeWidth="9" fill="none"/>

      {/* Shorts — light grey bermudas */}
      <path d="M-53 55 Q0 72 55 52 L58 100 Q30 118 4 103 L0 92 -4 104 Q-30 116-55 102Z" fill="url(#chavo-pants)"/>
      {/* Shorts crease */}
      <path d="M-50 96 L-12 101 M15 100 52 94" stroke="#9a958b" strokeWidth="4"/>
      {/* Patch on shorts */}
      <g transform="translate(-28, 78) rotate(-3)">
        <polygon points="0,0 28,2 25,18 -2,16" fill="#847e75" stroke="#1b1a19" strokeWidth="3"/>
        <line x1="-1" y1="-1" x2="29" y2="1" stroke="#1b1a19" strokeWidth="2.5" strokeDasharray="4,3"/>
        <line x1="29" y1="1" x2="26" y2="20" stroke="#1b1a19" strokeWidth="2.5" strokeDasharray="4,3"/>
        <line x1="26" y1="20" x2="-3" y2="18" stroke="#1b1a19" strokeWidth="2.5" strokeDasharray="4,3"/>
        <line x1="-3" y1="18" x2="-1" y2="-1" stroke="#1b1a19" strokeWidth="2.5" strokeDasharray="4,3"/>
      </g>

      {/* Neck */}
      <path d="M-18-157 L-18-120 Q0-100 20-120 L20-158Z" fill="url(#chavo-skin)"/>
    </g>

    {/* ── Head ── */}
    <g transform={`translate(0 -215) rotate(${wave(f-6,.04,1.4)+cryTremble*0.5})`}>
      {/* Ears */}
      <ellipse cx="-62" cy="5" rx="14" ry="20" fill="#c48a6a"/>
      <ellipse cx="62" cy="5" rx="14" ry="20" fill="#c48a6a"/>
      {/* Face */}
      <path d="M-63-28 Q-60-78 0-78 Q60-78 63-26 L58 22 Q50 70 0 78 Q-52 68-58 23Z" fill="url(#chavo-skin-face)"/>
      {/* Hair fringe under hat */}
      <path d="M-65-8 Q-85-58-38-85 Q8-112 52-74 Q78-54 66-8 Q38-32 28-62 Q-15-26-65-8" fill="url(#chavo-hair)"/>
      <path d="M-54-50 Q-18-92 24-78" stroke="#4a3020" strokeWidth="6" opacity=".4" fill="none" strokeLinecap="round"/>
      {/* Face features */}
      <ChavoFace f={f} mood={mood} scale={1}/>

      {/* ── HAT — Ushanka with plaid, visor, ear flaps ── */}
      <g transform="translate(0, -72)">
        {/* Hat dome */}
        <path d="M-68 8 Q-72-30-48-52 Q-20-72 0-72 Q20-72 48-52 Q72-30 68 8Z" fill="url(#chavo-plaid)" stroke="#20241f" strokeWidth="3"/>
        {/* Visor / brim */}
        <path d="M-55 6 Q-60 28-35 26 L35 26 Q60 28 55 6Z" fill="#474c46" stroke="#20241f" strokeWidth="2.5"/>
        <path d="M-48 10 Q0 18 48 10" stroke="#9da79c" strokeWidth="3" fill="none" opacity=".5"/>
        {/* Left ear flap */}
        <path d="M-60 2 L-78 42 Q-80 58-68 62 L-52 58 L-48 8Z" fill="url(#chavo-plaid)" stroke="#20241f" strokeWidth="2.5" transform={`rotate(${wave(f,.06,1.5)})`}/>
        {/* Right ear flap */}
        <path d="M60 2 L78 42 Q80 58 68 62 L52 58 L48 8Z" fill="url(#chavo-plaid)" stroke="#20241f" strokeWidth="2.5" transform={`rotate(${-wave(f,.06,1.5)})`}/>
        {/* Hat band */}
        <path d="M-62 8 Q0 18 62 8" stroke="#20241f" strokeWidth="5" fill="none"/>
      </g>
    </g>

    {/* ── Toy car if seated ── */}
    {seated && <g transform={`translate(${80+wave(f,.1,.6)}, ${handR.y+10}) rotate(${wave(f,.08,2)})`}>
      <rect x="-28" y="-14" width="56" height="24" rx="5" fill="#f0433a" stroke="#1e2126" strokeWidth="3"/>
      <rect x="-18" y="-12" width="20" height="12" rx="2" fill="#8ed5fa" opacity=".8"/>
      <circle cx="-18" cy="12" r="6" fill="#1e2126"/><circle cx="-18" cy="12" r="3" fill="#555"/>
      <circle cx="18" cy="12" r="6" fill="#1e2126"/><circle cx="18" cy="12" r="3" fill="#555"/>
      <path d="M-26-11 Q-32-22-14-22 L16-22 Q32-22 28-11" fill="#f0433a" stroke="#1e2126" strokeWidth="2"/>
      <ellipse cx="-10" cy="-9" rx="5" ry="3" fill="#fff" opacity=".35"/>
    </g>}

    {/* Pain / eso_eso effect */}
    {pose === 'eso_eso' && <g transform="translate(55 -250)">
      <circle r={32+wave(f,.12,5)} fill="#ff4d96" opacity=".14"/>
      <path d="M-22-22-32-34 M12-28 16-44 M28-6 44-10 M18 22 30 34" stroke="#ff80bc" strokeWidth="3.5" fill="none" strokeLinecap="round"/>
    </g>}
  </g>;
}


/* ════════════════════════════════════════════════════════════════
   Label — text label with dark pill background
   ════════════════════════════════════════════════════════════════ */
export function Label({x, y, text, color = '#fff8e0', size = 23}: {x: number; y: number; text: string; color?: string; size?: number}) {
  const w = text.length * size * .54 + 30;
  return <g transform={`translate(${x} ${y})`}><rect x={-w/2} y={-size-7} width={w} height={size+20} rx="10" fill="#2a1a0c" opacity=".82"/><text textAnchor="middle" fill={color} fontSize={size} fontWeight="750">{text}</text></g>;
}
