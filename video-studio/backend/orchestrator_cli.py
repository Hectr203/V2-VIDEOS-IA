#!/usr/bin/env python3
import asyncio
import argparse
import sys
import os
import json
import time

from services.project_manager import ProjectManager
from services.render_service import render_project, render_single_scene

async def main():
    parser = argparse.ArgumentParser(description="Orquestador CLI de Video Studio IA para Agentes y Chat")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcomando: create
    p_create = subparsers.add_parser("create", help="Crear nuevo proyecto y generar guion/storyboard")
    p_create.add_argument("--tema", "-t", type=str, required=True, help="Tema o instrucción")
    p_create.add_argument("--duracion", "-d", type=int, default=60, help="Duración en segundos (ej: 60, 300 para 5 min, 600 para 10 min)")
    p_create.add_argument("--estilo", "-e", type=str, default="curiosity", help="Estilo narrativo")
    p_create.add_argument("--proveedor-voz", type=str, default="edge-tts", help="edge-tts, vibevoice, elevenlabs, etc.")
    p_create.add_argument("--voz", "-v", type=str, default="es-ES-AlvaroNeural", help="ID de la voz")

    # Subcomando: status
    p_status = subparsers.add_parser("status", help="Consultar estado de un proyecto")
    p_status.add_argument("--proyecto", "-p", type=str, required=True, help="ID del proyecto")

    # Subcomando: edit-scene
    p_edit = subparsers.add_parser("edit-scene", help="Editar texto o parámetros de una escena")
    p_edit.add_argument("--proyecto", "-p", type=str, required=True, help="ID del proyecto")
    p_edit.add_argument("--escena", "-s", type=int, required=True, help="Número de escena")
    p_edit.add_argument("--texto", type=str, default=None, help="Nuevo texto de narración")
    p_edit.add_argument("--callout", type=str, default=None, help="Nuevo banner en pantalla")
    p_edit.add_argument("--sticker", type=str, default=None, help="Nuevo sticker SVG")

    # Subcomando: regenerate-scene
    p_regen = subparsers.add_parser("regenerate-scene", help="Regenerar selectivamente una escena")
    p_regen.add_argument("--proyecto", "-p", type=str, required=True, help="ID del proyecto")
    p_regen.add_argument("--escena", "-s", type=int, required=True, help="Número de escena")
    p_regen.add_argument("--modo", "-m", type=str, default="all", choices=["all", "voice", "visual"], help="Modo de regeneración")

    # Subcomando: render
    p_render = subparsers.add_parser("render", help="Renderizar video completo o escena individual a MP4")
    p_render.add_argument("--proyecto", "-p", type=str, required=True, help="ID del proyecto")
    p_render.add_argument("--escena", "-s", type=int, default=None, help="Escena individual a previsualizar")

    args = parser.parse_args()

    if args.command == "create":
        print(f"\n[Orchestrator] Creando proyecto sobre: '{args.tema}' (Objetivo: {args.duracion}s)...")
        res = ProjectManager.create_project(
            topic=args.tema,
            target_duration=args.duracion,
            style=args.estilo,
            voice_provider=args.proveedor_voz,
            voice_id=args.voz
        )
        meta = res["project"]
        scenes = res["scenes"]
        print(f"✓ Proyecto creado: {meta['id']}")
        print(f"✓ Escenas generadas: {len(scenes)}")
        print(f"✓ Estilo visual: {meta.get('visual_theme')}\n")
        for sc in scenes[:5]:
            print(f"  [Escena #{sc['id']}] Acto {sc.get('act', 1)} | Callout: {sc['callout']} | {sc['narrative_text'][:50]}...")
        if len(scenes) > 5:
            print(f"  ... y {len(scenes)-5} escenas más.")

    elif args.command == "status":
        proj = ProjectManager.get_project(args.proyecto)
        if not proj:
            print(f"Error: Proyecto '{args.proyecto}' no encontrado.")
            sys.exit(1)
        meta = proj["project"]
        scenes = proj["scenes"]
        print(f"\n[Proyecto: {meta['id']}]")
        print(f"Tema:             {meta['topic']}")
        print(f"Duración Real:    {meta.get('total_real_duration', 0)}s (Objetivo: {meta['target_duration_seconds']}s)")
        print(f"Escenas:          {len(scenes)}")
        print(f"Estado:           {meta.get('status')}")
        print(f"Video Final:      {meta.get('final_video_url') or 'Pendiente de render'}\n")

    elif args.command == "edit-scene":
        updates = {}
        if args.texto: updates["narrative_text"] = args.texto
        if args.callout: updates["callout"] = args.callout
        if args.sticker: updates["sticker"] = args.sticker
        res = ProjectManager.update_scene(args.proyecto, args.escena, updates)
        print(f"✓ Escena #{args.escena} actualizada con éxito en proyecto {args.proyecto}.")

    elif args.command == "regenerate-scene":
        print(f"[Orchestrator] Regenerando escena #{args.escena} (modo: {args.modo})...")
        res = await ProjectManager.regenerate_scene(args.proyecto, args.escena, mode=args.modo)
        print(f"✓ Escena #{args.escena} regenerada con éxito.")

    elif args.command == "render":
        if args.escena is not None:
            print(f"[Orchestrator] Sintetizando si es necesario y renderizando previsualización de escena #{args.escena}...")
            proj = ProjectManager.get_project(args.proyecto)
            if not proj:
                print(f"Error: Proyecto '{args.proyecto}' no encontrado.")
                sys.exit(1)
            scene = next((s for s in proj["scenes"] if s["id"] == args.escena), None)
            if not scene:
                print(f"Error: Escena #{args.escena} no encontrada.")
                sys.exit(1)

            if scene["status"] != "audio_ready" or not scene["audio_path"] or not os.path.exists(scene["audio_path"]):
                await ProjectManager.synthesize_scene_audio(args.proyecto, args.escena)
                proj = ProjectManager.get_project(args.proyecto)
                scene = next((s for s in proj["scenes"] if s["id"] == args.escena), None)

            filename = f"preview_{args.proyecto}_s{args.escena}_{int(time.time())}.mp4"
            res = render_single_scene(scene, filename)
            print(f"✓ Previsualización lista: {res['video_path']} ({res['duration_seconds']}s)")
        else:
            print(f"[Orchestrator] Sintetizando audios pendientes y renderizando proyecto completo {args.proyecto}...")
            proj = await ProjectManager.synthesize_all_project_audio(args.proyecto)
            filename = f"full_{args.proyecto}_{int(time.time())}.mp4"
            res = render_project(proj["project"], proj["scenes"], filename)
            print(f"\n🎉 ¡PRODUCCIÓN COMPLETA RENDERIZADA!")
            print(f"Ruta:      {res['video_path']}")
            print(f"Duración:  {res['duration_seconds']}s ({res['duration_frames']} frames)")
            print(f"Peso:      {res['size_mb']} MB")
            print(f"Tiempo:    {res['render_time_seconds']}s\n")

if __name__ == "__main__":
    asyncio.run(main())
