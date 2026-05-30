#!/bin/zsh
# ─────────────────────────────────────────────────────────────────────────────
# dev.sh  —  Modo DESARROLLO con hot reload
#
# CÓMO USAR:
#   ./dev.sh
#
# DENTRO DEL TERMINAL (mientras corre):
#   r  → Hot reload   (aplica cambios de UI en ~1-2 seg, sin perder estado)
#   R  → Hot restart  (reinicia completo, más lento pero más limpio)
#   q  → Salir
#
# NOTA: Abre el browser en http://localhost:8080
# ─────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MODO DESARROLLO — Flutter Hot Reload"
echo "  http://localhost:8080"
echo "  [r] reload  [R] restart  [q] salir"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

flutter run \
  --device-id web-server \
  --web-port 8080 \
  --web-hostname localhost \
  --profile
