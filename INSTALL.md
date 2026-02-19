# Installation

Voir la version détaillée : `docs/INSTALL.md`.

## Prérequis
- Git
- Python 3.10+
- (optionnel) PlatformIO pour compiler le firmware
- (optionnel) KiCad pour le hardware

## Setup local (minimal)
```bash
python -m venv .venv
source .venv/bin/activate
pip install platformio

cd firmware
pio run -e esp32s3_idf || true
pio test -e native || true
```

## Setup GitHub (indispensable)
1. Créer les labels `ai:*` : `ai:spec ai:plan ai:tasks ai:impl ai:qa ai:docs ai:hold`
2. (Optionnel) Créer les labels `type:*` : `type:consulting type:systems type:design type:creative type:spike type:compliance`
3. Ajouter les secrets si utilisés (ex : `OPENAI_API_KEY`, `COPILOT_GITHUB_TOKEN`)
4. Vérifier que GitHub Actions est activé

## Démarrer
- Ouvrir une issue via un template (dans `.github/ISSUE_TEMPLATE/`)
- Triage (prio/risque/scope)
- Ajouter un label `ai:*` pour déclencher l’automatisation
