#!/usr/bin/env python3
import asyncio
import argparse
import sys
import os
import time

from services.script_generator import generate_storyboard
from services.tts_service import synthesize_speech, VOICES_ES
from services.render_service import render_video

async def main():
    parser = argparse.ArgumentParser(description="Generador automático de videos estilo Resultaaquee (1-Click)")
    parser.add_argument("--tema", "-t", type=str, required=True, help="Tema o pregunta para el video")
    parser.add_argument("--voz", "-v", type=str, default="es-ES-AlvaroNeural", help="Identificador de la voz de Edge-TTS")
    parser.add_argument("--estilo", "-e", type=str, default="curiosity", help="Estilo del guion (curiosity, tech, money, humor)")
    parser.add_argument("--salida", "-o", type=str, default=None, help="Nombre del archivo MP4 de salida")
    
    args = parser.parse_args()

    clean_name = "".join([c if c.isalnum() else "_" for c in args.tema])[:25].strip("_")
    filename = args.salida or f"reel_{clean_name}_{int(time.time())}.mp4"

    print("\n" + "="*60)
    print("🎬 VIDEO CREATOR STUDIO — GENERADOR AUTOMÁTICO")
    print(f"Tema:   {args.tema}")
    print(f"Voz:    {args.voz}")
    print(f"Salida: {filename}")
    print("="*60 + "\n")

    # 1. Storyboard
    print("📝 [1/3] Creando guion estructurado y desglose de escenas...")
    storyboard = generate_storyboard(args.tema, style=args.estilo)
    print(f"    ✓ Guion listo ({len(storyboard['scenes'])} escenas). Gancho: \"{storyboard['hook']}\"")

    # 2. Voz y Timestamps
    print("\n🗣️  [2/3] Sintetizando voz en off gratuita y sincronizando subtítulos...")
    temp_audio = os.path.abspath(f"../output/temp_voice_{int(time.time())}.mp3")
    audio_info = await synthesize_speech(
        text=storyboard["full_script"],
        output_audio_path=temp_audio,
        voice=args.voz
    )
    print(f"    ✓ Audio generado: {round(audio_info['duration'], 2)}s | {len(audio_info['words'])} palabras mapeadas")

    # 3. Renderizado Remotion
    print("\n🎨 [3/3] Compilando video vertical (1080x1920) con Remotion...")
    result = render_video(storyboard, audio_info, output_filename=filename)
    
    print("\n" + "🎉"*20)
    print(f"¡VIDEO GENERADO CON ÉXITO!")
    print(f"Ruta:      {result['video_path']}")
    print(f"Duración:  {round(result['duration_seconds'], 1)} segundos ({result['duration_frames']} frames)")
    print(f"Peso:      {result['size_mb']} MB")
    print(f"Tiempo:    {result['render_time_seconds']} segundos de render")
    print("🎉"*20 + "\n")

if __name__ == "__main__":
    asyncio.run(main())
