#!/bin/bash
# Vérifie la présence de l'exécutable OpenClaw dans ~/.local/bin
set -euo pipefail
if [ -x "$HOME/.local/bin/openclaw" ]; then
  echo "[OK] OpenClaw installé dans ~/.local/bin/openclaw."
else
  echo "[ERREUR] OpenClaw n'est pas trouvé dans ~/.local/bin/openclaw."
  exit 1
fi
