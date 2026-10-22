#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BACKEND_DIR="$DIR/backend"
FRONTEND_DIR="$DIR/frontend"

echo "=========================================================="
echo "🎬 INICIANDO VIDEO STUDIO IA (Estilo Resultaaquee)"
echo "=========================================================="

# 1. Iniciar Backend FastAPI
echo "🚀 Iniciando Backend FastAPI en http://127.0.0.1:8000..."
source "$BACKEND_DIR/.venv/bin/activate"
python3 -m uvicorn main:app --app-dir "$BACKEND_DIR" --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# 2. Iniciar Frontend Vite
echo "💻 Iniciando Frontend React en http://localhost:5173..."
cd "$FRONTEND_DIR"
npm run dev &
FRONTEND_PID=$!

echo ""
echo "✅ TODO LISTO:"
echo "   - Interfaz Web:  http://localhost:5173"
echo "   - Backend API:   http://localhost:8000/docs"
echo "   - Carpeta Video: $DIR/output/"
echo ""
echo "Presiona CTRL+C para detener los servidores."

trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true; exit 0" INT TERM
wait
