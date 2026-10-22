#!/usr/bin/env python3
import asyncio
import os
import sys
import time
import json
import uuid

from services.voice_hub import VoiceHub
from services.project_manager import ProjectManager, PROJECTS_DIR
from services.render_service import render_project

SCENES_DEF = [
    {
        "id": 1,
        "act": 1,
        "title": "El Gran Secreto del Aire",
        "narrative_text": "¡Resulta que casi la mitad de cada bote de helado que compras en la tienda no es leche ni crema, sino simplemente aire atrapado a propósito!",
        "callout": "¡50% AIRE!",
        "sticker": "shock",
        "sfx": "whoosh",
        "bg_color": "#FEF3C7"
    },
    {
        "id": 2,
        "act": 1,
        "title": "La Ciencia del Overrun",
        "narrative_text": "En la industria heladera esto se llama overrun. Si no le inyectaran aire durante el batido, el helado se convertiría en un bloque de hielo impenetrable como una roca.",
        "callout": "EL OVERRUN",
        "sticker": "idea",
        "sfx": "pop",
        "bg_color": "#EDE9FE"
    },
    {
        "id": 3,
        "act": 1,
        "title": "Los Ingredientes Sagrados",
        "narrative_text": "Todo comienza en enormes tanques de acero inoxidable donde se combinan tres elementos esenciales: leche entera, crema rica en grasa y una calculada porción de azúcares.",
        "callout": "LA BASE LÁCTEA",
        "sticker": "milk",
        "sfx": "ding",
        "bg_color": "#E0F2FE"
    },
    {
        "id": 4,
        "act": 1,
        "title": "El Azúcar como Anticongelante",
        "narrative_text": "¿Sabías que el azúcar aquí no está solo por el sabor dulce? Funciona como un poderoso anticongelante natural que evita que el agua forme bloques duros de hielo.",
        "callout": "ANTICONGELANTE",
        "sticker": "brain",
        "sfx": "click",
        "bg_color": "#FCE7F3"
    },
    {
        "id": 5,
        "act": 2,
        "title": "La Guerra de Grasa y Agua",
        "narrative_text": "Pero hay un dilema científico: la grasa de la leche y el agua se repelen por naturaleza. Para forzarlas a ser inseparables, los heladeros añaden emulsionantes.",
        "callout": "EMULSIONANTES",
        "sticker": "danger",
        "sfx": "whoosh",
        "bg_color": "#DCFCE7"
    },
    {
        "id": 6,
        "act": 2,
        "title": "La Pasteurización Caliente",
        "narrative_text": "La mezcla se calienta rápidamente a más de ochenta grados centígrados para eliminar cualquier bacteria y disolver los ingredientes a nivel molecular.",
        "callout": "80°C CALOR",
        "sticker": "fire",
        "sfx": "pop",
        "bg_color": "#FEF3C7"
    },
    {
        "id": 7,
        "act": 2,
        "title": "Homogeneización a Presión",
        "narrative_text": "Inmediatamente después, una bomba gigantesca dispara el líquido a dos mil libras de presión por orificios diminutos para pulverizar las gotas de grasa.",
        "callout": "ALTA PRESIÓN",
        "sticker": "arrow_up",
        "sfx": "ding",
        "bg_color": "#EDE9FE"
    },
    {
        "id": 8,
        "act": 2,
        "title": "El Sueño de la Maduración",
        "narrative_text": "Ahora viene la paciencia. La mezcla se enfría a cuatro grados y reposa entre cuatro y veinticuatro horas para que las proteínas lácteas se hinchen de hidratación.",
        "callout": "MADURACIÓN",
        "sticker": "idea",
        "sfx": "click",
        "bg_color": "#E0F2FE"
    },
    {
        "id": 9,
        "act": 2,
        "title": "El Tubo Congelador",
        "narrative_text": "Llega el momento estelar: el turbinado continuo. La mezcla entra a un cilindro congelado con paredes a treinta grados bajo cero mientras cuchillas giran velozmente.",
        "callout": "EL TURBINADO",
        "sticker": "freeze",
        "sfx": "whoosh",
        "bg_color": "#FCE7F3"
    },
    {
        "id": 10,
        "act": 2,
        "title": "La Batalla de los Microcristales",
        "narrative_text": "La clave del éxito reside en raspar el hielo miles de veces por segundo. Si los cristales superan cincuenta micras, tu lengua los notará arenosos y desagradables.",
        "callout": "CRISTALES MINI",
        "sticker": "microscope",
        "sfx": "pop",
        "bg_color": "#DCFCE7"
    },
    {
        "id": 11,
        "act": 3,
        "title": "Textura Soft Serve",
        "narrative_text": "Al salir del cilindro congelador, el helado tiene la textura suave de un helado cremoso de máquina, pero todavía está a medio camino de su viaje.",
        "callout": "CREMOSIDAD",
        "sticker": "ice_cream",
        "sfx": "ding",
        "bg_color": "#FEF3C7"
    },
    {
        "id": 12,
        "act": 3,
        "title": "El Túnel de Congelación",
        "narrative_text": "Se envasa a gran velocidad y se introduce en un túnel de viento polar a menos cuarenta grados. En solo minutos, la estructura cremosa queda sellada para siempre.",
        "callout": "-40°C POLAR",
        "sticker": "freeze",
        "sfx": "click",
        "bg_color": "#EDE9FE"
    },
    {
        "id": 13,
        "act": 3,
        "title": "El Misterio del Brain Freeze",
        "narrative_text": "¿Alguna vez has sufrido el famoso dolor de cerebro por comer muy rápido? Ocurre porque los vasos de tu paladar se contraen de golpe para defender a tu cabeza del frío.",
        "callout": "BRAIN FREEZE",
        "sticker": "brain",
        "sfx": "whoosh",
        "bg_color": "#FCE7F3"
    },
    {
        "id": 14,
        "act": 3,
        "title": "La Temperatura Perfecta",
        "narrative_text": "Por eso los maestros heladeros recomiendan servirlo a menos catorce grados centígrados, la temperatura mágica donde tus papilas gustativas captan todo su sabor.",
        "callout": "-14°C IDEAL",
        "sticker": "shock",
        "sfx": "pop",
        "bg_color": "#DCFCE7"
    },
    {
        "id": 15,
        "act": 3,
        "title": "El Veredicto Final",
        "narrative_text": "¿Tú eres del equipo helado de chocolate o de vainilla tradicional? Cuéntame tu sabor preferido en los comentarios y suscríbete para descubrir más misterios cotidianos.",
        "callout": "¿CUÁL ES TU FAVORITO?",
        "sticker": "ice_cream",
        "sfx": "ding",
        "bg_color": "#FEF08A"
    }
]

async def main():
    print("=" * 65)
    print("🍦 GENERANDO VIDEO DE 3 MINUTOS: CÓMO SE HACE EL HELADO")
    print("🎙️  Voz: ElevenLabs Varón #1 (Adam - Narrador Profundo HD)")
    print("🎨 Estilo: Curioso / Divulgación Científica de Alta Retención")
    print("=" * 65)

    project_id = f"proj_helado_eleven_{int(time.time())}"
    pdir = ProjectManager.get_project_dir(project_id)
    assets_dir = os.path.join(pdir, "assets")
    os.makedirs(assets_dir, exist_ok=True)

    print(f"\n[1/3] Sintetizando las 15 escenas con la voz de varón de ElevenLabs (Adam)...")
    scenes_processed = []
    total_audio_duration = 0.0

    for i, s in enumerate(SCENES_DEF):
        audio_filename = f"scene_{s['id']}_eleven.mp3"
        audio_path = os.path.join(assets_dir, audio_filename)
        
        # Síntesis con ElevenLabs (Voz de varón Adam)
        res = await VoiceHub.synthesize(
            text=s["narrative_text"],
            output_audio_path=audio_path,
            provider="elevenlabs",
            voice_id="pNInz6obpgDQGcFmaJgB"
        )
        
        dur = res["duration"]
        total_audio_duration += dur
        
        scene_item = dict(s)
        scene_item["audio_path"] = audio_path
        scene_item["audio_url"] = f"/projects/{project_id}/assets/{audio_filename}"
        scene_item["audio_duration"] = dur
        scene_item["words"] = res["words"]
        scene_item["status"] = "audio_ready"
        scene_item["versions"] = []
        scenes_processed.append(scene_item)
        
        print(f"  ✓ Escena {s['id']}/15: {s['title'][:25]:<25} | {round(dur, 1)}s | Words: {len(res['words'])} | Sticker: {s['sticker']}")

    print(f"\nDuración total de audio: {round(total_audio_duration, 2)}s ({round(total_audio_duration / 60, 2)} minutos)")

    # Guardar metadata del proyecto
    project_meta = {
        "id": project_id,
        "topic": "¿Cómo se hace realmente el helado?",
        "target_duration_seconds": 180,
        "style": "curiosity",
        "voice_provider": "elevenlabs",
        "voice_id": "pNInz6obpgDQGcFmaJgB",
        "visual_theme": "Curiosidades científicas y proceso industrial artesanal de heladería",
        "status": "ready_to_render",
        "total_real_duration": round(total_audio_duration, 2),
        "scene_count": len(scenes_processed),
        "created_at": time.time(),
        "updated_at": time.time(),
        "final_video_url": None
    }

    with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
        json.dump(project_meta, f, ensure_ascii=False, indent=2)

    with open(os.path.join(pdir, "scenes.json"), "w", encoding="utf-8") as f:
        json.dump(scenes_processed, f, ensure_ascii=False, indent=2)

    output_filename = "como_se_hace_el_helado_3min_elevenlabs.mp4"
    print(f"\n[2/3] Renderizando video con Remotion (1080x1920 @ 30 FPS)...")
    print(f"Salida prevista: output/{output_filename}")

    render_res = render_project(
        project_meta=project_meta,
        scenes=scenes_processed,
        output_filename=output_filename,
        fps=30
    )

    # Copiar también al nombre estándar para conveniencia
    import shutil
    std_copy = os.path.join(os.path.dirname(render_res['video_path']), "como_se_hace_el_helado_3min.mp4")
    shutil.copy2(render_res['video_path'], std_copy)

    project_meta["final_video_url"] = render_res["video_url"]
    project_meta["status"] = "completed"
    with open(os.path.join(pdir, "project.json"), "w", encoding="utf-8") as f:
        json.dump(project_meta, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 65)
    print("🎉 ¡VIDEO CON VOZ DE ELEVENLABS GENERADO EXITOSAMENTE!")
    print(f"📁 Archivo HD:  {render_res['video_path']}")
    print(f"📁 Copia std:   {std_copy}")
    print(f"⏱️  Duración:   {render_res['duration_seconds']} segundos ({round(render_res['duration_seconds']/60, 2)} minutos)")
    print(f"🎬 Frames:     {render_res['duration_frames']} frames")
    print(f"📦 Tamaño:     {render_res['size_mb']} MB")
    print(f"⚡ Render:     {render_res['render_time_seconds']}s")
    print("=" * 65)

if __name__ == "__main__":
    asyncio.run(main())
