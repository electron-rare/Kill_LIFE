#!/bin/bash
# Script pour vérifier qu'aucun dossier du dépôt principal ou home partagé n'est monté dans la VM
set -euo pipefail

# Recherche de montages suspects
MOUNTS=$(mount | grep -E '/Users|/home|Kill_LIFE|/mnt|/media|VBoxShared|vboxsf')

if [ -n "$MOUNTS" ]; then
  echo "[ALERTE] Un dossier potentiellement sensible est monté dans la VM :"
  echo "$MOUNTS"
  exit 1
else
  echo "[OK] Aucun dossier du dépôt principal ou home partagé n'est monté."
fi
