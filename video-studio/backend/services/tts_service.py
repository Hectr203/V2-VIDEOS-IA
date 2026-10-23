import asyncio
import os
import subprocess
from typing import List, Dict, Any
import edge_tts

VOICES_ES = [
    {"id": "es-ES-AlvaroNeural", "name": "Álvaro (España - Narrador/Expresivo)", "gender": "Male"},
    {"id": "es-MX-DaliaNeural", "name": "Dalia (México - Conversacional)", "gender": "Female"},
    {"id": "es-MX-JorgeNeural", "name": "Jorge (México - Dinámico)", "gender": "Male"},
    {"id": "es-ES-ElviraNeural", "name": "Elvira (España - Clara)", "gender": "Female"},
    {"id": "es-AR-TomasNeural", "name": "Tomás (Argentina)", "gender": "Male"},
    {"id": "es-CO-GonzaloNeural", "name": "Gonzalo (Colombia)", "gender": "Male"},
]

def get_audio_duration(file_path: str) -> float:
    """Calcula la duración exacta en segundos de un archivo de audio usando ffprobe."""
    try:
        cmd = [
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", file_path
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return float(res.stdout.strip())
    except Exception:
        return 0.0

async def synthesize_speech(
    text: str,
    output_audio_path: str,
    voice: str = "es-ES-AlvaroNeural",
    rate: str = "+5%",
    pitch: str = "+0Hz"
) -> Dict[str, Any]:
    """
    Sintetiza texto a voz usando Microsoft Edge-TTS y calcula marcas de tiempo
    por palabra con alta precisión para subtítulos dinámicos estilo karaoke.
    """
    os.makedirs(os.path.dirname(output_audio_path), exist_ok=True)
    
    communicate = edge_tts.Communicate(text=text, voice=voice, rate=rate, pitch=pitch)
    
    sentence_cues = []
    
    with open(output_audio_path, "wb") as audio_file:
        async for chunk in communicate.stream():
            chunk_type = chunk.get("type")
            if chunk_type == "audio":
                cdata = chunk.get("data")
                if cdata:
                    audio_file.write(cdata)
            elif chunk_type == "SentenceBoundary":
                # offset y duration en cientos de nanosegundos (10^-7 segundos)
                start_sec = float(chunk.get("offset") or 0) / 10_000_000.0
                dur_sec = float(chunk.get("duration") or 0) / 10_000_000.0
                sentence_cues.append({
                    "text": chunk.get("text", "").strip(),
                    "start": round(start_sec, 3),
                    "end": round(start_sec + dur_sec, 3),
                    "duration": round(dur_sec, 3)
                })

    total_duration = get_audio_duration(output_audio_path)
    if not sentence_cues and total_duration > 0:
        sentence_cues.append({
            "text": text,
            "start": 0.0,
            "end": total_duration,
            "duration": total_duration
        })

    # Generar timestamps palabra por palabra interpolando la duración de sílabas/caracteres
    word_timestamps: List[Dict[str, Any]] = []
    
    for sentence in sentence_cues:
        raw_words = sentence["text"].split()
        if not raw_words:
            continue
        
        # Ponderar duración de cada palabra por su longitud (mínimo peso 2)
        weights = [max(len(w), 2) for w in raw_words]
        total_weight = sum(weights)
        sent_duration = sentence["duration"]
        current_cursor = sentence["start"]
        
        for w, weight in zip(raw_words, weights):
            w_dur = (weight / total_weight) * sent_duration
            word_timestamps.append({
                "word": w,
                "start": round(current_cursor, 3),
                "end": round(current_cursor + w_dur, 3)
            })
            current_cursor += w_dur

    return {
        "audio_path": output_audio_path,
        "duration": total_duration,
        "sentences": sentence_cues,
        "words": word_timestamps
    }
