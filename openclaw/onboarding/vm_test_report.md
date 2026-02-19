# Modèle de documentation pour tests réalisés en VM (à compléter dans onboarding)

## Rapport de test VM OpenClawSandbox

- Date : $(date)
- Utilisateur : <user>
- Version Ubuntu : 24.04 Minimal
- Version OpenClaw : $(~/.local/bin/openclaw --version 2>/dev/null || echo "N/A")
- Scripts exécutés :
  - install_packages.sh
  - scan_secrets.sh
  - check_mounts.sh
  - check_openclaw.sh
  - openclaw_check.sh
  - onboarding_simulation.sh
  - check_observer_only.sh
- Résultats :
  - Tous les scripts ont été exécutés sans erreur (à compléter)
  - Aucun secret/token détecté
  - Politique observer-only respectée
  - VM détruite après usage

## Commentaires / Retours
- ...
