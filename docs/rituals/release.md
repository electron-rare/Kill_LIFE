# Rituel — Release

## Pré-requis
- Gate repo-local stable OK
- Evidence pack complet
- Notes de release prêtes
- Tag de release prepare (`v*`)

## Étapes
- Bump version
- Créer le tag `v*`
- Publier les artefacts via `release_signing.yml`
  - chemin canonique: push du tag
  - fallback opérateur: `workflow_dispatch` avec `release_tag` explicite
- Changelog

## Post-release
- Retours terrain
- Bugs P0 → hotfix
