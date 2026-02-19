# Easter Egg musique expérimentale
# "Le script d’installation module le pipeline comme un Oramics : chaque étape, chaque evidence pack, est une invention sonore." — Daphne Oram
#!/bin/bash
# install_kill_life.sh — Installation complète pour Kill_LIFE
# Usage : ./install_kill_life.sh [feature-or-epic] [profile]

set -e

FEATURE=${1:-demo-feature}
PROFILE=${2:-prototype}

# 1. Mise à jour du système
if command -v apt-get &> /dev/null; then
  sudo apt-get update
  sudo apt-get install -y python3 python3-pip python3-venv git docker.io docker-compose
elif command -v brew &> /dev/null; then
  brew update
  brew install python git docker docker-compose
fi

if [ ! -d Kill_LIFE ]; then
  git clone https://github.com/electron-rare/Kill_LIFE.git
fi
cd Kill_LIFE

# 5. Environnement Python (création AVANT activation)
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
python3 -m pip install -U pip

# 3. Initialiser la spec
if [ ! -d specs ]; then
  echo "[INFO] Initialisation du dossier specs..."
  PYTHONPATH="$(pwd)" .venv/bin/python tools/ai/specify_init.py --name "$FEATURE"
else
  echo "[INFO] Dossier specs déjà présent."
fi

# 4. Profil compliance
echo "[INFO] Activation du profil compliance ($PROFILE)..."
PYTHONPATH="$(pwd)" .venv/bin/python tools/compliance/use_profile.py --profile "$PROFILE"

# 6. Dépendances AI & hardware
if [ -f tools/ai/requirements.txt ]; then
  pip install -r tools/ai/requirements.txt
fi
if [ -f tools/hw/schops/requirements.txt ]; then
  pip install -r tools/hw/schops/requirements.txt
fi
pip install kicad-sch-api kicad-sch-mcp

# 7. Dépendances firmware
cd firmware || exit 1
python3 -m pip install -U platformio
pio run -e esp32s3_arduino
pio test -e native
cd ..

# 8. Pipeline hardware (KiCad)
bash tools/hw/hw_gate.sh hardware/kicad
python3 tools/watch/watch_hw.py

# 9. Documentation
python3 -m pip install -U mkdocs
mkdocs build --strict

# 10. Docker (optionnel)
if [ -f docker-compose.yml ]; then
  echo "[INFO] Installation et lancement des containers Docker..."
  sudo docker-compose up -d
fi

# 11. OpenClaw & agents
if [ -f openclaw/README.md ]; then
  echo "[INFO] Sécurité OpenClaw : sandbox obligatoire, jamais d'accès aux secrets ou au code source."
fi
for agent in agents/*.md; do
  echo "[INFO] Prompt agent disponible : $agent"
done

# 12. Fin

echo "\n✅ Installation complète terminée !\n"
echo "- Dossier specs : specs/$FEATURE"
echo "- Profil compliance : $PROFILE"
echo "- Firmware build & tests : OK"
echo "- Pipeline hardware : OK"
echo "- Documentation générée dans site/"
echo "- Docker containers : lancés (si docker-compose.yml présent)"
echo "- OpenClaw & agents : setup OK"
