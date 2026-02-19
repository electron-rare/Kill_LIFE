#!/bin/bash
# Script pour automatiser la simulation d'onboarding avec tous les guides/tests du dossier openclaw/onboarding/
set -euo pipefail
ONBOARD_DIR="/tmp/onboarding"

# Copier le dossier onboarding dans la VM (à adapter selon votre méthode de transfert)
# scp -r openclaw/onboarding <user>@<ip_VM>:/tmp/

# Exécuter tous les scripts .sh et afficher tous les fichiers .md
for file in "$ONBOARD_DIR"/*; do
  if [[ "$file" == *.sh ]]; then
    echo "[INFO] Exécution du script $file"
    bash "$file" || true
  elif [[ "$file" == *.md ]]; then
    echo "[INFO] Affichage du guide $file"
    head -20 "$file"
  fi
done
