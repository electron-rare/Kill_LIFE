---
name: installProject
description: Démarre l’installation complète du projet Kill_LIFE.
argument-hint: Spécifie options (Docker, hardware, firmware, doc, compliance).
---
Démarre l’installation du projet :
1. Lire README, INSTALL.md
2. Cloner le repo
3. Lancer le script install_kill_life.sh
4. Installer les dépendances (Python, PlatformIO, KiCad, mkdocs, Docker)
5. Initialiser la spec (tools/ai/specify_init.py)
6. Choisir le profil compliance (tools/compliance/use_profile.py)
7. Build & tests firmware (pio run/test)
8. Pipeline hardware (tools/hw/hw_gate.sh, watch_hw.py)
9. Générer la documentation (mkdocs build)
10. Activer Docker si besoin (docker-compose)
11. Vérifier la sécurité OpenClaw
12. Archiver evidence pack
13. Onboarding & feedback
> Voir checklist commune : plan_wizard_agents_coordination.prompt.md