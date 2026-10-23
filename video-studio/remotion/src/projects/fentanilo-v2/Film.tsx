import React, {useEffect, useState} from 'react';
import {AbsoluteFill, Audio, Sequence, cancelRender, continueRender, delayRender, staticFile, useCurrentFrame} from 'remotion';
import timelineData from './timeline.json';
import {ArtDefs, Backdrop, Brain, Cup, Face, Headphones, Joy, Key, Label, Lungs, Pain, Person, Receptor, Spark, clamp, ease, mix, seeded, wave} from './art';

export const timeline = timelineData;
type Scene = typeof timeline.scenes[number];

function Orbit({f, count=12, radius=250, color='cyan'}: {f:number;count?:number;radius?:number;color?:'cyan'|'orange'}) {
  return <g>{Array.from({length:count},(_,i)=>{
    const angle=i/count*Math.PI*2+f*.003;
    return <g key={i} opacity={.45+seeded(i)*.5} transform={`translate(${360+Math.cos(angle)*radius} ${720+Math.sin(angle)*radius*1.2}) rotate(${angle*180/Math.PI+90})`}><Key f={f} scale={.22+seeded(i)*.08} color={color}/></g>;
  })}</g>;
}

function Neuron({f}: {f:number}) {
  return <g transform={`translate(360 660) scale(${1+ease(f/130)*.08})`}>
    {Array.from({length:9},(_,i)=>{
      const angle=i*40-100;
      const phase=((f*1.6+i*17)%110)/110;
      return <g key={i} transform={`rotate(${angle})`}>
        <path d="M60 0 C130-60 167 50 218 0 S286-35 342-20" stroke="#167eaf" strokeWidth="12" fill="none"/>
        <path d="M60-3 C130-63 167 47 218-3 S286-38 342-23" stroke="#46d9dd" strokeWidth="7" fill="none"/>
        <path d="M218-3 Q229-58 274-76 M289-28 Q313 19 351 22" stroke="#39b9c9" strokeWidth="5" fill="none" strokeLinecap="round"/>
        <circle cx="274" cy="-76" r="7" fill="#70e9e6"/><circle cx="351" cy="22" r="6" fill="#70e9e6"/>
        <circle cx={mix(68,342,phase)} cy={Math.sin(phase*Math.PI*3)*-16} r="8" fill="#fff5a2" opacity={Math.sin(phase*Math.PI)}/>
      </g>;
    })}
    <circle r="155" fill="url(#aura)"/>
    <path d="M-74-51 Q-35-94 9-73 Q72-89 86-21 Q109 36 52 73 Q-4 104-57 63 Q-108 19-74-51" fill="#1896b8"/>
    <path d="M-77-56 Q-35-99 9-78 Q72-94 83-27 Q105 30 49 65 Q-4 96-57 58 Q-108 13-77-56" fill="url(#cyan)"/>
    <circle r="41" fill="#248baf"/><circle r="29" fill="#5be2de"/><circle r="18" fill="#34b4c6"/>
    <ellipse cx="-36" cy="-42" rx="15" ry="10" fill="#bcfff6" opacity=".6"/>
    {[0,1,2].map(i=><Receptor key={i} x={Math.cos(i*2.1)*70} y={Math.sin(i*2.1)*66} scale={.18} active={.3}/>) }
  </g>;
}

function Pill({f,split}: {f:number;split:number}) {
  return <g transform={`translate(360 ${692+wave(f,.035,6)}) rotate(${wave(f,.025,3)})`}>
    {[0,1,2].map(i=><path key={i} d="M-164-124 Q-217-33-164 106 Q-93 200 62 163 Q209 118 177-45 Q151-189 15-181 Q-95-211-164-124" fill="#9e6fe6" opacity={.09+i*.03} transform={`scale(${1+i*.13}) rotate(${f*.05+i*30})`}/>)}
    <g transform={`translate(${-split*79} ${split*9}) rotate(${-split*12})`}>
      <path d="M-8-135 A135 135 0 0 0-8 135 L-8-135" fill="#cfbae7" transform="translate(0 13)"/>
      <path d="M-8-135 A135 135 0 0 0-8 135 L-8-135" fill="#fff0fc"/>
      <path d="M-18-118 A118 118 0 0 0-18 118" stroke="#e7d6f6" strokeWidth="6" fill="none"/>
      <path d="M-87-9 Q-71-29-53-9 M-68 54 Q-39 78-15 54" stroke="#b99bcc" strokeWidth="8" fill="none" strokeLinecap="round"/>
    </g>
    <g transform={`translate(${split*79} ${split*9}) rotate(${split*12})`}>
      <path d="M8-135 A135 135 0 0 1 8 135 L8-135" fill="#cfbae7" transform="translate(0 13)"/>
      <path d="M8-135 A135 135 0 0 1 8 135 L8-135" fill="#fff0fc"/>
      <path d="M53-9 Q71-29 87-9 M15 54 Q39 78 68 54" stroke="#b99bcc" strokeWidth="8" fill="none" strokeLinecap="round"/>
    </g>
    {split>.1&&<g opacity={split}>
      <circle r="110" fill="url(#warm-aura)"/>
      {Array.from({length:22},(_,i)=><circle key={i} cx={(seeded(i+12)-.5)*85} cy={(seeded(i+41)-.5)*150+wave(f,.07,4,i)} r={3+seeded(i)*4} fill={i%2?'#ffad4e':'#f989c8'}/>)}
    </g>}
  </g>;
}

function SceneArt({scene, f}: {scene:Scene;f:number}) {
  const enter=ease(f/17);
  switch(scene.id) {
    case 'hook': {
      const bliss=ease((f-30)/15);
      return <>
        <g opacity={bliss}><Backdrop palette="gold" f={f}/></g>
        {bliss<.8&&<Person f={f} pose="pain" y={740} scale={.93} opacity={1-bliss}/>}
        {bliss>0&&<Person f={f} pose="float" y={760} scale={.93} opacity={bliss}/>}
        <g opacity={bliss*.7}>{[0,1,2,3].map(i=><Spark key={i} x={140+i*145} y={460+(i%2)*440} size={15+wave(f,.09,5,i)}/>)}</g>
        <Label x={360} y={1140} text="LA MISMA LLAVE. DOS EFECTOS." size={20}/>
      </>;
    }
    case 'balance': {
      const reveal=ease(f/45);
      return <>
        <g opacity={reveal}>
          <path d="M0 330 L383 330 318 1150 H0Z" fill="#1665a8" opacity=".6"/>
          <path d="M383 330 H720 V1150 H318Z" fill="#feb642" opacity=".27"/>
          {Array.from({length:10},(_,i)=><path key={i} d={`M194 710 L${-150+i*80} 330 H${-115+i*80}Z`} fill="#64cefa" opacity={.12}/>) }
          <path d="M383 330 318 1150" stroke="#e2e2fa" strokeWidth="3" opacity=".6"/>
          <circle cx="527" cy="720" r="210" fill="url(#warm-aura)"/>
        </g>
        <Pain f={f} x={mix(310,190,enter)} y={715+wave(f,.055,9)} scale={mix(.2,1.21,enter)}/>
        <Joy f={f} x={mix(410,530,enter)} y={715+wave(f,.055,9,2)} scale={mix(.2,1.21,enter)}/>
        <Label x={190} y={951} text="DOLOR" color="#8beaff"/><Label x={530} y={951} text="PLACER" color="#ffe49d"/>
      </>;
    }
    case 'neuron': return <>
      <Neuron f={f}/>
      <Label x={360} y={1040} text="NEURONA"/>
      <text x="360" y="1090" textAnchor="middle" fill="#b4e8ee" fontSize="22">Pequeños receptores. Grandes efectos.</text>
    </>;
    case 'receptor': {
      const insertion=ease((f-40)/33), activation=ease((f-70)/30);
      const painSize=mix(.83,.36,activation), joySize=mix(.75,1.15,activation);
      return <>
        <Receptor x={360} y={540} scale={1.37} active={activation}/>
        <path d="M275 641 Q247 787 183 906 M445 641 Q474 787 537 906" stroke="#a2e9eb" strokeWidth="3" strokeDasharray="6 8" fill="none" opacity=".6"/>
        <Pain f={f} x={183} y={925} scale={painSize}/><Joy f={f} x={537} y={925} scale={joySize}/>
        <g opacity={ease((f-25)/12)}><Key x={mix(840,411,insertion)} y={540} scale={1.13} angle={mix(-12,0,insertion)+wave(f,.07,activation*2)} color="purple"/></g>
        <Label x={360} y={737} text="RECEPTOR OPIOIDE" size={21}/>
        <Label x={183} y={1090} text="DOLOR ↓" color="#9cefff"/><Label x={537} y={1090} text="BIENESTAR ↑" color="#ffe7a4"/>
        <g opacity={activation}>{[0,1,2,3].map(i=><Spark key={i} x={180+i*120} y={410+(i%2)*250} size={10+wave(f,.07,5,i)} />)}</g>
      </>;
    }
    case 'endorphins': {
      const relief=ease((f-scene.frames*.62)/24);
      return <>
        <ellipse cx="360" cy="1110" rx="140" ry="27" fill="#110c2a" opacity=".3"/>
        <Person f={f} pose={relief>.5?'relief':'pain'} y={755} scale={.91}/>
      </>;
    }
    case 'potency': {
      const comparison=ease((f-50)/35);
      return <>
        <circle cx="365" cy="630" r="250" fill="url(#warm-aura)" opacity=".23"/>
        <Key x={318} y={610+wave(f,.04,7)} color="orange" scale={mix(.7,1.85,enter)} face f={f}/>
        <Label x={360} y={760} text="FENTANILO" color="#ffd48a"/>
        <g opacity={comparison} transform={`translate(0 ${mix(30,0,comparison)})`}>
          <text x="360" y="445" textAnchor="middle" fill="#ffd474" fontWeight="850" fontSize="89">50–100×</text>
          <text x="360" y="489" textAnchor="middle" fill="#e4d5f6" fontSize="23">más potente que la morfina</text>
          <Key x={345} y={958} color="cyan" scale={.45}/>
          <Label x={360} y={1028} text="MORFINA" size={20} color="#afeafa"/>
          <path d="M137 840 H583" stroke="#d2b8ee" strokeWidth="2" opacity=".2"/>
        </g>
      </>;
    }
    case 'flood': return <>
      <circle cx="360" cy="710" r={270+wave(f,.035,25)} fill="url(#aura)"/>
      <Person f={f} pose="float" y={760} scale={.73}/>
      <Orbit f={f} count={14} radius={256} color="orange"/>
      {Array.from({length:10},(_,i)=>{
        const angle=i/10*Math.PI*2; const active=ease((f-i*3)/18);
        return <Receptor key={i} x={360+Math.cos(angle)*195} y={730+Math.sin(angle)*298} scale={.22} active={active}/>;
      })}
      <Label x={360} y={1144} text="ACTIVACIÓN INTENSA" color="#9cfff4"/>
    </>;
    case 'coffee': return <g transform={`translate(360 690) scale(${mix(.82,1,enter)}) translate(-360 -690)`}><Cup f={f}/>{[0,1,2].map(i=><Spark key={i} x={135+i*210} y={430+(i%2)*450} size={12+wave(f,.1,5,i)}/>)}</g>;
    case 'music': return <Headphones f={f}/>;
    case 'pain': {
      const vanish=ease((f-24)/30);
      return <>
        <g opacity={1-vanish}><Pain f={f} x={360} y={710} scale={1.55*(1-vanish)}/></g>
        {Array.from({length:24},(_,i)=>{
          const a=i/24*Math.PI*2,r=mix(70,210,vanish);
          return <Spark key={i} x={360+Math.cos(a)*r} y={710+Math.sin(a)*r} size={4+seeded(i)*9} opacity={Math.sin(vanish*Math.PI)}/>;
        })}
        <Label x={360} y={1020} text="EL DOLOR DISMINUYE" color="#fff0c3"/>
      </>;
    }
    case 'breathing':
    case 'slow': {
      const slow=scene.id==='slow'?ease((f-25)/(scene.frames-65)):0;
      const stopped=slow>.95;
      return <>
        <Brain f={f} x={360} y={450} scale={.87} stopped={stopped}/>
        <Lungs f={f} y={886} scale={1.1} slow={slow}/>
        <Receptor x={360} y={565} scale={.18} active={slow}/>
        <Label x={360} y={1147} text={scene.id==='slow'?'LA RESPIRACIÓN PUEDE DETENERSE':'CEREBRO → RESPIRACIÓN'} color={scene.id==='slow'?'#ffb5d3':'#abfff5'} size={scene.id==='slow'?20:22}/>
        {scene.id==='slow'&&<g opacity={ease(f/20)}><Key x={438} y={565} color="orange" scale={.33}/><path d={`M95 1090 H150 L170 ${1090-(1-slow)*22} 190 ${1090+(1-slow)*18} 210 1090 H295 L315 ${1090-(1-slow)*22} 335 ${1090+(1-slow)*18} 355 1090 H625`} stroke={stopped?'#d6b1e5':'#78e4dd'} strokeWidth="3" fill="none" opacity=".7"/></g>}
      </>;
    }
    case 'tiny': {
      const drop=ease((f-20)/35);
      return <>
        <g transform={`translate(360 ${570+wave(f,.04,5)}) rotate(22)`}>
          <rect x="-45" y="-125" width="90" height="148" rx="19" fill="#e5e2f7"/>
          <path d="M-28-104 H27 V0 H-28Z" fill="#fef8fe"/>
          <path d="M-45 0 H45 V31 Q0 51-45 31Z" fill="#aaa7c6"/>
          {[-1,0,1].map(i=><circle key={i} cx={i*21} cy="24" r="4" fill="#605879"/>)}
        </g>
        <ellipse cx="360" cy="879" rx="179" ry="39" fill="#15112f"/>
        <path d="M181 879 Q180 941 360 946 Q540 941 539 879" fill="#473266"/>
        <ellipse cx="360" cy="879" rx="178" ry="34" fill="#241741"/>
        {Array.from({length:12},(_,i)=><rect key={i} x={339+seeded(i)*42} y={mix(611,864+seeded(i)*13,clamp(drop*1.4-i*.04))} width={5+seeded(i)*5} height="6" rx="2" fill="#fbf2ff" transform={`rotate(${i*31} ${360} ${870})`}/>)}
        <Label x={360} y={1030} text="POCO NO SIGNIFICA SEGURO" color="#ffcee3" size={21}/>
        <text x="360" y="1090" textAnchor="middle" fill="#c5b3da" fontSize="21">No existe una cantidad segura universal.</text>
      </>;
    }
    case 'fall': {
      const dim=ease(f/(scene.frames*.65));
      return <>
        <rect width="720" height="1280" fill="#110f29" opacity={dim*.5}/>
        <Person f={f} pose="faint" x={360} y={735} scale={.85}/>
        {Array.from({length:10},(_,i)=>{const a=i/10*Math.PI*2;return <Receptor key={i} x={360+Math.cos(a)*240} y={735+Math.sin(a)*320} scale={.22} active={.5*(1-dim)}/>;})}
        <Label x={360} y={1145} text="ALIVIO Y RIESGO COMPARTEN RECEPTOR" size={18}/>
      </>;
    }
    case 'pill': return <>
      <Pill f={f} split={ease((f-38)/40)}/>
      <Label x={360} y={1003} text="NO PUEDES SABERLO CON SOLO MIRAR" size={18}/>
    </>;
    case 'rescue': {
      const reveal=ease((f-24)/20);
      return <>
        <circle cx="360" cy="565" r="200" fill="url(#aura)"/>
        <g transform={`translate(360 555) scale(${mix(.82,1,enter)})`}>
          <circle r="116" fill="#0c6072"/><circle cy="-6" r="112" fill="#b8f1dd"/>
          <path d="M-23-77 H23 V-29 H71 V17 H23 V65 H-23 V17 H-71 V-29 H-23Z" fill="#147f79"/>
        </g>
        <text x="360" y="770" textAnchor="middle" fill="#f7ffed" fontSize="51" fontWeight="850">Cada segundo cuenta.</text>
        <g opacity={reveal}>
          <text x="360" y="842" textAnchor="middle" fill="#c0fff0" fontSize="31" fontWeight="750">Llama a emergencias.</text>
          <path d="M176 886 H544" stroke="#9cdfda" opacity=".3"/>
          <text x="360" y="944" textAnchor="middle" fill="#edfff7" fontSize="30" fontWeight="700">La naloxona puede revertir</text>
          <text x="360" y="983" textAnchor="middle" fill="#edfff7" fontSize="30" fontWeight="700">una sobredosis de opioides.</text>
          <Label x={360} y={1120} text="COMPARTE INFORMACIÓN QUE CUIDA" size={19}/>
        </g>
      </>;
    }
    default: return null;
  }
}

function EndorphinOverlay({f,scene}: {f:number;scene:Scene}) {
  const relief=ease((f-scene.frames*.62)/24);
  return <>
    {[0,1,2].map(i=>{
      const p=ease((f-28-i*25)/60);
      const startX=[156,545,174][i],startY=[550,665,850][i];
      return <g key={i} opacity={(1-ease((p-.92)/.08))*.95}><Key x={mix(startX,415,p)} y={mix(startY,958,p)-Math.sin(p*Math.PI)*58} scale={.42} color="cyan" angle={wave(f,.05,7,i)}/></g>;
    })}
    <circle cx="415" cy="953" r={90} fill="url(#aura)" opacity={Math.sin(relief*Math.PI)}/>
    <Label x={360} y={1150} text="ENDORFINAS · REGULACIÓN NATURAL" size={20} color="#9bf9f0"/>
  </>;
}

function Captions({scene,f}: {scene:Scene;f:number}) {
  const time=f/30;
  const words=scene.words;
  let current=words.findIndex(w=>time>=w.start&&time<w.end);
  if(current<0) current=Math.max(0, words.findIndex(w=>w.start>time)-1);
  if(time>=words[words.length-1].end) current=words.length-1;
  // Greedy groups capped by character count prevent long Spanish words clipping.
  const groups:{word:string;start:number;end:number}[][]=[];
  for(const word of words){
    const last=groups[groups.length-1];
    if(!last||last.length>=5||last.map(w=>w.word).join(' ').length+word.word.length>30)groups.push([word]);
    else last.push(word);
  }
  const active=words[current];
  const group=groups.find(g=>g.includes(active))||groups[0];
  const pop=ease((time-group[0].start)*12);
  return <div style={{position:'absolute',left:48,top:174,width:624,textAlign:'center',fontSize:35,lineHeight:1.32,fontWeight:750,letterSpacing:-.6,transform:`translateY(${mix(6,0,pop)}px)`,color:'#fff8f1',textShadow:'0 3px 15px rgba(20,10,42,.4)'}}>
    {group.map((w,i)=><React.Fragment key={`${w.start}-${i}`}><span style={{display:'inline-block',padding:'2px 7px',margin:'1px 0',borderRadius:8,background: w===active?'rgba(25,18,52,.66)':'transparent',color:w===active?'#fff8bb':'#fff9ef',opacity:time>=w.start?1:.58}}>{w.word}</span>{' '}</React.Fragment>)}
  </div>;
}

function Shot({scene,index}: {scene:Scene;index:number}) {
  const f=useCurrentFrame();
  const gold=scene.palette==='gold'||(scene.id==='hook'&&f>40);
  const camera=1+ease(f/scene.frames)*.018;
  const fade=scene.id==='rescue'?1:ease((scene.frames-f)/7);
  return <AbsoluteFill style={{opacity:fade,background:scene.palette==='gold'?'#f7bc45':scene.palette==='teal'?'#12576a':'#2c1a50'}}>
    <svg width="720" height="1280" viewBox="0 0 720 1280" style={{position:'absolute',inset:0,overflow:'hidden'}}>
      <ArtDefs/><Backdrop palette={scene.palette} f={f}/>
      <g transform={`translate(360 730) scale(${camera}) translate(-360 -730)`}>
        <SceneArt scene={scene} f={f}/>
        {scene.id==='endorphins'&&<EndorphinOverlay scene={scene} f={f}/>}
        {(scene.id==='breathing'||scene.id==='slow')&&f%50<40&&<g opacity={scene.id==='slow'?1-ease(f/(scene.frames-25)):1}>
          {[0,1,2].map(i=><circle key={i} cx="360" cy={585+((f*2+i*20)%65)} r="6" fill="#c9fff1" opacity={.7}/>) }
        </g>}
      </g>
      <g fill={gold?'#715038':'#d0bee7'} opacity=".7" fontSize="16" fontWeight="700" letterSpacing="2.2">
        <text x="48" y="75">FENTANILO</text><text x="672" y="75" textAnchor="end">{String(index+1).padStart(2,'0')} / 16</text>
      </g>
      <text x="360" y="130" textAnchor="middle" fill={gold?'#775137':'#c0acd9'} fontSize="17" fontWeight="650" letterSpacing="2.5">{scene.chapter}</text>
      <rect x="48" y="1213" width="624" height="3" rx="2" fill={gold?'#9a673d':'#ae92d7'} opacity=".2"/>
      <rect x="48" y="1213" width={624*clamp((scene.start+f)/timeline.durationInFrames)} height="3" rx="2" fill={gold?'#895837':'#c5b5ea'} opacity=".6"/>
      <text x="48" y="1250" fill={gold?'#795330':'#a08bbd'} fontSize="13" letterSpacing="1.5">UNA EXPLICACIÓN VISUAL</text>
      <text x="672" y="1250" fill={gold?'#795330':'#a08bbd'} fontSize="13" textAnchor="end">CDC · NIDA</text>
    </svg>
    <Captions scene={scene} f={f}/>
  </AbsoluteFill>;
}

export const FentanylFilm: React.FC = () => {
  const [handle]=useState(()=>delayRender('Loading bundled typeface'));
  useEffect(()=>{
    const font=new FontFace('StudioSans',`url(${staticFile('fentanilo-v2/UbuntuSans.ttf')})`,{weight:'100 900'});
    font.load().then(loaded=>{document.fonts.add(loaded);continueRender(handle);}).catch(cancelRender);
  },[handle]);
  return <AbsoluteFill style={{background:'#21153b',fontFamily:'StudioSans, sans-serif'}}>
    <div style={{position:'absolute',width:720,height:1280,transform:'scale(1.5)',transformOrigin:'top left'}}>
      {timeline.scenes.map((scene,i)=><Sequence key={scene.id} from={scene.start} durationInFrames={scene.frames}>
        <Shot scene={scene} index={i}/><Audio src={staticFile(scene.audio)} volume={.95}/>
      </Sequence>)}
    </div>
    <Audio src={staticFile('fentanilo-v2/score.wav')} volume={.8}/>
  </AbsoluteFill>;
};
