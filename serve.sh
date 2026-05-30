#!/bin/zsh
# ─────────────────────────────────────────────────────────────────────────────
# serve.sh  —  Build release + servidor ESTABLE (sobrevive al cerrar VS Code)
#
# CÓMO USAR:
#   ./serve.sh          → build + inicia servidor
#   ./serve.sh --no-build  → solo inicia/reinicia servidor (sin rebuild)
#
# El servidor queda corriendo en segundo plano.
# Para detenerlo: ./stop.sh
# Logs: /tmp/flutter_server.log
# ─────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"

PID_FILE="/tmp/flutter_server_8080.pid"
LOG_FILE="/tmp/flutter_server.log"
PORT=8080
BUILD_DIR="$(pwd)/build/web"

# ── Detener servidor anterior si existe ──────────────────────────────────────
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "→ Deteniendo servidor anterior (PID $OLD_PID)..."
    kill "$OLD_PID"
    sleep 1
  fi
  rm -f "$PID_FILE"
fi

# Liberar puerto por si acaso
lsof -ti:$PORT | xargs kill -9 2>/dev/null

# ── Build (opcional) ─────────────────────────────────────────────────────────
if [[ "$1" != "--no-build" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Compilando Flutter Web (release)..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  flutter build web --release
  if [[ $? -ne 0 ]]; then
    echo "✗ Error en el build. Abortando."
    exit 1
  fi
fi

# ── Iniciar servidor desconectado del terminal ────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Iniciando servidor en puerto $PORT..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

nohup python3 -m http.server $PORT --directory "$BUILD_DIR" \
  > "$LOG_FILE" 2>&1 &

SERVER_PID=$!
echo $SERVER_PID > "$PID_FILE"

# Verificar que arrancó
sleep 1
if kill -0 "$SERVER_PID" 2>/dev/null; then
  echo ""
  echo "✓ Servidor corriendo en http://localhost:$PORT"
  echo "  PID: $SERVER_PID"
  echo "  Log: $LOG_FILE"
  echo "  Para detener: ./stop.sh"
  echo ""
else
  echo "✗ El servidor no pudo arrancar. Revisa: $LOG_FILE"
  exit 1
fi
