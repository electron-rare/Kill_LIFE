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
Le workflow CI/CD compile et teste le firmware sur ESP, STM et Linux automatiquement.

Pour lancer manuellement :
```bash
python tools/build_firmware.py esp
python tools/test_firmware.py esp
python tools/collect_evidence.py esp
```
Remplace `esp` par `stm` ou `linux` selon la cible.

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

---

## 🤝 Contribuer

1. Forker le repo et créer une branche dédiée
2. Proposer une PR en suivant le modèle (voir `docs/`)
3. Passer les gates (checklists de conformité)
4. Ajouter un evidence pack si besoin
5. Demander une review ou de l’aide via une issue

Pour toute question, consulte la FAQ ou ouvre une issue !

Pour toute question, consulte la FAQ ou ouvre une issue !
