import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import {execFileSync} from 'node:child_process';

const here=path.dirname(fileURLToPath(import.meta.url));
const studio=path.resolve(here,'../..');
const remotion=path.join(studio,'remotion');
const require=createRequire(path.join(remotion,'package.json'));
const {bundle}=require('@remotion/bundler');
const {selectComposition,renderMedia,renderStill}=require('@remotion/renderer');
const timeline=JSON.parse(await fs.readFile(path.join(here,'timeline.json'),'utf8'));
const renders=path.join(here,'renders');
await fs.mkdir(renders,{recursive:true});
const stills=process.argv.includes('--stills');
const draft=process.argv.includes('--draft');
const serveUrl=await bundle({entryPoint:path.join(remotion,'src/index.ts'),publicDir:path.join(remotion,'public')});
const chromiumOptions={gl:'angle'};
const composition=await selectComposition({serveUrl,id:'Fentanilo2DStudio',chromiumOptions});
if(stills){
  for(const scene of timeline.scenes){
    const frame=scene.start+Math.floor(scene.frames*.67);
    await renderStill({serveUrl,composition,output:path.join(renders,`${scene.id}.png`),frame,imageFormat:'png',scale:2/3,chromiumOptions});
    console.log(`STILL ${scene.id} @${(frame/30).toFixed(2)}s`);
  }
} else {
  const name=draft?'preview-720p.mp4':'fentanilo-2d-v2.mp4';
  const partial=path.join(renders,`partial-${name}`);
  let progress=-1;
  await renderMedia({serveUrl,composition,outputLocation:partial,codec:'h264',crf:draft?23:17,
    pixelFormat:'yuv420p',audioCodec:'aac',audioBitrate:'192k',
    scale:draft?2/3:1,concurrency:4,chromiumOptions,
    onProgress:({progress:p})=>{const n=Math.floor(p*20)*5;if(n!==progress){progress=n;console.log(`RENDER ${n}%`);}},
  });
  const probe=JSON.parse(execFileSync('ffprobe',['-v','error','-show_streams','-show_format','-of','json',partial],{encoding:'utf8'}));
  const v=probe.streams.find(s=>s.codec_type==='video'),a=probe.streams.find(s=>s.codec_type==='audio');
  const w=draft?720:1080,h=draft?1280:1920;
  if(!v||!a||v.width!==w||v.height!==h||v.avg_frame_rate!=='30/1'||Math.abs(Number(probe.format.duration)-timeline.durationInFrames/30)>.15)throw new Error('Render validation failed; partial retained.');
  const final=path.join(renders,name);
  await fs.rename(partial,final);
  await fs.writeFile(path.join(renders,draft?'preview-probe.json':'final-probe.json'),JSON.stringify(probe,null,2));
  if(!draft){
    await fs.mkdir(path.join(studio,'output'),{recursive:true});
    await fs.copyFile(final,path.join(studio,'output',name));
  }
  console.log(`VERIFIED ${final} (${probe.format.duration}s, video + audio)`);
}
