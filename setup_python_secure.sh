#!/bin/bash
# Script de setup sécurisé pour Python dans le repo Kill_LIFE
# Crée un environnement virtuel, installe les dépendances, audite la sécurité

set -e

# 1. Création de l'environnement virtuel
if [ ! -d ".venv" ]; then
    echo "Création de l'environnement virtuel (.venv)..."
    python3 -m venv .venv
else
    echo "Environnement virtuel déjà présent."
fi

# 2. Activation de l'environnement
source .venv/bin/activate

# 3. Mise à jour des outils de base
pip install --upgrade pip setuptools wheel

# 4. Installation des dépendances
if [ -f requirements-mistral.txt ]; then
    pip install -r requirements-mistral.txt
fi
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

# 5. Audit de sécurité
if ! pip show pip-audit > /dev/null 2>&1; then
    pip install pip-audit
fi
pip-audit || echo "Avertissement : pip-audit a détecté des vulnérabilités."

# 6. Conseils supplémentaires
cat <<EOF

Conseils sécurité :
- Ne versionnez pas .venv ni vos secrets.
- Ajoutez .venv à .gitignore.
- Mettez à jour vos dépendances régulièrement.
- Utilisez pip-audit pour vérifier les vulnérabilités.
EOF

# 7. Fin
