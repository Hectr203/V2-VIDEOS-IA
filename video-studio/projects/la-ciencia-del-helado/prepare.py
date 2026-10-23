"""Preparación de audio TTS y sincronización temporal para la-ciencia-del-helado."""
import asyncio
import hashlib
import json
import math
from pathlib import Path
import subprocess
import edge_tts
import numpy as np

HERE = Path(__file__).resolve().parent
PUBLIC = HERE / "public"
SOURCE = HERE / "src"
FPS = 30


def get_duration(path):
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path)], text=True))


async def generate_narration(scene, config, sem):
    target = PUBLIC / f"{scene['id']}.mp3"
    cache_dir = HERE / "audio_cache"
    cache_dir.mkdir(exist_ok=True)
    cache = cache_dir / f"{scene['id']}.json"
    key = hashlib.sha256(json.dumps([scene['text'], config['voice'], config['rate']]).encode()).hexdigest()
    if target.exists() and cache.exists():
        data = json.loads(cache.read_text(encoding="utf-8"))
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
                seconds = get_duration(partial)
                partial.replace(target)
                data = {'key': key, 'duration': seconds, 'words': words}
                cache.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"Audio {scene['id']}: {seconds:.2f}s, {len(words)} palabras", flush=True)
                return data
            except Exception:
                if attempt == 2:
                    raise
                await asyncio.sleep(1 + attempt)


def generate_procedural_score(scenes, total_seconds):
    sr = 32000
    count = math.ceil(total_seconds * sr)
    audio = np.zeros((count, 2), dtype=np.float64)

    def add_signal(sig, at, gain=1.0, pan=0.0):
        start = int(at * sr)
        if start < 0 or start >= count:
            return
        chunk = sig[:count - start] * gain
        audio[start:start + len(chunk), 0] += chunk * math.sqrt((1 - pan) / 2)
        audio[start:start + len(chunk), 1] += chunk * math.sqrt((1 + pan) / 2)

    notes = [[220, 261.63, 329.63, 440], [174.61, 220, 261.63, 349.23], [196, 261.63, 329.63, 392], [196, 246.94, 293.66, 392]]
    for beat in range(math.ceil(total_seconds / 0.375)):
        at = beat * 0.375
        note = notes[(beat // 16) % 4][beat % 4]
        t = np.arange(int(sr * 1.5)) / sr
        env = (1 - np.exp(-t * 45)) * np.exp(-t * 4.5)
        sig = (np.sin(2 * np.pi * note * t) + 0.22 * np.sin(2 * np.pi * note * 2 * t)) * env
        add_signal(sig, at, 0.015, math.sin(beat) * 0.4)

    max_val = np.max(np.abs(audio))
    if max_val > 0.95:
        audio = audio / max_val * 0.95
    pcm = (audio * 32767).astype(np.int16)
    score_path = PUBLIC / "score.wav"
    import wave
    with wave.open(str(score_path), 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(sr)
        wav.writeframes(pcm.tobytes())
    print(f"Banda sonora guardada en: {score_path}")


async def main():
    storyboard = json.loads((HERE / "storyboard.json").read_text(encoding="utf-8"))
    sem = asyncio.Semaphore(2)
    tasks = [generate_narration(sc, storyboard, sem) for sc in storyboard["scenes"]]
    narrations = await asyncio.gather(*tasks)

    timeline_scenes = []
    current_frame = 0
    for sc, nar in zip(storyboard["scenes"], narrations):
        dur = max(sc.get("minSeconds", 2.0), nar["duration"] + 0.3)
        frames = math.ceil(dur * FPS)
        timeline_scenes.append({
            **sc,
            "start": current_frame,
            "frames": frames,
            "words": nar["words"],
            "audio": f"{sc['id']}.mp3"
        })
        current_frame += frames

    timeline_data = {
        "title": storyboard["title"],
        "fps": FPS,
        "durationInFrames": current_frame,
        "scenes": timeline_scenes
    }

    timeline_json = json.dumps(timeline_data, ensure_ascii=False, indent=2) + "\n"
    (HERE / "timeline.json").write_text(timeline_json, encoding="utf-8")
    (SOURCE / "timeline.json").write_text(timeline_json, encoding="utf-8")
    generate_procedural_score(timeline_scenes, current_frame / FPS)
    print(f"Timeline completado: {current_frame} frames ({current_frame / FPS:.2f}s)")


if __name__ == "__main__":
    asyncio.run(main())
