# Configuration GitHub Pages

Pour que GitHub Pages serve correctement les artefacts et endpoints JSON :

1. **Branche à publier** : Configurez GitHub Pages pour utiliser la branche `gh-pages`.
2. **Dossier racine** : Choisissez `/` (racine) comme dossier source.
3. **Vérification** : Après exécution du workflow, vérifiez que les fichiers sont bien présents sur https://electron-rare.github.io/Kill_LIFE/

## Procédure

- Allez dans **Settings > Pages** du dépôt GitHub.
- Sélectionnez :
  - **Source** : `gh-pages`
  - **Dossier** : `/` (root)
- Sauvegardez.
- Relancez le workflow `pages_publish.yml` si besoin.

## Points d’attention
- Le workflow doit créer le dossier `public/` et le publier sur `gh-pages`.
- Les fichiers JSON, endpoints.md, evidence pack doivent être dans `public/`.
- Shields.io doit pointer vers : `https://electron-rare.github.io/Kill_LIFE/docs/badges/<badge>.json`

---

> Si le dossier public n’est pas à la racine, adaptez le chemin dans le workflow et la configuration Pages.
> Pour une vérification rapide, utilisez : `curl https://electron-rare.github.io/Kill_LIFE/docs/badges/supply_chain_badge.json`

---

**Astuce** : Pour une publication immédiate, utilisez l’action `workflow_dispatch` dans GitHub Actions.
