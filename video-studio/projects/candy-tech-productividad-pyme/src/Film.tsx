import React from 'react';
import {AbsoluteFill, Audio, Sequence, staticFile, useCurrentFrame} from 'remotion';
import timelineData from './timeline.json';
import {ArtDefs, Backdrop, SceneArt, ease, mix, clamp, wave} from './art';

export const timeline=timelineData;
type Scene=typeof timeline.scenes[number]&{chapter:string;palette:string;art:string;act:string};
const asset=(s:string)=>staticFile(s.replace(/^\//,''));

function Captions({scene,f}:{scene:Scene;f:number}){
 const t=f/30,words=scene.words||[]; if(!words.length)return null;
 let at=words.findIndex(w=>t>=w.start&&t<w.end); if(at<0)at=Math.max(0,words.findIndex(w=>w.start>t)-1); if(t>=words[words.length-1].end)at=words.length-1;
 const groups:{word:string;start:number;end:number}[][]=[];
 for(const word of words){const last=groups[groups.length-1];if(!last||last.length>=6||last.map(w=>w.word).join(' ').length+word.word.length>35)groups.push([word]);else last.push(word);}
 const active=words[at],group=groups.find(g=>g.includes(active))||groups[0],pop=ease((t-group[0].start)*10);
 return <div style={{position:'absolute',left:56,top:1095,width:608,textAlign:'center',fontSize:31,lineHeight:1.32,fontWeight:760,letterSpacing:-.25,transform:`translateY(${mix(10,0,pop)}px)`,color:'#fffaf1',textShadow:'0 3px 18px rgba(0,12,28,.86)'}}>
  {group.map((w,i)=><span key={`${w.start}-${i}`} style={{display:'inline-block',padding:'1px 5px',borderRadius:5,background:w===active?'rgba(5,45,75,.74)':'transparent',color:w===active?'#ffad82':'#fffaf1',opacity:t>=w.start?1:.5}}>{w.word} </span>)}
 </div>;
}

function Shot({scene,index}:{scene:Scene;index:number}){
 const f=useCurrentFrame(),progress=ease(f/Math.max(1,scene.frames)),scale=1+progress*.025,drift=wave(f,.012,7);
 const isBrand=scene.art==='brand';
 return <AbsoluteFill style={{background:'#082d59',fontFamily:'StudioSans, sans-serif'}}>
  <svg width="720" height="1280" viewBox="0 0 720 1280" style={{position:'absolute',inset:0,overflow:'hidden'}}>
   <ArtDefs/><Backdrop palette={scene.palette} f={f}/>
   <g opacity=".88"><image href={asset('candy-tech-symbol.png')} x="48" y="37" width="45" height="45" preserveAspectRatio="xMidYMid meet"/><text x="101" y="66" fill="#e9fff8" fontSize="14" fontWeight="800" letterSpacing="2">CANDY TECH SOLUTIONS</text><text x="672" y="66" textAnchor="end" fill="#e9fff8" fontSize="14" fontWeight="800" letterSpacing="2">{String(index+1).padStart(2,'0')} / 14</text></g>
   <g fill="#fff9ee" opacity=".2"><path d="M48 106H672" stroke="#fff" strokeWidth="2"/><path d={`M48 106H${48+624*clamp((scene.start+f)/timeline.durationInFrames)}`} stroke="#ff886c" strokeWidth="3" opacity=".95"/></g>
   <text x="360" y="183" textAnchor="middle" fill={scene.palette==='coral'?'#fff2de':'#d9fff5'} fontSize="17" fontWeight="850" letterSpacing="2.6">{scene.act.toUpperCase()}</text>
   <text x="360" y="236" textAnchor="middle" fill="#fffaf2" fontSize="26" fontWeight="850" letterSpacing="1.2">{scene.chapter}</text>
   <g transform={`translate(${drift} 0) translate(360 0) scale(${scale}) translate(-360 0)`}><SceneArt kind={scene.art} f={f}/></g>
   {isBrand&&<><image href={asset('candy-tech-wordmark.png')} x="102" y="830" width="516" height="200" preserveAspectRatio="xMidYMid meet" filter="url(#depth)"/><text x="360" y="1036" textAnchor="middle" fill="#103663" fontSize="20" fontWeight="700">Tecnología fácil para tu negocio.</text></>}
   <path d="M54 1220H666" stroke="#fff" strokeWidth="2" opacity=".18"/><circle cx="360" cy="1220" r="3" fill="#ff8a6d"/>
  </svg>
  <Captions scene={scene} f={f}/>
 </AbsoluteFill>;
}

export const CandyTechProductividadPymeFilm:React.FC<{aspectRatio?:'9:16'|'16:9'}>=({aspectRatio='9:16'})=>{
 const horizontal=aspectRatio==='16:9';
 const shots=timeline.scenes.map((raw,i)=>{const scene=raw as Scene;return <Sequence key={scene.id} from={scene.start} durationInFrames={scene.frames}><Shot scene={scene} index={i}/><Audio src={asset(`/${scene.audio}`)} volume={1}/></Sequence>;});
 return <AbsoluteFill style={{background:'#07182e',fontFamily:'StudioSans, sans-serif'}}>
  {horizontal?<div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center',background:'radial-gradient(ellipse,#145c72,#07182e)'}}><div style={{position:'relative',width:720,height:1280,transform:'scale(.84375)',borderRadius:24,overflow:'hidden',boxShadow:'0 0 100px rgba(0,0,0,.56)'}}>{shots}</div></div>:<div style={{position:'absolute',width:720,height:1280,transform:'scale(1.5)',transformOrigin:'top left'}}>{shots}</div>}
  <Audio src={asset('/score.wav')} volume={.2}/>
 </AbsoluteFill>;
};
