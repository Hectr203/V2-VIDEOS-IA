#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BACKEND_DIR="$DIR/backend"
FRONTEND_DIR="$DIR/frontend"
ASSEMBLER_DIR="$(dirname "$DIR")/videoAssembler"

find_free_port() {
  node -e 'const net = require("node:net"); const s = net.createServer(); s.listen(0, "127.0.0.1", () => { console.log(s.address().port); s.close(); });'
}

VIDEO_STUDIO_HOST="${VIDEO_STUDIO_HOST:-127.0.0.1}"
VIDEO_STUDIO_BROWSER_HOST="${VIDEO_STUDIO_BROWSER_HOST:-localhost}"
VIDEO_STUDIO_BACKEND_PORT="${VIDEO_STUDIO_BACKEND_PORT:-8000}"
VIDEO_STUDIO_FRONTEND_PORT="${VIDEO_STUDIO_FRONTEND_PORT:-$(find_free_port)}"
VIDEO_ASSEMBLER_PORT="${VIDEO_ASSEMBLER_PORT:-$(find_free_port)}"
while [ "$VIDEO_ASSEMBLER_PORT" = "$VIDEO_STUDIO_FRONTEND_PORT" ]; do
  VIDEO_ASSEMBLER_PORT="$(find_free_port)"
done

BACKEND_PID=""
FRONTEND_PID=""
ASSEMBLER_PID=""

cleanup() {
  trap - EXIT INT TERM
  for pid in "$BACKEND_PID" "$FRONTEND_PID" "$ASSEMBLER_PID"; do
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi
  done
  for pid in "$BACKEND_PID" "$FRONTEND_PID" "$ASSEMBLER_PID"; do
    if [ -n "$pid" ]; then wait "$pid" 2>/dev/null || true; fi
  done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "=========================================================="
echo "🎬 INICIANDO VIDEO STUDIO IA (Estilo Resultaaquee)"
echo "=========================================================="

# 1. Iniciar Backend FastAPI
echo "🚀 Iniciando Backend FastAPI en http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_STUDIO_BACKEND_PORT..."
source "$BACKEND_DIR/.venv/bin/activate"
python3 -m uvicorn main:app --app-dir "$BACKEND_DIR" --host "$VIDEO_STUDIO_HOST" --port "$VIDEO_STUDIO_BACKEND_PORT" &
BACKEND_PID=$!

# 2. Iniciar Frontend Vite
echo "💻 Iniciando panel Video Studio en http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_STUDIO_FRONTEND_PORT..."
cd "$FRONTEND_DIR"
VIDEO_STUDIO_HOST="$VIDEO_STUDIO_HOST" \
VIDEO_STUDIO_FRONTEND_PORT="$VIDEO_STUDIO_FRONTEND_PORT" \
VIDEO_STUDIO_BACKEND_PORT="$VIDEO_STUDIO_BACKEND_PORT" \
VIDEO_STUDIO_STRICT_PORT=1 \
VITE_VIDEO_ASSEMBLER_URL="http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_ASSEMBLER_PORT" \
npm run dev -- --strictPort &
FRONTEND_PID=$!

# 3. Iniciar el editor multipista hermano
echo "🎞️  Iniciando Video Assembler en http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_ASSEMBLER_PORT..."
cd "$ASSEMBLER_DIR"
VIDEO_STUDIO_BACKEND_PORT="$VIDEO_STUDIO_BACKEND_PORT" \
npm run dev -- --host "$VIDEO_STUDIO_HOST" --port "$VIDEO_ASSEMBLER_PORT" --strictPort &
ASSEMBLER_PID=$!

echo ""
echo "✅ TODO LISTO:"
echo "   - Video Studio:  http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_STUDIO_FRONTEND_PORT"
echo "   - Editor avanzado: http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_ASSEMBLER_PORT"
echo "   - Backend API:   http://$VIDEO_STUDIO_BROWSER_HOST:$VIDEO_STUDIO_BACKEND_PORT/docs"
echo "   - Carpeta Video: $DIR/output/"
echo ""
echo "Presiona CTRL+C para detener los servidores."

wait -n "$BACKEND_PID" "$FRONTEND_PID" "$ASSEMBLER_PID"
