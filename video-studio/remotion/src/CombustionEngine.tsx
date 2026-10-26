import React from 'react';
import {AbsoluteFill, Audio, interpolate, staticFile, useCurrentFrame} from 'remotion';

const W = 716;
const H = 1274;
const CYAN = '#20d7f4';
const BLUE = '#43a8ff';
const YELLOW = '#ffc340';
const ORANGE = '#ff7650';
const WHITE = '#fff8e9';

const steps = [
  {name:'ADMISIÓN', kicker:'1 · ENTRA LA MEZCLA', detail:'El pistón baja y aspira aire + combustible.', color:BLUE},
  {name:'COMPRESIÓN', kicker:'2 · TODO SE COMPRIME', detail:'El pistón sube. Las dos válvulas se cierran.', color:YELLOW},
  {name:'COMBUSTIÓN', kicker:'3 · EL GOLPE DE POTENCIA', detail:'La bujía enciende la mezcla y empuja el pistón.', color:ORANGE},
  {name:'ESCAPE', kicker:'4 · SALEN LOS GASES', detail:'El pistón sube y expulsa los gases quemados.', color:CYAN},
];

const PixelRect: React.FC<{x:number;y:number;w:number;h:number;fill:string;stroke?:string;sw?:number}> = ({x,y,w,h,fill,stroke,sw=5}) =>
  <rect x={x} y={y} width={w} height={h} fill={fill} stroke={stroke} strokeWidth={sw} shapeRendering="crispEdges"/>;

const RobotGuide: React.FC<{frame:number}> = ({frame}) => {
  const bob = Math.round(Math.sin(frame/8)*5);
  return <g transform={`translate(584 ${830+bob})`} shapeRendering="crispEdges">
    <PixelRect x={17} y={0} w={10} h={14} fill={CYAN}/>
    <PixelRect x={0} y={15} w={44} h={42} fill="#147baa" stroke="#0b315b"/>
    <PixelRect x={6} y={23} w={12} h={10} fill="#152640"/><PixelRect x={26} y={23} w={12} h={10} fill="#152640"/>
    <PixelRect x={9} y={25} w={6} h={5} fill={CYAN}/><PixelRect x={29} y={25} w={6} h={5} fill={CYAN}/>
    <PixelRect x={15} y={41} w={15} h={6} fill="#ff685a"/><PixelRect x={4} y={58} w={10} h={8} fill="#2676a3"/><PixelRect x={30} y={58} w={10} h={8} fill="#2676a3"/>
  </g>;
};

const stars = Array.from({length:86},(_,i)=>({x:(i*97+23)%W,y:(i*173+19)%H,r:i%8===0?3:2,a:0.15+(i%5)*0.075}));

function EngineDiagram({frame,stage,progress,showIntro,showRecap}: {frame:number;stage:number;progress:number;showIntro:boolean;showRecap:boolean}) {
  const phase = steps[stage] ?? steps[0];
  // Each of the four strokes turns the crank 180 degrees: a complete cycle is 720 degrees.
  const theta = stage*Math.PI + progress*Math.PI;
  const pistonTop = 438;
  const stroke = 215;
  const pistonY = pistonTop + (stage%2===0 ? progress : 1-progress)*stroke;
  const crankX = 360 + 106*Math.sin(theta);
  const crankY = 761 - 106*Math.cos(theta);
  const intakeOpen = stage===0 && progress<0.91;
  const exhaustOpen = stage===3 && progress>0.08;
  const flame = stage===2 ? Math.max(0.18,Math.sin(progress*Math.PI)) : 0;
  const cycleRepeat = showRecap || frame>1500;
  const pulse = 0.8+Math.sin(frame/5)*0.16;

  return <svg width="100%" height="100%" viewBox={`0 0 ${W} ${H}`} style={{position:'absolute',inset:0}}>
    <defs>
      <linearGradient id="cylinderFill" x1="0" x2="1"><stop offset="0" stopColor="#132d48"/><stop offset="0.5" stopColor="#0a192c"/><stop offset="1" stopColor="#1d3b59"/></linearGradient>
      <filter id="softGlow"><feGaussianBlur stdDeviation="8" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    </defs>
    <g opacity="0.86">{stars.map((s,i)=><circle key={i} cx={s.x} cy={s.y} r={s.r} fill={i%4===0?CYAN:'#dbe8f4'} opacity={s.a*(0.8+Math.sin(frame/13+i)*0.2)}/>)}</g>
    <path d="M0 911H716" stroke="#314665" strokeWidth="5"/><path d="M0 919H716" stroke="#091426" strokeWidth="8"/>

    {/* Intake and exhaust manifolds */}
    <path d="M190 464H269V407H306" fill="none" stroke={BLUE} strokeWidth="22" strokeLinejoin="miter"/>
    <path d="M412 407H456V464H522" fill="none" stroke="#ed6555" strokeWidth="22" strokeLinejoin="miter"/>
    <path d="M204 464H268" stroke="#a7dcff" strokeWidth="4" strokeDasharray="9 10" opacity={intakeOpen?pulse:0.2}/>
    <path d="M455 464H512" stroke="#ffc1a9" strokeWidth="4" strokeDasharray="9 10" opacity={exhaustOpen?pulse:0.2}/>
    <text x="178" y="440" fill={BLUE} fontSize="17" fontWeight="800" textAnchor="middle">AIRE + GASOLINA</text>
    <text x="532" y="440" fill="#ff9880" fontSize="17" fontWeight="800" textAnchor="middle">GASES</text>
    {[0,1,2].map(i=><g key={i} opacity={intakeOpen?0.9:0.12}>
      <path d={`M${209+i*22} 471h14l-7 13z`} fill={BLUE}/>
    </g>)}
    {[0,1,2].map(i=><circle key={i} cx={488+i*19} cy={427-(frame%24)*1.5} r={5+i%2*2} fill="#ff8e6c" opacity={exhaustOpen?0.8:0.1}/>) }

    {/* Engine block and cylinder cutaway */}
    <path d="M231 354H486V821H231z" fill="#15243a" stroke="#71829a" strokeWidth="9"/>
    <path d="M269 383H448V736H269z" fill="url(#cylinderFill)" stroke="#8da4ba" strokeWidth="8"/>
    <path d="M287 398H430" stroke="#d3e0e9" strokeWidth="8"/>
    <text x="358" y="347" fill="#a9bdd0" fontSize="16" textAnchor="middle" letterSpacing="2">CILINDRO</text>

    {/* Valve heads and stems: the blue intake valve or red exhaust valve opens for its stroke. */}
    <g transform={intakeOpen?'translate(0 12)':''}>
      <path d="M307 373V408" stroke={BLUE} strokeWidth="10"/><path d="M293 409H321" stroke={BLUE} strokeWidth="12"/>
    </g>
    <g transform={exhaustOpen?'translate(0 12)':''}>
      <path d="M412 373V408" stroke="#ef7460" strokeWidth="10"/><path d="M398 409H426" stroke="#ef7460" strokeWidth="12"/>
    </g>
    <text x="307" y="366" fill={BLUE} fontSize="12" textAnchor="middle">ADM.</text><text x="412" y="366" fill="#ef7460" fontSize="12" textAnchor="middle">ESC.</text>

    {/* Spark plug and controlled ignition */}
    <path d="M359 345V402" stroke="#bdc9d5" strokeWidth="10"/><path d="M349 347H369" stroke="#f3d36a" strokeWidth="7"/>
    {stage===2&&<g filter="url(#softGlow)" opacity={flame}>
      <path d="M360 419 340 455 354 451 344 484 378 444 365 448 378 421z" fill={YELLOW}/>
      <circle cx="358" cy="475" r="58" fill={ORANGE} opacity="0.22"/>
    </g>}

    {/* Compression charge in the chamber */}
    {(stage===1||stage===0)&&Array.from({length:16},(_,i)=><circle key={i} cx={294+(i*37)%111} cy={420+((i*53+Math.floor(frame/5)*3)%Math.max(32,pistonY-435))} r={3+(i%3)} fill={stage===0?BLUE:YELLOW} opacity={stage===0?0.5:0.62}/>)}

    {/* Reciprocating piston, connecting rod, crank pin and flywheel */}
    <path d={`M360 ${pistonY+67} L${crankX} ${crankY}`} stroke="#d9e4ed" strokeWidth="25"/>
    <path d={`M360 ${pistonY+67} L${crankX} ${crankY}`} stroke="#5d7289" strokeWidth="11"/>
    <rect x="280" y={pistonY} width="160" height="72" fill="#a9b8c7" stroke="#f4f1df" strokeWidth="7" shapeRendering="crispEdges"/>
    <path d={`M285 ${pistonY+13}H435M285 ${pistonY+23}H435`} stroke="#637991" strokeWidth="6"/>
    <circle cx={crankX} cy={crankY} r="24" fill="#ffc340" stroke="#fff1c2" strokeWidth="7"/>
    <circle cx="360" cy="761" r="101" fill="#101c30" stroke="#93a3b7" strokeWidth="15"/>
    <circle cx="360" cy="761" r="22" fill="#ffc340" stroke="#fff1c2" strokeWidth="6"/>
    <path d={`M360 761 360 ${pistonY+67}`} stroke="#8295aa" strokeWidth="7" strokeDasharray="9 8" opacity="0.75"/>
    <text x="360" y="889" fill="#c0ccda" fontSize="14" fontWeight="700" textAnchor="middle" letterSpacing="2">CIGÜEÑAL · GIRO CONTINUO</text>

    {/* Torque trail links the piston movement to a usable rotation. */}
    <path d="M446 756a86 86 0 0 1-118 77" fill="none" stroke={YELLOW} strokeWidth="7" strokeDasharray="10 9" opacity={0.45+0.3*Math.sin(frame/7)}/>
    <path d="m330 827-5 17 19-4" fill="none" stroke={YELLOW} strokeWidth="7"/>
    {cycleRepeat&&<g transform={`translate(${interpolate(frame,[1270,1799],[465,500],{extrapolateLeft:'clamp',extrapolateRight:'clamp'})} 738)`}>
      <path d="M0 0h92" stroke={YELLOW} strokeWidth="9"/><path d="m92-18 28 18-28 18z" fill={YELLOW}/>
      <g transform="translate(130 -46)"><circle cx="38" cy="44" r="39" fill="#202d42" stroke="#8594a8" strokeWidth="8"/><circle cx="38" cy="44" r="11" fill={YELLOW}/><path d="M38 5v78M0 44h76" stroke="#8594a8" strokeWidth="6"/></g>
      <text x="82" y="91" fill={CYAN} fontSize="15" textAnchor="middle">A LAS RUEDAS</text>
    </g>}
    <RobotGuide frame={frame}/>
  </svg>;
}

export const CombustionEngine: React.FC = () => {
  const frame = useCurrentFrame();
  const introEnd = 180;
  // Boundaries follow the word timestamps exported by Edge TTS so each labeled
  // stroke changes with its spoken explanation.
  const strokeEnds = [443,677,1065,1361];
  const strokeStarts = [180,443,677,1065];
  const cycleEnd = strokeEnds[3];
  const recapEnd = 1659;
  const rawStage = strokeEnds.findIndex(end=>frame<end);
  const stage = frame < introEnd ? 0 : rawStage < 0 ? 3 : rawStage;
  const progress = frame < introEnd ? 0 : interpolate(frame,[strokeStarts[stage],strokeEnds[stage]],[0,1],{extrapolateLeft:'clamp',extrapolateRight:'clamp'});
  const showIntro = frame<introEnd;
  const showRecap = frame>=cycleEnd&&frame<recapEnd;
  const showOutro = frame>=recapEnd;
  const step = steps[stage];
  const phaseTitle = showIntro?'¿CÓMO SE MUEVE UN MOTOR?':showOutro?'DEL PISTÓN A LAS RUEDAS':showRecap?'4 TIEMPOS · 2 VUELTAS':step.name;
  const phaseKicker = showIntro?'EXPLOSIONES CONTROLADAS':showOutro?'ENERGÍA EN MOVIMIENTO':showRecap?'UN CICLO COMPLETO':step.kicker;
  const phaseDetail = showIntro?'Una mezcla de aire y gasolina se convierte en giro.':showOutro?'El cigüeñal entrega el giro a la transmisión.':showRecap?'Cada cilindro da potencia una vez cada dos giros.':step.detail;
  const phaseColor = showIntro?CYAN:showOutro?YELLOW:showRecap?CYAN:step.color;
  const titleIn = interpolate(frame,[0,18],[0,1],{extrapolateRight:'clamp'});
  const globalZoom = interpolate(frame,[0,1799],[1.015,1.035]);
  const barProgress = Math.min(1,Math.max(0,frame/1800));

  return <AbsoluteFill style={{backgroundColor:'#071326',overflow:'hidden',fontFamily:'Arial, sans-serif'}}>
    <Audio src={staticFile('motor-combustion-voz.mp3')} volume={1}/>
    <AbsoluteFill style={{transform:`scale(${globalZoom})`,transformOrigin:'center center'}}>
      <EngineDiagram frame={frame} stage={stage} progress={progress} showIntro={showIntro} showRecap={showRecap}/>
    </AbsoluteFill>
    <div style={{position:'absolute',top:67,left:24,right:24,textAlign:'center',opacity:titleIn,textShadow:'0 4px 0 #101827, 2px 2px 0 #101827'}}>
      <div style={{fontSize:20,fontWeight:900,letterSpacing:2,color:'#afc0d1'}}>{phaseKicker}</div>
      <div style={{fontSize:35,fontWeight:900,letterSpacing:0.2,lineHeight:1.2,color:phaseColor,marginTop:8}}>{phaseTitle}</div>
    </div>
    <div style={{position:'absolute',left:32,right:32,top:962,textAlign:'center',fontSize:25,fontWeight:800,lineHeight:1.35,color:WHITE,textShadow:'0 3px #111827'}}>{phaseDetail}</div>
    <div style={{position:'absolute',left:26,right:26,top:1044,display:'flex',justifyContent:'space-between',fontSize:15,fontWeight:900,letterSpacing:0.8}}>
      {steps.map((s,i)=><div key={s.name} style={{color:!showIntro&&!showOutro&&!showRecap&&i===stage?s.color:'#8494a8',borderBottom:`4px solid ${!showIntro&&!showOutro&&!showRecap&&i===stage?s.color:'#304057'}`,paddingBottom:8}}>{i+1}. {['ADM.','COMP.','POT.','ESC.'][i]}</div>)}
    </div>
    <div style={{position:'absolute',left:0,right:0,bottom:48,textAlign:'center',fontSize:14,fontWeight:700,letterSpacing:2,color:'#8ea1b9'}}>MOTOR DE GASOLINA · CICLO DE CUATRO TIEMPOS</div>
    <div style={{position:'absolute',left:0,right:0,bottom:0,height:7,background:'#172941'}}><div style={{height:'100%',width:`${barProgress*100}%`,background:phaseColor,boxShadow:`0 0 10px ${phaseColor}`}}/></div>
  </AbsoluteFill>;
};

export const combustionEngineProps = {durationInFrames:1800};
