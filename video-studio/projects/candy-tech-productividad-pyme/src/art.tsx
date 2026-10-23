import React from 'react';

export const clamp=(n:number,a=0,b=1)=>Math.min(b,Math.max(a,n));
export const mix=(a:number,b:number,t:number)=>a+(b-a)*t;
export const ease=(n:number)=>{const t=clamp(n);return t*t*(3-2*t);};
export const wave=(f:number,s=.06,a=1,p=0)=>Math.sin(f*s+p)*a;
const seeded=(n:number)=>{const a=Math.sin(n*127.1+311.7)*43758.5453;return a-Math.floor(a);};
type P={x:number;y:number};
export function joint(a:P,b:P,l1:number,l2:number,bend:number):P{const dx=b.x-a.x,dy=b.y-a.y,d=clamp(Math.hypot(dx,dy),1,l1+l2-.01),q=Math.atan2(dy,dx)+bend*Math.acos(clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1));return{x:a.x+Math.cos(q)*l1,y:a.y+Math.sin(q)*l1};}

export const ArtDefs=()=> <defs>
 <marker id="arrow" markerWidth="10" markerHeight="10" refX="7" refY="5" orient="auto"><path d="M0 0L10 5L0 10Z" fill="#ff8768"/></marker>
 <radialGradient id="bg-navy" cx="48%" cy="28%" r="85%"><stop stopColor="#164d7a"/><stop offset=".48" stopColor="#092e59"/><stop offset="1" stopColor="#06162f"/></radialGradient>
 <radialGradient id="bg-teal" cx="50%" cy="33%" r="82%"><stop stopColor="#35d1bd"/><stop offset=".49" stopColor="#087f88"/><stop offset="1" stopColor="#07344e"/></radialGradient>
 <radialGradient id="bg-coral" cx="50%" cy="28%" r="86%"><stop stopColor="#ff9a72"/><stop offset=".5" stopColor="#dc594e"/><stop offset="1" stopColor="#692e48"/></radialGradient>
 <linearGradient id="skin" x2=".8" y2="1"><stop stopColor="#ffd3a8"/><stop offset=".58" stopColor="#e6a17a"/><stop offset="1" stopColor="#bc6d62"/></linearGradient>
 <linearGradient id="skin-face" x2=".85" y2="1"><stop stopColor="#ffd5a3"/><stop offset=".58" stopColor="#e9a46f"/><stop offset="1" stopColor="#c87552"/></linearGradient>
 <linearGradient id="hair" x2=".7" y2="1"><stop stopColor="#302633"/><stop offset=".56" stopColor="#191d30"/><stop offset="1" stopColor="#101a31"/></linearGradient>
 <linearGradient id="suit" x2=".9" y2="1"><stop stopColor="#315d88"/><stop offset=".42" stopColor="#153d68"/><stop offset="1" stopColor="#0a2547"/></linearGradient>
 <linearGradient id="suit-light" x2="1" y2="1"><stop stopColor="#577ca0"/><stop offset="1" stopColor="#173b63"/></linearGradient>
 <linearGradient id="shirt-ivory" x2=".8" y2="1"><stop stopColor="#fffdf2"/><stop offset="1" stopColor="#dce9e3"/></linearGradient>
 <linearGradient id="shirt" x2=".8" y2="1"><stop stopColor="#e9fff6"/><stop offset=".55" stopColor="#75d9c4"/><stop offset="1" stopColor="#15989e"/></linearGradient>
 <linearGradient id="coral" x2=".8" y2="1"><stop stopColor="#ffb082"/><stop offset=".5" stopColor="#ff735b"/><stop offset="1" stopColor="#d74753"/></linearGradient>
 <linearGradient id="teal" x2=".8" y2="1"><stop stopColor="#a4fff0"/><stop offset=".55" stopColor="#28d2c0"/><stop offset="1" stopColor="#009b9e"/></linearGradient>
 <linearGradient id="glass" x2="1" y2="1"><stop stopColor="#e1fbff" stopOpacity=".9"/><stop offset="1" stopColor="#98c8ed" stopOpacity=".56"/></linearGradient>
 <radialGradient id="halo"><stop stopColor="#83f9df" stopOpacity=".6"/><stop offset="1" stopColor="#46ddcb" stopOpacity="0"/></radialGradient>
 <filter id="depth" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur in="SourceAlpha" stdDeviation="10"/><feOffset dy="12"/><feComponentTransfer><feFuncA type="linear" slope=".35"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="soft"><feGaussianBlur stdDeviation="17"/></filter>
 <pattern id="sparkle" width="92" height="92" patternUnits="userSpaceOnUse"><circle cx="12" cy="21" r="1.2" fill="#fff" opacity=".18"/><circle cx="69" cy="59" r=".9" fill="#fff" opacity=".14"/></pattern>
</defs>;

export function Backdrop({palette,f}:{palette:string;f:number}){return <g><rect width="720" height="1280" fill={`url(#bg-${palette})`}/><ellipse cx={360+wave(f,.01,28)} cy="560" rx="330" ry="285" fill="url(#halo)" opacity=".35"/><rect width="720" height="1280" fill="url(#sparkle)"/>{Array.from({length:18},(_,i)=><circle key={i} cx={seeded(i)*720} cy={(seeded(i+40)*1280+f*(.14+i%3*.08))%1280} r={1.5+seeded(i+99)*2} fill="#dffff6" opacity=".18"/>)}</g>;}

function Owner({f,pose='open'}:{f:number;pose?:string}){
 const thinking=pose==='thinking',breathe=wave(f,.075,.009),blink=(f%133>125)||(f%187>166&&f%187<170),sway=wave(f,.032,1.4);
 const skin='#d68a5f',skinShadow='#aa604c';
 const leftHand: P=thinking?{x:-77,y:35}:{x:-142+wave(f,.05,5),y:-4+wave(f,.06,4)};
 const rightHand: P=thinking?{x:55+wave(f,.025,3),y:-164+wave(f,.04,3)}:{x:148+wave(f,.045,7),y:-46+wave(f,.06,5)};
 const arms=[{side:-1,end:leftHand},{side:1,end:rightHand}].map(({side,end})=>{
  const shoulder={x:side*64,y:-106},elbow=joint(shoulder,end,105,95,side);
  return <g key={side}>
   <path d={`M${shoulder.x} ${shoulder.y}Q${elbow.x} ${elbow.y} ${elbow.x} ${elbow.y}L${end.x} ${end.y}`} fill="none" stroke="#092544" strokeWidth="36" strokeLinecap="round" strokeLinejoin="round"/>
   <path d={`M${shoulder.x-3} ${shoulder.y-3}L${elbow.x-3} ${elbow.y-3}L${end.x-3} ${end.y-3}`} fill="none" stroke="url(#suit-light)" strokeWidth="29" strokeLinecap="round" strokeLinejoin="round"/>
   <ellipse cx={elbow.x-2} cy={elbow.y-2} rx="13" ry="11" fill="#416b92" opacity=".65"/>
   <g transform={`translate(${end.x} ${end.y}) rotate(${side*12})`}>
    <path d="M-10-3Q-13-19-4-22Q4-22 5-11Q10-22 16-17Q19-12 13-4Q25-10 28-3Q28 5 15 11Q3 17-8 8Z" fill="url(#skin)" stroke="#ffddb9" strokeWidth="2.5" strokeLinejoin="round"/>
    <path d="M0-9L3-2M9-10L10-4M17-8L16-3" stroke={skinShadow} strokeWidth="2" strokeLinecap="round" opacity=".7"/>
   </g>
  </g>;
 });
 const legs=[-1,1].map(side=>{
  const hip={x:side*34,y:76},foot={x:side*48+wave(f,.035,2,side),y:330},knee=joint(hip,foot,122,128,side);
  return <g key={side}>
   <path d={`M${hip.x} ${hip.y}L${knee.x} ${knee.y}L${foot.x} ${foot.y-23}`} fill="none" stroke="#091f3a" strokeWidth="38" strokeLinecap="round" strokeLinejoin="round"/>
   <path d={`M${hip.x-4} ${hip.y}L${knee.x-4} ${knee.y}L${foot.x-4} ${foot.y-23}`} fill="none" stroke="url(#suit)" strokeWidth="29" strokeLinecap="round" strokeLinejoin="round"/>
   <path d={`M${knee.x-10} ${knee.y}L${knee.x+8} ${knee.y+6}`} stroke="#527497" strokeWidth="4" opacity=".5" strokeLinecap="round"/>
   <g transform={`translate(${foot.x} ${foot.y})`}>
    <path d="M-17-24H18V-2Q38 2 39 20Q38 30 24 31H-23Q-33 28-28 15Z" fill="#0a1c34" stroke="#6283a1" strokeWidth="3"/>
    <path d="M-17 19Q5 24 35 18" fill="none" stroke="#e2edea" strokeWidth="4" strokeLinecap="round"/>
    <path d="M-8-17L3-12M4-18L15-13" stroke="#9ab1c4" strokeWidth="2.5" strokeLinecap="round"/>
   </g>
  </g>;
 });
 return <g filter="url(#depth)" transform={`translate(360 ${774+wave(f,.055,2)}) rotate(${sway}) scale(.88)`}>
  <ellipse cy="346" rx="102" ry="17" fill="#051a2f" opacity=".35" filter="url(#soft)"/>
  {legs}
  {arms}
  <g transform={`scale(1 ${1+breathe})`}>
   <path d="M-45-133L-73-124Q-91-116-96-92L-79 68Q0 89 79 68L96-92Q89-116 69-124L43-133Z" fill="url(#shirt-ivory)" stroke="#e4f3ed" strokeWidth="3"/>
   <path d="M-60-127Q-81-119-94-102L-88 75Q-46 90 0 88V-105Z" fill="url(#suit)" stroke="#456b90" strokeWidth="3"/>
   <path d="M60-127Q81-119 94-102L88 75Q46 90 0 88V-105Z" fill="url(#suit)" stroke="#456b90" strokeWidth="3"/>
   <path d="M-49-124L-6-103L-30-68L-68-101Z" fill="#f7fbf2" stroke="#c7d9de" strokeWidth="2"/>
   <path d="M49-124L6-103L30-68L68-101Z" fill="#f7fbf2" stroke="#c7d9de" strokeWidth="2"/>
   <path d="M-8-103L0-94L8-103L5-82L0-77L-5-82Z" fill="#18b8b0" stroke="#b6fff1" strokeWidth="2"/>
   <path d="M-5-79L5-79L17 45L0 60L-17 45Z" fill="url(#teal)" stroke="#86f1df" strokeWidth="2"/>
   <path d="M49-82Q64-87 75-79L68-62L48-67Z" fill="url(#coral)" stroke="#ffc4a7" strokeWidth="2"/>
   <path d="M0-70V72" stroke="#8eacc0" strokeWidth="2" opacity=".55"/>
   <circle cx="23" cy="22" r="4" fill="#f1d7a3"/><circle cx="23" cy="48" r="4" fill="#f1d7a3"/>
   <path d="M-55 78Q0 94 55 78L49 101Q0 116-49 101Z" fill="#0c2949" stroke="#365d82" strokeWidth="3"/>
   <path d="M-15 108L0 116L15 108" fill="none" stroke="#f26349" strokeWidth="3" opacity=".7"/>
  </g>
  {thinking&&<g transform="translate(-83 34) rotate(-8)" filter="url(#depth)"><path d="M-23-39H26L32 50H-28Z" fill="#563f49" stroke="#bda9a0" strokeWidth="4"/><path d="M-12-27H14" stroke="#eccb99" strokeWidth="3" strokeLinecap="round"/><circle cx="20" cy="-28" r="3" fill="#ff8267"/></g>}
  <path d="M-18-153L-18-128Q0-111 18-128L18-153Z" fill="url(#skin)"/>
  <g transform={`translate(0 -219) rotate(${wave(f-6,.04,1.5)})`}>
   <ellipse cx="-68" cy="5" rx="15" ry="21" fill={skinShadow}/><ellipse cx="68" cy="5" rx="15" ry="21" fill={skinShadow}/>
   <path d="M-70-31Q-67-83 0-83Q67-83 70-29L63 22Q55 76 0 82Q-55 76-64 22Z" fill="url(#skin-face)" stroke="#f6c59d" strokeWidth="3"/>
   <path d="M-70-20Q-90-70-49-100Q-13-123 21-105Q60-98 73-67Q80-47 70-18Q49-38 37-70Q8-43-23-39Q-52-34-70-20Z" fill="url(#hair)" stroke="#382d3e" strokeWidth="4"/>
   <path d={`M-30-99Q-14-${122+wave(f-8,.065,4)}13-108Q32-118 49-101`} fill="none" stroke="#554254" strokeWidth="8" strokeLinecap="round"/>
   <path d="M-43-20Q-27-29-11-22M12-22Q29-30 44-19" fill="none" stroke="#392a3b" strokeWidth="5" strokeLinecap="round"/>
   <g transform={`scale(1 ${blink?0.08:1})`}>
    <ellipse cx="-27" cy="0" rx="14" ry="17" fill="#fff8eb"/><ellipse cx="27" cy="0" rx="14" ry="17" fill="#fff8eb"/>
    <ellipse cx="-25" cy="2" rx="8" ry="11" fill="#272538"/><ellipse cx="29" cy="2" rx="8" ry="11" fill="#272538"/>
    <circle cx="-28" cy="-3" r="3.5" fill="#fff"/><circle cx="26" cy="-3" r="3.5" fill="#fff"/>
   </g>
   <path d="M-1 10Q-8 26 1 27Q7 27 10 20" fill="none" stroke="#a85e4a" strokeWidth="3" strokeLinecap="round"/>
   <path d={thinking?'M-16 47Q0 39 16 47':'M-18 43Q0 61 19 42'} fill="none" stroke="#71384a" strokeWidth="4" strokeLinecap="round"/>
   <path d="M-45 33Q-37 71-15 77M45 33Q37 71 15 77" fill="none" stroke="#9f5e53" strokeWidth="2" opacity=".44" strokeLinecap="round"/>
   <ellipse cx="-46" cy="30" rx="10" ry="5" fill="#ed8575" opacity=".3"/><ellipse cx="46" cy="30" rx="10" ry="5" fill="#ed8575" opacity=".3"/>
   <path d="M-65-2L-71 22M65-2L71 22" stroke="#2b2538" strokeWidth="8" strokeLinecap="round"/>
  </g>
 </g>;
}

function Paper({x,y,r=0,color='#fff2de'}:{x:number;y:number;r?:number;color?:string}){return <g transform={`translate(${x} ${y}) rotate(${r})`} filter="url(#depth)"><path d="M-40-50H24L42-32V51H-40Z" fill={color} stroke="#fff" strokeWidth="3"/><path d="M24-49V-31H42" fill="none" stroke="#d0bdad" strokeWidth="3"/><path d="M-25-16H21M-25 0H21M-25 16H8" stroke="#98a8b4" strokeWidth="4" strokeLinecap="round"/></g>;}
function Node({x,y,label,color='teal'}:{x:number;y:number;label:string;color?:string}){return <g transform={`translate(${x} ${y})`} filter="url(#depth)"><circle r="45" fill={color==='coral'?'url(#coral)':'url(#teal)'} stroke="#dcfff6" strokeWidth="4"/><circle r="12" fill="#fff" opacity=".9"/><text y="69" textAnchor="middle" fill="#fff" fontSize="16" fontWeight="800" letterSpacing="1">{label}</text></g>;}
function Flow({f}:{f:number}){return <g filter="url(#depth)"><path d="M143 718C211 718 208 642 274 642S342 716 401 716S477 632 567 632" fill="none" stroke="#d7fff5" strokeWidth="10" strokeLinecap="round" opacity=".7"/><path d={`M${150+(f*3%420)} 718q14-8 28 0q-14 8-28 0`} fill="#ff8866"/><Node x={153} y={718} label="ENTRADA"/><Node x={360} y={678} label="PROCESO"/><Node x={565} y={636} label="RESULTADO" color="coral"/></g>;}
function Dashboard({f}:{f:number}){return <g transform="translate(360 680)" filter="url(#depth)"><path d="M-209-135Q-209-157-187-157H187Q209-157 209-135V120Q209 142 187 142H-187Q-209 142-209 120Z" fill="url(#glass)" stroke="#eafffb" strokeWidth="6"/><path d="M-209-86H209" stroke="#fff" strokeWidth="4" opacity=".7"/><circle cx="-178" cy="-122" r="7" fill="#ff8869"/><circle cx="-153" cy="-122" r="7" fill="#ffce78"/><circle cx="-128" cy="-122" r="7" fill="#68dfbd"/><path d="M-160 68V19H-119V68M-93 68V-17H-52V68M-26 68V-57H15V68M41 68V-7H82V68" fill="#079c9e" opacity=".8"/><path d="M-166-40Q-99-93-39-61T78-84T166-42" fill="none" stroke="#f26349" strokeWidth="8" strokeLinecap="round"/><circle cx={-39+wave(f,.08,9)} cy="-61" r="9" fill="#fff"/></g>;}
function Magnifier({f}:{f:number}){return <g transform={`translate(${360+wave(f,.025,8)} 690) rotate(-15)`} filter="url(#depth)"><circle r="114" fill="url(#glass)" stroke="#dffff8" strokeWidth="13"/><path d="M81 81L170 175" stroke="#f26349" strokeWidth="32" strokeLinecap="round"/><path d="M-49 4L-13 39L57-44" fill="none" stroke="#058c91" strokeWidth="13" strokeLinecap="round" strokeLinejoin="round"/></g>;}
function Lightbulb({f}:{f:number}){const glow=.7+Math.sin(f*.08)*.15;return <g transform="translate(360 666)" filter="url(#depth)"><circle r="179" fill="url(#halo)" opacity={glow}/><path d="M0-132Q-99-132-100-40Q-100 15-57 57Q-35 79-34 108H34Q35 79 57 57Q100 15 100-40Q99-132 0-132Z" fill="url(#coral)" stroke="#fff2dd" strokeWidth="8"/><path d="M-35 119H35M-29 138H29M-19 156H19" stroke="#fff2dd" strokeWidth="9" strokeLinecap="round"/><path d="M0-191V-165M-147-142L-127-123M147-142L127-123M-205-30H-174M205-30H174" stroke="#fbd686" strokeWidth="9" strokeLinecap="round"/></g>;}
function Team({f}:{f:number}){return <g transform="translate(0 32)"><g transform="translate(-153 82) scale(.68)"><Owner f={f+12}/></g><g transform="translate(153 82) scale(.68)"><Owner f={f+42} pose="thinking"/></g><path d="M215 625Q360 530 505 625" fill="none" stroke="#d7fff2" strokeWidth="7" strokeDasharray="8 16" opacity=".7"/><circle cx="360" cy="606" r="55" fill="url(#coral)" stroke="#fff1db" strokeWidth="5"/><path d="M335 606L352 623L388 583" fill="none" stroke="#fff" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round"/></g>;}
function Brand(){return <g><ellipse cx="360" cy="930" rx="303" ry="112" fill="#f5faf4" stroke="#d5fff3" strokeWidth="5" filter="url(#depth)"/><path d="M104 799Q360 704 616 799" fill="none" stroke="#9affeb" strokeWidth="5" opacity=".9"/><circle cx="110" cy="800" r="12" fill="url(#coral)"/><circle cx="610" cy="800" r="12" fill="url(#teal)"/></g>;}

export function SceneArt({kind,f}:{kind:string;f:number}){
 const bob=wave(f,.04,5);
 switch(kind){
  case 'hook': return <g transform={`translate(0 ${bob})`}><Paper x={143} y={614} r={-17}/><Paper x={575} y={662} r={15} color="#ffe0d2"/><path d="M120 520Q172 477 221 526M500 543Q557 490 609 541" fill="none" stroke="#ffb58e" strokeWidth="7" strokeDasharray="10 13"/><Owner f={f} pose="thinking"/><path d="M435 526Q495 471 550 512" fill="none" stroke="#ff8768" strokeWidth="6" markerEnd="url(#arrow)"/></g>;
  case 'friction': return <g transform={`translate(0 ${bob})`}><Paper x={152} y={630} r={-14}/><Paper x={570} y={596} r={18}/><Paper x={159} y={858} r={9} color="#ffdfd3"/><Owner f={f} pose="thinking"/><path d="M186 500C323 449 409 467 535 498" fill="none" stroke="#ffe8bb" strokeWidth="8" strokeDasharray="7 14"/><circle cx="182" cy="500" r="15" fill="#ff8367"/><circle cx="535" cy="498" r="15" fill="#ff8367"/></g>;
  case 'listen': return <g><Owner f={f}/><path d="M450 546Q532 500 573 544Q601 578 568 614L541 646L486 626Q441 614 441 577Z" fill="#fff7e9" stroke="#c9fff3" strokeWidth="5" filter="url(#depth)"/><circle cx="484" cy="578" r="7" fill="#079b9b"/><circle cx="512" cy="578" r="7" fill="#079b9b"/><circle cx="540" cy="578" r="7" fill="#f26349"/><path d="M95 674Q133 605 190 620" fill="none" stroke="#fff2d3" strokeWidth="5" strokeDasharray="6 11" opacity=".7"/></g>;
  case 'map': return <g><Dashboard f={f}/><Owner f={f+10}/></g>;
  case 'bottleneck': return <g><Flow f={f}/><path d="M262 593L291 627L262 661M458 593L429 627L458 661" fill="none" stroke="#ff8367" strokeWidth="8" strokeLinecap="round"/><circle cx="360" cy="627" r={34+Math.sin(f*.07)*4} fill="url(#coral)" opacity=".75"/></g>;
  case 'workflow': return <g><Flow f={f}/><path d="M226 838Q360 900 496 838" fill="none" stroke="#ffdf9c" strokeWidth="6" strokeDasharray="6 12"/><Owner f={f+30}/></g>;
  case 'ai': return <g><Dashboard f={f}/><Owner f={f+19}/>{Array.from({length:7},(_,i)=>{const a=i*Math.PI*2/7+f*.008,x=360+Math.cos(a)*230,y=625+Math.sin(a)*205;return <g key={i}><path d={`M360 625L${x} ${y}`} stroke="#dcfff4" strokeWidth="3" opacity=".55"/><circle cx={x} cy={y} r="11" fill={i%3===0?'url(#coral)':'url(#teal)'}/></g>;})}</g>;
  case 'implement': return <g><Magnifier f={f}/><g transform="translate(0 272) scale(.48)"><Owner f={f+43}/></g><path d="M165 881H555" stroke="#d7fff0" strokeWidth="7" strokeLinecap="round"/><circle cx="360" cy="881" r="14" fill="#ff8065"/></g>;
  case 'growth': return <g><Team f={f}/><path d="M161 859L256 779L324 813L448 694L525 728" fill="none" stroke="#fff0bf" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round"/><path d="M490 696L530 725L496 758" fill="none" stroke="#fff0bf" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round"/><Lightbulb f={f+18}/></g>;
  case 'brand': return <g><Brand/><circle cx={360+wave(f,.06,3)} cy="780" r="38" fill="url(#coral)" opacity=".94"/><path d="M343 789L355 775L366 784L378 769" fill="none" stroke="#fff2dc" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"/><circle cx="343" cy="789" r="3.5" fill="#fff2dc"/><circle cx="378" cy="769" r="3.5" fill="#fff2dc"/></g>;
  default:return <Owner f={f}/>;
 }
}
