#!/bin/bash
# Script pour vérifier l'absence de commit/push dans la VM (politique observer-only)
set -euo pipefail

# Recherche des commandes git commit/push dans l'historique
if grep -qE 'git (commit|push)' ~/.bash_history 2>/dev/null; then
  echo "[ALERTE] Des commandes git commit/push ont été détectées dans l'historique."
  grep -E 'git (commit|push)' ~/.bash_history
  exit 1
else
  echo "[OK] Aucun commit/push détecté dans l'historique. Politique observer-only respectée."
fi
