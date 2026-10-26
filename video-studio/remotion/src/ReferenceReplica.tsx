import React from 'react';
import {AbsoluteFill, Audio, interpolate, staticFile, useCurrentFrame} from 'remotion';

/** Original Remotion artwork inspired by the supplied pixel-art reference.
 * Every visual is drawn here; the reference MP4 is never composited into output.
 */
const W = 716;
const H = 1274;
const CYAN = '#16d8fa';
const YELLOW = '#ffc02e';
const WHITE = '#f8f8f1';
const NAVY = '#071326';

type Scene = {start: number; end: number; title: string[]; caption: string; kind: string; tint?: string};
const scenes: Scene[] = [
  {start: 0, end: 116, title: ['STANFORD HA REGALADO', 'UN JARVIS'], caption: 'UN JARVIS', kind: 'intro'},
  {start: 104, end: 202, title: ['VIVE EN TU', 'ORDENADOR'], caption: 'SE LLAMA OPENJARVIS', kind: 'laptop'},
  {start: 190, end: 286, title: ['VIVE EN TU', 'ORDENADOR'], caption: 'EN TU ORDENADOR', kind: 'laptop'},
  {start: 274, end: 376, title: ['UNA LÍNEA', 'Y 3 MINUTOS'], caption: 'INSTALARLO ES PEGAR', kind: 'terminal'},
  {start: 364, end: 466, title: ['UNA LÍNEA', 'Y 3 MINUTOS'], caption: 'SOLO', kind: 'timer'},
  {start: 454, end: 560, title: ['GMAIL + CALENDARIO', 'PERMISO UNA VEZ'], caption: 'LUEGO LE DAS', kind: 'permissions'},
  {start: 548, end: 646, title: [], caption: 'Y CADA MAÑANA', kind: 'reveal'},
  {start: 634, end: 750, title: ['CADA MAÑANA', 'TE LO RESUME'], caption: 'TE RESUME EN', kind: 'inbox', tint: '#f49a45'},
  {start: 738, end: 836, title: ['CÓDIGO ABIERTO', 'SIN SUSCRIPCIÓN'], caption: 'LO MEJOR', kind: 'spotlight'},
  {start: 824, end: 922, title: ['CÓDIGO ABIERTO', 'SIN SUSCRIPCIÓN'], caption: 'PÚBLICO', kind: 'code'},
  {start: 910, end: 1008, title: ['CÓDIGO ABIERTO', 'SIN SUSCRIPCIÓN'], caption: 'SUSCRIPCIÓN', kind: 'subscribe'},
  {start: 996, end: 1094, title: ['UNA FORTUNA', 'CONTRA UNA LÍNEA'], caption: 'UNA LÍNEA', kind: 'scale'},
  {start: 1082, end: 1196, title: ['COMENTA', '«IA»'], caption: 'BIBLIOTECA DE RECURSOS', kind: 'library'},
  {start: 1184, end: 1303, title: ['COMENTA', '«IA»'], caption: 'ABRIENDO CORREOS', kind: 'mail'},
];

const px: React.CSSProperties = {shapeRendering: 'crispEdges', imageRendering: 'pixelated'};
const Rect: React.FC<{x:number;y:number;w:number;h:number;fill:string;stroke?:string;sw?:number}> = ({x,y,w,h,fill,stroke,sw=4}) => <rect x={x} y={y} width={w} height={h} fill={fill} stroke={stroke} strokeWidth={sw} style={px}/>;

const Human: React.FC<{x?:number;y?:number;scale?:number;frame:number}> = ({x=90,y=0,scale=1,frame}) => {
  const bob = Math.round(Math.sin(frame/7)*3);
  return <g transform={`translate(${x} ${y+bob}) scale(${scale})`} style={px}>
    <Rect x={0} y={22} w={70} h={54} fill="#9c6646" stroke="#4f352b"/>
    <Rect x={8} y={31} w={54} h={39} fill="#f0c298" stroke="#382c2a"/>
    <Rect x={12} y={40} w={18} h={13} fill="#27384a"/><Rect x={42} y={40} w={15} h={13} fill="#27384a"/>
    <Rect x={28} y={47} w={14} h={5} fill="#191c28"/><Rect x={26} y={59} w={22} h={5} fill="#b8463e"/>
    <Rect x={0} y={18} w={70} h={8} fill="#d39445"/><Rect x={4} y={76} w={62} h={30} fill="#7e492e" stroke="#302334"/>
    <Rect x={-5} y={101} w={78} h={8} fill="#d19d63"/>
  </g>;
};

const Robot: React.FC<{x?:number;y?:number;scale?:number;frame:number}> = ({x=0,y=0,scale=1,frame}) => {
  const bob = Math.round(Math.sin(frame/8+1)*5);
  return <g transform={`translate(${x} ${y+bob}) scale(${scale})`} style={px}>
    <Rect x={17} y={0} w={10} h={13} fill="#18c7e9"/><Rect x={0} y={14} w={44} h={38} fill="#147baa" stroke="#0b315b"/>
    <Rect x={6} y={22} w={12} h={10} fill="#18294b"/><Rect x={26} y={22} w={12} h={10} fill="#18294b"/>
    <Rect x={10} y={24} w={5} h={5} fill={CYAN}/><Rect x={29} y={24} w={5} h={5} fill={CYAN}/>
    <Rect x={16} y={39} w={13} h={5} fill="#ff685a"/><Rect x={4} y={53} w={9} h={7} fill="#2676a3"/><Rect x={31} y={53} w={9} h={7} fill="#2676a3"/>
  </g>;
};

const Laptop: React.FC<{x:number;y:number;frame:number;label?:string}> = ({x,y,frame,label='OpenJarvis'}) => {
  const glow = 0.68 + Math.sin(frame/11)*0.12;
  return <g transform={`translate(${x} ${y})`} style={px}>
    <Rect x={0} y={0} w={230} h={145} fill="#18283f" stroke="#64748a" sw={7}/><Rect x={11} y={11} w={208} h={122} fill="#061728"/>
    <text x={115} y={53} textAnchor="middle" fill={CYAN} fontFamily="monospace" fontSize="19" opacity={glow}>{label}</text>
    <Robot x={94} y={68} scale={0.75} frame={frame}/><path d="M-18 151H250l-24 18H5z" fill="#a8b2bf" stroke="#47566b" strokeWidth="5" style={px}/>
  </g>;
};

const Mail: React.FC<{x:number;y:number;scale?:number;angle?:number}> = ({x,y,scale=1,angle=0}) => <g transform={`translate(${x} ${y}) rotate(${angle}) scale(${scale})`} style={px}>
  <Rect x={0} y={0} w={58} h={42} fill="#f5f1df" stroke="#aab1bb" sw={3}/><path d="M2 4 29 25 56 4" fill="none" stroke="#e75853" strokeWidth="6" style={px}/>
 </g>;

function SceneArt({scene, local, global}: {scene:Scene;local:number;global:number}) {
  const floatY = Math.sin(local/9)*7;
  const laptop = (x=236,y=475,label?:string) => <Laptop x={x} y={y} frame={global} label={label}/>;
  switch(scene.kind) {
    case 'intro': return <>
      <Human x={86} y={530} frame={global}/><Robot x={445} y={492+floatY} scale={1.55} frame={global}/>
      <Rect x={192} y={596} w={326} h={24} fill="#996d48"/><Rect x={214} y={460} w={242} h={135} fill="#111e30" stroke="#b07e4f" sw={7}/>
      <Laptop x={246} y={442} frame={global} label="JARVIS"/>
      <Mail x={30} y={472+floatY} angle={-12}/><Mail x={535} y={456-floatY} angle={10}/>
    </>;
    case 'laptop': return <>
      <Human x={64} y={553} scale={0.8} frame={global}/>{laptop(202,443)}
      <rect x="189" y="425" width="258" height="206" rx="10" fill="none" stroke={CYAN} strokeWidth="4" strokeDasharray="10 10" opacity={0.35+0.4*Math.sin(local/10)}/>
      <Robot x={480} y={535+floatY} scale={0.8} frame={global}/>
    </>;
    case 'terminal': case 'timer': return <>
      <Human x={52} y={552} scale={0.8} frame={global}/>
      <g transform="translate(197 462)"><Rect x={0} y={0} w={365} h={175} fill="#0c1d30" stroke="#53647b" sw={7}/><Rect x={0} y={0} w={365} h={26} fill="#29405a"/>
        {[0,1,2,3,4].map((i)=><Rect key={i} x={24} y={49+i*22} w={90+(i%2)*75} h={5} fill={i===1?YELLOW:CYAN}/>)}</g>
      {scene.kind==='timer'&&<g transform="translate(337 338)"><circle cx="0" cy="0" r="58" fill="#f5f0dd"/><path d="M0 0V-58A58 58 0 0 1 0 58Z" fill="#ff7665"/><text x="0" y="92" fill={WHITE} textAnchor="middle" fontSize="24" fontFamily="monospace">1:49</text></g>}
    </>;
    case 'permissions': return <>
      <Human x={63} y={548} scale={0.8} frame={global}/>
      {[0,1].map(i=><g key={i} transform={`translate(${190+i*190} 410)`}><Rect x={0} y={0} w={150} h={150} fill="#f2f2e9" stroke="#aab4c5" sw={6}/>
        {i===0?<><path d="M10 10h62v62H10z" fill="#5188ef"/><path d="M78 10h62v62H78z" fill="#fb6154"/><path d="M10 78h62v62H10z" fill="#3cba76"/><path d="M78 78h62v62H78z" fill="#ffc943"/></>:<><circle cx="75" cy="75" r="54" fill="#fff" stroke="#5390ed" strokeWidth="12"/><path d="M75 21v54h54" fill="none" stroke="#4ab678" strokeWidth="12"/></>}
        <Rect x={42} y={150} w={66} h={37} fill="#ffbf24" stroke="#c98a16"/><path d="M58 150v-14a17 17 0 0 1 34 0v14" fill="none" stroke="#b98523" strokeWidth="9"/>
      </g>)}
      <Robot x={534} y={550} frame={global}/>
    </>;
    case 'reveal': return <><g opacity="0.42"><rect x="0" y="0" width={W} height={H} fill="#9da6bb"/></g><Human x={70} y={588} scale={0.85} frame={global}/><Robot x={492} y={586} scale={0.9} frame={global}/><Mail x={160} y={540} scale={0.7}/></>;
    case 'inbox': return <>
      {[0,1,2,3,4].map(i=><Mail key={i} x={25+i*60} y={538+(i%2)*19+floatY} scale={0.82} angle={-8+i*4}/>)}
      <Human x={204} y={532} frame={global}/><Robot x={478} y={549} scale={1.2} frame={global}/>
      <circle cx="602" cy="300" r="56" fill="#ffd53b"/><Rect x={527} y={354} w={120} h={64} fill="#fa5b52" stroke="#fa5b52"/><text x="587" y="400" fill="white" fontSize="42" fontWeight="900" textAnchor="middle">50</text>
    </>;
    case 'spotlight': return <>
      <path d="M205 315 520 640H110z" fill="#f8edb8" opacity="0.18"/><Robot x={310} y={548+floatY} scale={1.7} frame={global}/>
      <g opacity=".5">{[0,1,2,3,4].map(i=><circle key={i} cx={100+i*120} cy={400+(i%2)*65} r="4" fill={CYAN}/>)}</g>
    </>;
    case 'code': return <>
      <Laptop x={255} y={452} frame={global} label="</> PUBLIC"/>
      {[0,1,2,3,4,5,6].map(i=><g key={i}><Rect x={90+i*78} y={330+(i%3)*25} w={12} h={12} fill={CYAN}/><Rect x={105+i*78} y={330+(i%3)*25} w={28} h={4} fill="#3a8ca5"/></g>)}
      <Robot x={90} y={560} scale={0.9} frame={global}/>
    </>;
    case 'subscribe': return <>
      {[0,1,2].map(i=><g key={i} transform={`translate(${174+i*130} ${440+(i%2)*25}) rotate(${i===1?-12:10} 48 80)`}><Rect x={0} y={0} w={105} h={150} fill="#f5f3eb" stroke="#a8abb5" sw={5}/><Rect x={18} y={22} w={70} h={15} fill="#798ba2"/><path d="M8 20 96 130M96 18 8 132" stroke="#ee655c" strokeWidth="14"/></g>)}
      <Robot x={298} y={588} scale={0.95} frame={global}/>
    </>;
    case 'scale': return <>
      <Rect x={345} y={376} w={16} h={236} fill="#9e7040"/><path d="M210 401 493 335" stroke="#c28a43" strokeWidth="14"/><path d="M238 394 205 498M242 393 284 492M470 341 438 453M473 340 519 443" stroke="#b38952" strokeWidth="5"/>
      <path d="M174 499h140l-30 44h-82z" fill="#9b7144"/><path d="M408 452h140l-30 44h-82z" fill="#b4c3d4"/><Rect x={283} y={611} w={140} h={18} fill="#c09254"/>
      <text x="228" y="484" fill={YELLOW} fontSize="17" textAnchor="middle">1 FORTUNA</text><text x="480" y="438" fill={CYAN} fontSize="17" textAnchor="middle">1 LÍNEA</text>
      <Human x={58} y={560} scale={0.7} frame={global}/>
    </>;
    case 'library': return <>
      <Rect x={208} y={397} w={257} h={239} fill="#65442e" stroke="#bd8751" sw={9}/>
      {[0,1,2].map(row=><g key={row}>{[0,1,2,3].map(col=><g key={col}><Rect x={225+col*55} y={425+row*64} w={20} h={45} fill={['#22c7dc','#e85348','#ffc334','#55aa71'][(row+col)%4]}/><Rect x={247+col*55} y={430+row*64} w={17} h={40} fill="#e8d5ac"/></g>)}<Rect x={212} y={476+row*64} w={249} h={8} fill="#bc884d"/></g>)}
      <Robot x={110} y={557} scale={1.25} frame={global}/><Rect x={290} y={356} w={120} h={42} fill="#f6bd27" stroke="#3c2b26"/><text x="350" y="385" fill="#172238" fontSize="22" fontWeight="900" textAnchor="middle">GRATIS</text>
    </>;
    case 'mail': return <>
      <g transform={`translate(290 ${368+floatY})`}><path d="M0 40q-34-44 8-58 21-42 62-10 43-28 62 12 40 7 23 49z" fill="#7e8996"/>
        <Mail x={-95} y={78+Math.sin(local/10)*18} angle={-18}/><Mail x={144} y={96+Math.cos(local/12)*24} angle={14}/><Mail x={45} y={125+Math.sin(local/8)*15} angle={-6}/>
      </g>
      {[0,1,2,3,4,5].map(i=><Mail key={i} x={110+i*76} y={592+(i%2)*11+floatY} scale={0.82} angle={-5+i*2}/>)}
      <Robot x={300} y={539} scale={0.8} frame={global}/>
    </>;
    default: return null;
  }
}

const stars = Array.from({length:75},(_,i)=>({x:(i*97+29)%716,y:(i*173+41)%930,r:i%9===0?3:2,a:0.2+(i%5)*0.1}));
const Backdrop: React.FC<{frame:number;tint?:string}> = ({frame,tint}) => <>
  <AbsoluteFill style={{background: tint ? `linear-gradient(180deg,${tint} 0%,#27354e 54%,#071326 100%)` : 'linear-gradient(180deg,#071326 0%,#101d37 70%,#07101f 100%)'}}/>
  <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{position:'absolute',inset:0}}>{stars.map((s,i)=><circle key={i} cx={s.x} cy={s.y} r={s.r} fill={i%4===0?CYAN:'#d6e2ee'} opacity={s.a*(0.8+Math.sin(frame/12+i)*0.2)}/>)}</svg>
  <div style={{position:'absolute',left:0,right:0,top:881,height:5,background:'#263955',boxShadow:'0 5px 12px #020815'}}/>
</>;

function SceneLayer({scene,frame}: {scene:Scene;frame:number}) {
  const local = frame-scene.start;
  const fadeIn = interpolate(local,[0,14],[0,1],{extrapolateRight:'clamp'});
  const fadeOut = interpolate(frame,[scene.end-14,scene.end],[1,0],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const opacity = Math.min(fadeIn,fadeOut);
  const driftX = interpolate(local,[0,scene.end-scene.start],[16,-10]);
  return <AbsoluteFill style={{opacity,transform:`translateX(${driftX}px)`}}>
    <Backdrop frame={frame} tint={scene.tint}/>
    <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{position:'absolute',inset:0,overflow:'hidden'}}>
      <g transform="translate(-72 70) scale(1.2)">{SceneArt({scene,local,global:frame})}</g>
    </svg>
    {scene.title.length>0&&<div style={{position:'absolute',top:83,left:20,right:20,textAlign:'center',fontFamily:'Arial, sans-serif',fontWeight:900,letterSpacing:0.3,lineHeight:1.15,textShadow:'0 3px 0 #111827, 2px 2px 0 #111827'}}>
      <div style={{fontSize:27,color:WHITE}}>{scene.title[0]}</div>
      <div style={{fontSize:34,color:scene.title.length>1&&(scene.title[1].includes('JARVIS')||scene.title[1].includes('3 MINUTOS')||scene.title[1].includes('CONTRA'))?CYAN:YELLOW}}>{scene.title[1]}</div>
    </div>}
    <div style={{position:'absolute',top:911,left:20,right:20,textAlign:'center',fontFamily:'Arial,sans-serif',fontWeight:900,fontSize:22,color:WHITE,textShadow:'0 3px #080e19'}}>
      {scene.caption.split(' ').map((word,i)=><span key={`${word}-${i}`} style={{color:i===scene.caption.split(' ').length-1?CYAN:WHITE,marginRight:6}}>{word}</span>)}
    </div>
    <div style={{position:'absolute',top:972,left:0,right:0,textAlign:'center',fontFamily:'Arial,sans-serif',fontSize:12,color:'#8ca1ba'}}>◉ @sebastiankra.ia</div>
  </AbsoluteFill>;
}

export const ReferenceReplica: React.FC<{includeVoice?: boolean}> = ({includeVoice = false}) => {
  const frame = useCurrentFrame();
  const cameraScale = interpolate(frame,[0,1302],[1.015,1.045]);
  const cameraY = interpolate(frame,[0,1302],[0,-11]);
  return <AbsoluteFill style={{backgroundColor:NAVY,overflow:'hidden'}}>
    {includeVoice&&<Audio src={staticFile('sebastiankra-voz.mp3')} volume={1}/>}
    <AbsoluteFill style={{transform:`scale(${cameraScale}) translateY(${cameraY}px)`,transformOrigin:'center center'}}>
      {scenes.filter(s=>frame>=s.start&&frame<s.end).map(scene=><SceneLayer key={scene.kind+scene.start} scene={scene} frame={frame}/>)}
    </AbsoluteFill>
  </AbsoluteFill>;
};

export const referenceReplicaProps = {durationInFrames: 1303};
