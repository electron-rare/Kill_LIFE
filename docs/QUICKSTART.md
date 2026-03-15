# Quickstart – Onboarding Express

Bienvenue sur Kill_LIFE ! Voici comment démarrer en quelques minutes :

## ✅ Checklist Onboarding Express

- [ ] Cloner le dépôt
- [ ] Installer les dépendances
- [ ] Lancer un build/test minimal
- [ ] Ouvrir la documentation locale (optionnel)
- [ ] Lire le README.md et la FAQ

## 1. Cloner le dépôt
```bash
git clone https://github.com/electron-rare/Kill_LIFE.git
cd Kill_LIFE
```

## 2. Installer les dépendances (exemple Python)
```bash
pip install -r requirements-mistral.txt
```

## 3. Build et test minimal (exemple PlatformIO)

## 3bis. Build et test multi-cible (CI/CD agentique)
Le workflow CI/CD actuellement câblé build l’ESP (`esp32s3_arduino`) et teste la cible native (`linux` -> `native`).

Par défaut, les wrappers tentent `pio` en natif, puis basculent automatiquement sur `tools/hw/cad_stack.sh pio` si `pio` n’est pas installé sur l’hôte.
Tu peux forcer le runner avec `KILL_LIFE_PIO_MODE=native` ou `KILL_LIFE_PIO_MODE=container`.

Si tu veux une voie native reproductible depuis le venv repo-local :
```bash
bash tools/bootstrap_python_env.sh --with-platformio
```

Pour lancer manuellement :
```bash
KILL_LIFE_PIO_MODE=native ./.venv/bin/python tools/build_firmware.py esp
./.venv/bin/python tools/collect_evidence.py esp
./.venv/bin/python tools/verify_evidence.py esp

KILL_LIFE_PIO_MODE=native ./.venv/bin/python tools/test_firmware.py linux
./.venv/bin/python tools/collect_evidence.py linux
./.venv/bin/python tools/verify_evidence.py linux
```
`stm` reste non supporté tant qu’aucune cible STM n’existe dans `firmware/platformio.ini`.

Les evidence packs sont générés dans `docs/evidence/`.

Pour vérifier la couverture :
```bash
python coverage_badge.py
```

## 4. Lancer la documentation locale (optionnel)
```bash
mkdocs serve
```

## 5. Aller plus loin
- Lire le README.md pour la structure du projet
- Explorer les dossiers `specs/`, `docs/`, `firmware/`, `hardware/`
- Suivre les guides détaillés dans `docs/`
- Consulter la [FAQ](docs/FAQ.md) pour les questions fréquentes

## 6. Outils CAD/EDA intégrés

`Kill_LIFE` embarque maintenant une stack CAD/EDA locale :

```bash
make cad-doctor
make cad-kicad CAD_ARGS="version"
make cad-pio CAD_ARGS="system info"
KILL_LIFE_PIO_MODE=container python3 tools/test_firmware.py linux

tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh pio system info
```

Le workspace monté est `Kill_LIFE` par défaut.

Les wrappers locaux qui lancent des runtimes Python/Node ou des conteneurs remappés utilisent un `HOME` explicite local au repo. La règle est documentée dans [RUNTIME_HOME.md](RUNTIME_HOME.md).

---

## 🤝 Contribuer

1. Forker le repo et créer une branche dédiée
2. Proposer une PR en suivant le modèle (voir `docs/`)
3. Passer les gates (checklists de conformité)
4. Ajouter un evidence pack si besoin
5. Demander une review ou de l’aide via une issue

Pour toute question, consulte la FAQ ou ouvre une issue !

Pour toute question, consulte la FAQ ou ouvre une issue !
