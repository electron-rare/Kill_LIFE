#!/bin/bash
# install_kill_life_full.sh — Installation complète et sécurisée pour Kill_LIFE
# Usage : ./install_kill_life_full.sh

set -e

# 1. Détection OS
if command -v apt-get &> /dev/null; then
  PKG_INSTALL="sudo apt-get install -y"
  PKG_UPDATE="sudo apt-get update"
elif command -v brew &> /dev/null; then
  PKG_INSTALL="brew install"
  PKG_UPDATE="brew update"
else
  echo "[ERREUR] Aucun gestionnaire de paquets compatible (apt-get ou brew) trouvé."
  exit 1
fi

# 2. Mise à jour du système
$PKG_UPDATE

# 3. Installation des outils système
$PKG_INSTALL python git docker docker-compose

# 4. Création et activation du venv
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate

# 5. Mise à jour pip
pip install --upgrade pip

# 6. Installation des dépendances Python
pip install -r requirements-mistral.txt
pip install -r tools/compliance/requirements.txt
pip install pip-audit
pip install platformio
pip install mkdocs
if [ -f tools/hw/schops/requirements.txt ]; then
  pip install -r tools/hw/schops/requirements.txt
fi
pip install kicad-sch-api
# NOTE : kicad-sch-mcp n'existe pas sur PyPI. Utilisez kicad-sch-api pour manipuler les schémas KiCad.
# Pour des fonctionnalités avancées, voir https://github.com/circuit-synth/mcp-kicad-sch-api

# 7. Audit sécurité
pip-audit || echo "Avertissement : pip-audit a détecté des vulnérabilités."

# 8. Vérification installation
pip list

# 9. Exécution script critique compliance
PYTHONPATH="$(pwd)" .venv/bin/python tools/compliance/use_profile.py prototype

# 10. Documentation
pip install mkdocs
mkdocs build --strict

# 11. Fin
cat <<EOF

✅ Installation complète terminée !
- Environnement virtuel : .venv
- Dépendances Python installées
- Audit sécurité effectué
- Compliance activé
- Documentation générée

Consultez README.md, INSTALL.md, RUNBOOK.md pour les guides et troubleshooting.
EOF
