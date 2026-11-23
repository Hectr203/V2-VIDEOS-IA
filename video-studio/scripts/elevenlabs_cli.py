#!/usr/bin/env python3
"""
CLI operativo de ElevenLabs para V2-VIDEOS-IA.

Permite:
1. Consultar el listado dinámico de voces disponibles (nombre, ID, género, edad, acento, estilo)
   antes de generar un video, con filtros opcionales (ej. `--edad young`).
2. Inspeccionar en vivo el estado del Gateway de rotación multi-cuenta (saldo restante por cuenta,
   umbral de seguridad y cuenta activa) sin exponer nunca claves reales.

Uso:
  python3 video-studio/scripts/elevenlabs_cli.py voces
  python3 video-studio/scripts/elevenlabs_cli.py voces --edad young --genero male
  python3 video-studio/scripts/elevenlabs_cli.py estado
  python3 video-studio/scripts/elevenlabs_cli.py estado --json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1] / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from services.elevenlabs_gateway import ElevenLabsGateway


def cmd_estado(args: argparse.Namespace) -> int:
    gw = ElevenLabsGateway()
    status = gw.get_pool_status(force_refresh=True)
    if args.json:
        print(json.dumps(status, ensure_ascii=False, indent=2))
        return 0 if status["service_healthy"] or not status["configured"] else 2

    print("\n=== GATEWAY ELEVENLABS · ESTADO DEL POOL DE CUENTAS ===")
    if not status["configured"]:
        print("  No hay API keys configuradas. Añade ELEVENLABS_API_KEY_1..6 en video-studio/backend/.env")
        return 1

    print(f"  Cuentas configuradas:    {status['total_accounts']}")
    print(f"  Cuentas listas (>= {status['min_credits_threshold']}): {status['available_accounts']}")
    print(f"  Cuenta activa:           {status['active_account'] or 'NINGUNA DISPONIBLE'}")
    print(f"  Saldo total combinado:   {status['total_remaining_characters']:,} caracteres")
    print(f"  Modelo por defecto:      {status['default_model']}\n")

    for acc in status["accounts"]:
        rem = f"{acc['remaining_characters']:,}" if acc["remaining_characters"] is not None else "n/a"
        lim = f"{acc['character_limit']:,}" if acc["character_limit"] is not None else "n/a"
        mark = "✓" if acc["meets_threshold"] else "✗"
        err = f" | {acc['last_error']}" if acc["last_error"] else ""
        print(f"  [{mark}] {acc['account']:<10} ({acc['key_hint']}) | estado={acc['status']:<13} | saldo={rem:>8} / {lim:<8} | plan={acc['tier']}{err}")
    print()
    return 0 if status["service_healthy"] else 2


def cmd_voces(args: argparse.Namespace) -> int:
    gw = ElevenLabsGateway()
    try:
        res = gw.list_voices(age=args.edad, gender=args.genero, search=args.buscar)
    except Exception as exc:
        print(f"ERROR consultando voces de ElevenLabs: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0

    print(f"\n=== VOCES DISPONIBLES DE ELEVENLABS ({res['total']} encontradas · vía {res['account_used']}) ===")
    print(f"  {'#':<3} {'Nombre':<18} {'Género':<10} {'Edad':<9} {'Acento':<12} {'Estilo / Uso':<22} {'Voice ID'}")
    print("  " + "-" * 96)
    for i, v in enumerate(res["voices"], 1):
        estilo = f"{v['style']} / {v['use_case']}"[:22]
        print(
            f"  {i:<3} {v['name'][:17]:<18} {v['gender'][:9]:<10} {v['age'][:8]:<9} "
            f"{v['accent'][:11]:<12} {estilo:<22} {v['id']}"
        )
    print("\n  Tip: filtra voces más jóvenes con `--edad young` o por género con `--genero male|female`.\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Gestor CLI del Gateway de ElevenLabs y selector de voces.")
    sub = parser.add_subparsers(dest="comando", required=True)

    p_estado = sub.add_parser("estado", help="Consulta salud y créditos restantes de todas las cuentas del gateway.")
    p_estado.add_argument("--json", action="store_true", help="Salida JSON estructurada.")
    p_estado.set_defaults(func=cmd_estado)

    p_voces = sub.add_parser("voces", help="Lista las voces reales disponibles en ElevenLabs con edad, género y estilo.")
    p_voces.add_argument("--edad", default=None, help="Filtrar por edad: young/joven, middle_aged/adulto, old/mayor.")
    p_voces.add_argument("--genero", default=None, help="Filtrar por género: male/masculino, female/femenino.")
    p_voces.add_argument("--buscar", default=None, help="Buscar por nombre, acento, estilo o descripción.")
    p_voces.add_argument("--json", action="store_true", help="Salida JSON estructurada.")
    p_voces.set_defaults(func=cmd_voces)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
