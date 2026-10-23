"""Generate fresh narration, cue sheet and an original procedural score.

Run with video-studio/backend/.venv/bin/python. Network: Edge TTS only.
All visuals remain authored SVG; the reference MP4 is never read here.
"""
import asyncio
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import wave

import edge_tts
import numpy as np

HERE = Path(__file__).resolve().parent
STUDIO = HERE.parents[1]
PUBLIC = STUDIO / "remotion/public/fentanilo-v2"
SOURCE = STUDIO / "remotion/src/projects/fentanilo-v2"
FPS = 30


def duration(path):
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path)], text=True))


async def narration(scene, config, sem):
    target = PUBLIC / f"{scene['id']}.mp3"
    cache = HERE / "audio" / f"{scene['id']}.json"
    key = hashlib.sha256(json.dumps([scene['text'], config['voice'], config['rate']]).encode()).hexdigest()
    if target.exists() and cache.exists():
        data = json.loads(cache.read_text())
        if data.get('key') == key and target.stat().st_size > 1000:
            return data
    async with sem:
        for attempt in range(3):
            try:
                words = []
                partial = target.with_suffix('.partial.mp3')
                tts = edge_tts.Communicate(scene['text'], config['voice'], rate=config['rate'], boundary='WordBoundary')
                with partial.open('wb') as stream:
                    async for chunk in tts.stream():
                        if chunk['type'] == 'audio':
                            stream.write(chunk['data'])
                        elif chunk['type'] == 'WordBoundary':
                            words.append({'word': chunk['text'], 'start': chunk['offset'] / 1e7, 'end': (chunk['offset'] + chunk['duration']) / 1e7})
                seconds = duration(partial)
                if not words or seconds <= 0:
                    raise RuntimeError(f"No word timestamps/audio for {scene['id']}")
                partial.replace(target)
                data = {'key': key, 'duration': seconds, 'words': words}
                cache.write_text(json.dumps(data, ensure_ascii=False, indent=2))
                print(f"Voice {scene['id']}: {seconds:.2f}s, {len(words)} words", flush=True)
                return data
            except Exception:
                if attempt == 2:
                    raise
                await asyncio.sleep(1 + attempt)


def score(scenes, total):
    """Deterministic stereo music + gentle transition/heartbeat sound design."""
    sr = 32000
    count = math.ceil(total * sr)
    audio = np.zeros((count, 2), dtype=np.float64)
    rng = np.random.default_rng(206)

    def add(signal, at, gain=1, pan=0):
        start = int(at * sr)
        if start < 0 or start >= count:
            return
        sig = signal[:count - start] * gain
        audio[start:start + len(sig), 0] += sig * math.sqrt((1 - pan) / 2)
        audio[start:start + len(sig), 1] += sig * math.sqrt((1 + pan) / 2)

    # Soft arpeggiated A minor / F / C / G bed; no sampled music.
    notes = [[220, 261.63, 329.63, 440], [174.61, 220, 261.63, 349.23], [196, 261.63, 329.63, 392], [196, 246.94, 293.66, 392]]
    for beat in range(math.ceil(total / .375)):
        at = beat * .375
        note = notes[(beat // 16) % 4][beat % 4]
        t = np.arange(int(sr * 1.5)) / sr
        env = (1 - np.exp(-t * 45)) * np.exp(-t * 4.5)
        sig = (np.sin(2 * np.pi * note * t) + .22 * np.sin(2 * np.pi * note * 2 * t)) * env
        add(sig, at, .016, math.sin(beat) * .45)
    for scene in scenes:
        at = scene['start'] / FPS
        t = np.arange(int(sr * .32)) / sr
        swish = rng.normal(0, 1, len(t))
        swish = np.convolve(swish, np.ones(18)/18, mode='same') * np.sin(np.pi * t / .32) ** 2
        add(swish, at, .048, -.2)
        if scene['id'] in ['receptor', 'endorphins', 'coffee', 'music', 'rescue']:
            t = np.arange(sr) / sr
            sig = (np.sin(2*np.pi*880*t) + .3*np.sin(2*np.pi*1320*t)) * np.exp(-t*9) * (1-np.exp(-t*120))
            add(sig, at + .55, .032, .25)
        if scene['id'] in ['breathing', 'slow']:
            for n in range(int(scene['frames'] / 30)):
                t = np.arange(int(sr * .2))/sr
                add(np.sin(2*np.pi*60*t)*np.exp(-t*25), at+n, .07)
    fade = np.minimum(1, np.arange(count)/sr/1.5) * np.minimum(1, (count-np.arange(count))/sr/1.8)
    audio *= fade[:, None]
    with wave.open(str(PUBLIC / 'score.wav'), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(sr)
        out.writeframes((np.clip(audio, -1, 1) * 32767).astype('<i2').tobytes())


async def main():
    for folder in [PUBLIC, SOURCE, HERE / 'audio', HERE / 'renders']:
        folder.mkdir(parents=True, exist_ok=True)
    font = Path('/usr/share/fonts/truetype/ubuntu/UbuntuSans[wdth,wght].ttf')
    if font.exists():
        shutil.copyfile(font, PUBLIC / 'UbuntuSans.ttf')
    config = json.loads((HERE / 'storyboard.json').read_text())
    sem = asyncio.Semaphore(3)
    voices = await asyncio.gather(*(narration(s, config, sem) for s in config['scenes']))
    scenes = []
    cursor = 0
    for spec, voice in zip(config['scenes'], voices):
        frames = math.ceil(max(voice['duration'] + .14, spec['minSeconds']) * FPS)
        scenes.append({**spec, 'start': cursor, 'frames': frames, 'words': voice['words'], 'audio': f"fentanilo-v2/{spec['id']}.mp3"})
        cursor += frames
    # Ending hold for the emergency call-to-action.
    scenes[-1]['frames'] += 42
    cursor += 42
    timeline = {'title': config['title'], 'fps': FPS, 'durationInFrames': cursor, 'scenes': scenes}
    (SOURCE / 'timeline.json').write_text(json.dumps(timeline, ensure_ascii=False, indent=2))
    (HERE / 'timeline.json').write_text(json.dumps(timeline, ensure_ascii=False, indent=2))
    score(scenes, cursor / FPS)
    # Portable timed subtitles for external editors, in addition to burned-in captions.
    def stamp(seconds):
        ms = round(seconds * 1000)
        return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
    cues = []
    for scene in scenes:
        words = scene['words']
        for i in range(0, len(words), 5):
            group = words[i:i+5]
            start = scene['start']/FPS + group[0]['start']
            end = scene['start']/FPS + group[-1]['end']
            cues.append(f"{len(cues)+1}\n{stamp(start)} --> {stamp(end)}\n{' '.join(w['word'] for w in group)}\n")
    (HERE / 'subtitles.srt').write_text('\n'.join(cues))
    print(f"READY: {cursor} frames / {cursor/FPS:.2f}s / {len(scenes)} scenes", flush=True)


if __name__ == '__main__':
    asyncio.run(main())
