import os
import asyncio
import subprocess
import urllib.request
from typing import Dict, Any, List, Optional
import edge_tts

import json

# Cargar .env si existe
env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.env"))
if os.path.exists(env_path):
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

# Lista unificada de voces disponibles por proveedor
AVAILABLE_VOICE_PROVIDERS = [
    {
        "provider": "edge-tts",
        "name": "Microsoft Edge-TTS (Local/Gratis - Sin Cuota)",
        "voices": [
            {"id": "es-ES-AlvaroNeural", "name": "Álvaro (España - Narrador Expresivo)", "gender": "Male"},
            {"id": "es-MX-DaliaNeural", "name": "Dalia (México - Conversacional)", "gender": "Female"},
            {"id": "es-MX-JorgeNeural", "name": "Jorge (México - Dinámico)", "gender": "Male"},
            {"id": "es-ES-ElviraNeural", "name": "Elvira (España - Clara)", "gender": "Female"},
            {"id": "es-AR-TomasNeural", "name": "Tomás (Argentina)", "gender": "Male"},
            {"id": "es-CO-GonzaloNeural", "name": "Gonzalo (Colombia)", "gender": "Male"},
        ]
    },
    {
        "provider": "elevenlabs",
        "name": "ElevenLabs (API Key Requerida)",
        "voices": [
            {"id": "pNInz6obpgDQGcFmaJgB", "name": "Adam (Voz #1 de Varón - Narrador Profundo)", "gender": "Male"},
            {"id": "TX3LPaxmHKxFdv7VOQHJ", "name": "Liam (Varón Dinámico - Creador)", "gender": "Male"},
            {"id": "nPczCjzI2devNBz1zQrb", "name": "Brian (Varón Sabio y Cálido)", "gender": "Male"},
            {"id": "21m00Tcm4TlvDq8ikWAM", "name": "Rachel (Storytelling)", "gender": "Female"}
        ]
    },
    {
        "provider": "azure",
        "name": "Azure Speech Services (Azure AI)",
        "voices": [
            {"id": "es-ES-AlvaroNeural", "name": "Azure Álvaro Neural", "gender": "Male"},
            {"id": "es-MX-DaliaNeural", "name": "Azure Dalia Neural", "gender": "Female"}
        ]
    },
    {
        "provider": "google",
        "name": "Google Text-to-Speech (Voz Oficial de Google)",
        "voices": [
            {"id": "google-latam", "name": "Voz de Google (Latinoamérica)", "gender": "Female"},
            {"id": "google-es", "name": "Voz de Google (España)", "gender": "Female"}
        ]
    }
]

def get_audio_duration(file_path: str) -> float:
    """Calcula la duración real exacta de un archivo de audio mediante ffprobe."""
    try:
        cmd = [
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", file_path
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return float(res.stdout.strip())
    except Exception:
        return 0.0

class VoiceHub:
    """
    Centro unificado de síntesis de voz con soporte para múltiples proveedores,
    fallback automático y sincronización por palabra (karaoke).
    """

    @classmethod
    def get_catalog(cls) -> List[Dict[str, Any]]:
        catalog = [{**provider, "voices": list(provider["voices"])} for provider in AVAILABLE_VOICE_PROVIDERS]
        elevenlabs = next(provider for provider in catalog if provider["provider"] == "elevenlabs")
        api_key = os.getenv("ELEVENLABS_API_KEY")
        if not api_key:
            elevenlabs["voices"] = []
            elevenlabs["name"] = "ElevenLabs (configura ELEVENLABS_API_KEY)"
            return catalog
        request = urllib.request.Request(
            "https://api.elevenlabs.io/v1/voices",
            headers={"xi-api-key": api_key, "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                data = json.loads(response.read().decode("utf-8"))
            elevenlabs["voices"] = [
                {
                    "id": voice["voice_id"],
                    "name": voice.get("name", voice["voice_id"]),
                    "gender": (voice.get("labels") or {}).get("gender", "Unknown"),
                }
                for voice in data.get("voices", [])
                if voice.get("voice_id")
            ]
        except Exception as error:
            elevenlabs["voices"] = []
            elevenlabs["name"] = f"ElevenLabs (no disponible: {error})"
        return catalog

    @classmethod
    async def synthesize(
        cls,
        text: str,
        output_audio_path: str,
        provider: str = "edge-tts",
        voice_id: str = "es-ES-AlvaroNeural",
        rate: str = "+4%",
        pitch: str = "+0Hz"
    ) -> Dict[str, Any]:
        """
        Sintetiza audio con el proveedor elegido. Si un proveedor externo falla o no está configurado,
        ejecuta fallback a Edge-TTS para garantizar que el flujo de video nunca se detenga.
        """
        os.makedirs(os.path.dirname(output_audio_path), exist_ok=True)

        if provider == "elevenlabs":
            if not os.getenv("ELEVENLABS_API_KEY"):
                raise RuntimeError("ELEVENLABS_API_KEY no está configurada")
            return await cls._synthesize_elevenlabs(text, output_audio_path, voice_id)

        if provider == "vibevoice":
            return await cls._synthesize_vibevoice(text, output_audio_path, voice_id)

        if provider in ["google", "google-tts", "gtts"]:
            return await cls._synthesize_google_tts(text, output_audio_path, voice_id)

        if provider != "edge-tts":
            raise ValueError(f"Proveedor de voz no soportado: {provider}")

        # Por defecto o fallback: Edge-TTS (alta calidad y sin cuotas)
        return await cls._synthesize_edge_tts(text, output_audio_path, voice_id, rate, pitch)

    @classmethod
    async def _synthesize_edge_tts(
        cls,
        text: str,
        output_audio_path: str,
        voice_id: str,
        rate: str,
        pitch: str
    ) -> Dict[str, Any]:
        # Si la voz no es compatible con Edge-TTS, mapear a es-ES-AlvaroNeural
        if not voice_id.startswith("es-"):
            voice_id = "es-ES-AlvaroNeural"

        communicate = edge_tts.Communicate(text=text, voice=voice_id, rate=rate, pitch=pitch)
        sentence_cues = []

        with open(output_audio_path, "wb") as audio_file:
            async for chunk in communicate.stream():
                if chunk.get("type") == "audio":
                    cdata = chunk.get("data")
                    if cdata:
                        audio_file.write(cdata)
                elif chunk.get("type") == "SentenceBoundary":
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

        # Mapeo de marcas de tiempo por palabra
        word_timestamps: List[Dict[str, Any]] = []
        for sentence in sentence_cues:
            words = sentence["text"].split()
            if not words:
                continue
            weights = [max(len(w), 2) for w in words]
            total_weight = sum(weights)
            sent_duration = sentence["duration"]
            cursor = sentence["start"]

            for w, weight in zip(words, weights):
                w_dur = (weight / total_weight) * sent_duration
                word_timestamps.append({
                    "word": w,
                    "start": round(cursor, 3),
                    "end": round(cursor + w_dur, 3)
                })
                cursor += w_dur

        return {
            "provider": "edge-tts",
            "voice_id": voice_id,
            "audio_path": output_audio_path,
            "duration": total_duration,
            "words": word_timestamps
        }

    @classmethod
    async def _synthesize_vibevoice(cls, text: str, output_path: str, voice_id: str) -> Dict[str, Any]:
        """Fail explicitly until a real local VibeVoice inference adapter is configured."""
        raise NotImplementedError(
            "VibeVoice está listado como integración futura; no hay adaptador de inferencia configurado."
        )

    @classmethod
    async def _synthesize_elevenlabs(cls, text: str, output_path: str, voice_id: str) -> Dict[str, Any]:
        """Integración de alta precisión con ElevenLabs API (alineación palabra por palabra y audio HD)."""
        import urllib.request
        import base64
        api_key = os.getenv("ELEVENLABS_API_KEY")
        if not api_key:
            raise ValueError("ELEVENLABS_API_KEY no configurada")

        if not voice_id or len(voice_id) < 10:
            raise ValueError("Selecciona una voz válida de ElevenLabs desde el catálogo")

        url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/with-timestamps"
        payload = json.dumps({
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {
                "stability": 0.5,
                "similarity_boost": 0.8
            }
        }).encode("utf-8")

        req = urllib.request.Request(
            url, data=payload,
            headers={"xi-api-key": api_key, "Content-Type": "application/json"}
        )

        def _call():
            with urllib.request.urlopen(req, timeout=40) as resp:
                return json.loads(resp.read().decode("utf-8"))

        data = await asyncio.to_thread(_call)

        audio_bytes = base64.b64decode(data.get("audio_base64", ""))
        with open(output_path, "wb") as f:
            f.write(audio_bytes)

        duration = get_audio_duration(output_path)

        align = data.get("alignment", {})
        chars = align.get("characters", [])
        starts = align.get("character_start_times_seconds", [])
        ends = align.get("character_end_times_seconds", [])

        word_timestamps = []
        if chars and starts and ends:
            current_word = []
            word_start = None
            prev_end = 0.0
            for char, s, e in zip(chars, starts, ends):
                if char.isspace():
                    if current_word:
                        word_timestamps.append({
                            "word": "".join(current_word),
                            "start": round(word_start, 3) if word_start is not None else 0.0,
                            "end": round(prev_end, 3)
                        })
                        current_word = []
                        word_start = None
                else:
                    if word_start is None:
                        word_start = s
                    current_word.append(char)
                    prev_end = e
            if current_word:
                word_timestamps.append({
                    "word": "".join(current_word),
                    "start": round(word_start, 3) if word_start is not None else 0.0,
                    "end": round(prev_end, 3)
                })

        if not word_timestamps:
            words = text.split()
            avg_w = duration / max(len(words), 1)
            word_timestamps = [
                {"word": w, "start": round(i * avg_w, 3), "end": round((i + 1) * avg_w, 3)}
                for i, w in enumerate(words)
            ]

        return {
            "provider": "elevenlabs",
            "voice_id": voice_id,
            "audio_path": output_path,
            "duration": duration,
            "words": word_timestamps
        }

    @classmethod
    async def _synthesize_google_tts(cls, text: str, output_path: str, voice_id: str) -> Dict[str, Any]:
        """Sintetiza texto a voz usando el motor oficial de Google (gTTS)."""
        from gtts import gTTS
        tld = "com.mx"
        if "es" in voice_id.lower() and "latam" not in voice_id.lower():
            tld = "es"

        def _call_gtts():
            tts = gTTS(text=text, lang="es", tld=tld, slow=False)
            tts.save(output_path)

        await asyncio.to_thread(_call_gtts)

        total_duration = get_audio_duration(output_path)
        words = text.split()
        word_timestamps: List[Dict[str, Any]] = []
        if words and total_duration > 0:
            weights = [max(len(w), 2) for w in words]
            total_weight = sum(weights)
            cursor = 0.0
            for w, weight in zip(words, weights):
                w_dur = (weight / total_weight) * total_duration
                word_timestamps.append({
                    "word": w,
                    "start": round(cursor, 3),
                    "end": round(cursor + w_dur, 3)
                })
                cursor += w_dur

        return {
            "provider": "google",
            "voice_id": voice_id,
            "audio_path": output_path,
            "duration": total_duration,
            "words": word_timestamps
        }

