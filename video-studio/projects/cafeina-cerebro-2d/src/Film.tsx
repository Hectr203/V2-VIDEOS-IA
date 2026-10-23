import React, {useEffect, useState} from 'react';
import {AbsoluteFill, Audio, Sequence, cancelRender, continueRender, delayRender, staticFile, useCurrentFrame} from 'remotion';
import timelineData from './timeline.json';
import {ArtDefs, Backdrop, SceneArt, Label, ease, mix, clamp} from './art';

export const timeline = timelineData;
type Scene = typeof timeline.scenes[number] & {chapter:string; palette:string; art:string; act?:string};
const asset=(file:string)=>staticFile(file.split('/').pop()||file);

function Captions({scene,f}:{scene:Scene;f:number}) {
  const t=f/30, words=scene.words||[];
  if(!words.length) return null;
  let activeIndex=words.findIndex(w=>t>=w.start&&t<w.end);
  if(activeIndex<0) activeIndex=Math.max(0,words.findIndex(w=>w.start>t)-1);
  if(t>=words[words.length-1].end) activeIndex=words.length-1;
  const groups:{word:string;start:number;end:number}[][]=[];
  for(const word of words){const g=groups[groups.length-1];if(!g||g.length>=5||g.map(w=>w.word).join(' ').length+word.word.length>30)groups.push([word]);else g.push(word);}
  const active=words[activeIndex], group=groups.find(g=>g.includes(active))||groups[0], pop=ease((t-group[0].start)*12);
  return <div style={{position:'absolute',left:48,top:145,width:624,textAlign:'center',fontSize:35,lineHeight:1.3,fontWeight:760,letterSpacing:-.5,transform:`translateY(${mix(7,0,pop)}px)`,color:'#fff8ee',textShadow:'0 3px 17px rgba(9,8,20,.65)'}}>
    {group.map((w,i)=><span key={`${w.start}-${i}`} style={{display:'inline-block',padding:'2px 6px',borderRadius:6,background:w===active?'rgba(26,19,43,.72)':'transparent',color:w===active?'#ffe087':'#fff8ee',opacity:t>=w.start?1:.52}}>{w.word} </span>)}
  </div>;
}

function Shot({scene,index}:{scene:Scene;index:number}) {
  const f=useCurrentFrame(), camera=1+ease(f/scene.frames)*.024;
  return <AbsoluteFill style={{background:'#211632'}}>
    <svg width="720" height="1280" viewBox="0 0 720 1280" style={{position:'absolute',inset:0,overflow:'hidden'}}>
      <ArtDefs/><Backdrop palette={scene.palette} f={f}/>
      <g transform={`translate(360 ${790+waveCamera(f)}) scale(${camera}) translate(-360 -790)`}>
        <SceneArt kind={scene.art} f={f}/>
      </g>
      <Label x={360} y={464} text={scene.chapter} size={19}/>
      <g fill="#fff0d1" opacity=".72" fontSize="15" fontWeight="800" letterSpacing="2.1"><text x="48" y="74">CAFÉINA / CEREBRO</text><text x="672" y="74" textAnchor="end">{String(index+1).padStart(2,'0')} · 12</text></g>
      <path d="M48 1214H672" stroke="#fff" strokeWidth="2" opacity=".18"/><path d={`M48 1214H${48+624*clamp((scene.start+f)/timeline.durationInFrames)}`} stroke="#ffe38a" strokeWidth="3" opacity=".8"/>
    </svg>
    <Captions scene={scene} f={f}/>
  </AbsoluteFill>;
}
const waveCamera=(f:number)=>Math.sin(f*.014)*5;

export const CafeinaCerebro2dFilm:React.FC<{aspectRatio?:'9:16'|'16:9'}>=({aspectRatio='9:16'})=>{
  const horizontal=aspectRatio==='16:9', [handle]=useState(()=>delayRender('Cargando tipografía'));
  useEffect(()=>{const font=new FontFace('StudioSans',`url(${asset('UbuntuSans.ttf')})`,{weight:'100 900'});font.load().then(loaded=>{document.fonts.add(loaded);continueRender(handle);}).catch(cancelRender);},[handle]);
  const film=timeline.scenes.map((raw,i)=>{const scene=raw as Scene;return <Sequence key={scene.id} from={scene.start} durationInFrames={scene.frames}><Shot scene={scene} index={i}/><Audio src={asset(scene.audio)} volume={.95}/></Sequence>;});
  return <AbsoluteFill style={{background:'#100c1e',fontFamily:'StudioSans, sans-serif'}}>
    {horizontal?<div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center',background:'radial-gradient(ellipse,#35224f,#100c1e)'}}><div style={{position:'relative',width:720,height:1280,transform:'scale(.84375)',boxShadow:'0 0 120px rgba(0,0,0,.7)',borderRadius:22,overflow:'hidden'}}>{film}</div></div>:<div style={{position:'absolute',width:720,height:1280,transform:'scale(1.5)',transformOrigin:'top left'}}>{film}</div>}
    <Audio src={asset('score.wav')} volume={.32}/>
  </AbsoluteFill>;
};
