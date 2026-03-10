# Publication automatique des artefacts et endpoints sur GitHub Pages

## Objectif
Rendre accessibles publiquement les endpoints JSON des badges dynamiques et les artefacts CI/CD via GitHub Pages.

## Workflow recommandé
- Utiliser GitHub Actions pour publier docs/badges/*.json, endpoints.md, evidence pack et documentation sur la branche gh-pages.
- Déclencher le workflow à chaque push sur main ou release majeure.

## Exemple de workflow (pages_publish.yml)

```yaml
name: Publish Badges & Evidence to GitHub Pages
on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  publish-pages:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Préparer les artefacts
        run: |
          mkdir -p public
          cp -r docs/badges/*.json public/
          cp endpoints.md public/
          cp -r docs/evidence public/
      - name: Déployer sur gh-pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
          force_orphan: true
```

## Vérification
- Les endpoints et artefacts sont accessibles sur https://electron-rare.github.io/Kill_LIFE/
- Les badges shields.io peuvent pointer vers les endpoints publiés.

---

> Ce workflow doit être adapté si d’autres artefacts ou documentation doivent être publiés.
