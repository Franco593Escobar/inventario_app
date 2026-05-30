#!/bin/zsh
# ─────────────────────────────────────────────────────────────────────────────
# stop.sh  —  Detener el servidor de Flutter Web
# ─────────────────────────────────────────────────────────────────────────────

PID_FILE="/tmp/flutter_server_8080.pid"
PORT=8080

if [[ -f "$PID_FILE" ]]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    echo "✓ Servidor detenido (PID $PID)"
  else
    echo "→ El servidor ya no estaba corriendo"
    rm -f "$PID_FILE"
  fi
else
  # Intentar por puerto
  FOUND=$(lsof -ti:$PORT 2>/dev/null)
  if [[ -n "$FOUND" ]]; then
    echo "$FOUND" | xargs kill -9
    echo "✓ Servidor en puerto $PORT detenido"
  else
    echo "→ No hay servidor corriendo en el puerto $PORT"
  fi
fi
