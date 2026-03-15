# KiCad benchmark matrix

Last updated: 2026-03-14

Source canonique pour `K-025` dans `Kill_LIFE`.

References de cadrage absorbees dans ce lot:

- provenance MCP/CAD: `docs/MCP_CAD_PROVENANCE_2026-03-14.md`
- setup MCP local: `docs/MCP_SETUP.md`
- support MCP local: `docs/MCP_SUPPORT_MATRIX.md`
- stack CAD locale: `deploy/cad/README.md`
- backlog executable: `specs/mcp_tasks.md`

## Objectif

Transformer le backlog benchmark `KiAuto` + `kicad-automation-scripts` en une decision operatoire exploitable, sans introduire de dependance externe par defaut et sans desserrer le garde-fou `bash tools/tui/cad_mcp_audit.sh audit`.

## Regle de base

- chaine canonique conservee: `kicad-cli` + `kicad-mcp`
- outillage adjacent compare comme appoint seulement
- aucun `pip install`, clone externe ou image supplementaire n'est ajoute par defaut dans ce repo pour `K-025`
- les logs bruts du lot vivent temporairement sous `.ops/kicad-benchmark/`, puis sont purges apres extraction des conclusions durables

## Matrice de comparaison

Inference explicite:
- la comparaison ci-dessous est deduite des references operatoires du `2026-03-13` et `2026-03-14`, plus de l'architecture actuelle de `Kill_LIFE`
- elle ne suppose ni checkout local de `KiAuto`, ni checkout local de `kicad-automation-scripts`

| Surface / chaine | Provenance | Dependance externe par defaut | ERC / DRC | Export / doc | Fit `Kill_LIFE` | Decision | Position operatoire |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `kicad-cli` + `kicad-mcp` | officiel + custom local | aucune nouvelle dependance | fort | fort | maximal | keep | chaine canonique deja portee par `tools/hw/cad_stack.sh`, `tools/hw/run_kicad_mcp.sh` et `mcp.json` |
| `KiAuto` | community valide | oui, explicite et optionnelle | fort | moyen a fort | moyen | adopt | appoint cible si un lot KiCad reclame des exports ou checks au-dela de la chaine canonique |
| `kicad-automation-scripts` | community valide | oui, explicite et optionnelle | moyen | moyen | faible | ignore | reference historique de patterns Docker/doc, pas une dependance runtime a introduire dans ce repo |

## Lecture de la decision

### `keep` — `kicad-cli` + `kicad-mcp`

- deja supporte, documente et aligne avec les wrappers locaux
- couvre le besoin courant sans nouvelle dette de packaging
- reste compatible avec le garde-fou `tools/tui/cad_mcp_audit.sh`

### `adopt` — `KiAuto`, mais seulement sur activation explicite

- utile comme appoint quand un lot concret demande plus de checks ERC/DRC/export que la chaine canonique n'en expose proprement
- ne doit pas devenir un prerequis repo-global
- doit rester active via un lot ou un profil explicite, avec documentation et logs dedies

Gates d'activation pour un futur lot:

1. un besoin projet reel depasse `kicad-cli` + `kicad-mcp`
2. l'ajout reste optionnel et documente, sans installation implicite
3. le garde-fou `bash tools/tui/cad_mcp_audit.sh audit` est rejoue avant promotion
4. les logs bruts du benchmark sont purges apres synthese durable

### `ignore` — `kicad-automation-scripts` comme dependance runtime

- sa valeur principale ici est documentaire et historique
- le repo possede deja `tools/hw/cad_stack.sh` pour les boucles locales Docker/headless
- l'introduire comme dependance operative dupliquerait la chaine locale plus qu'il ne la clarifierait

## Outillage repo-local livre par `K-025`

Le helper suivant sert a produire une trace locale du benchmark sans dependances additionnelles:

```bash
bash tools/tui/kicad_benchmark_review.sh report
bash tools/tui/kicad_benchmark_review.sh matrix
bash tools/tui/kicad_benchmark_review.sh doctor
bash tools/tui/kicad_benchmark_review.sh purge --yes
```

Contrat:

- `report`: genere `.ops/kicad-benchmark/report.md` plus des logs bruts temporaires
- `matrix`: imprime la matrice de comparaison et la journalise temporairement
- `doctor`: capture l'etat local utile au benchmark
- `purge`: supprime les `*.log` bruts et conserve `report.md`

Le helper ne remplace pas le garde-fou CAD/MCP:

```bash
bash tools/tui/cad_mcp_audit.sh audit
```

## Decision durable pour le repo

- garder `kicad-cli` + `kicad-mcp` comme chemin canonique
- adopter `KiAuto` uniquement comme appoint opt-in, sur lot futur explicitement motive
- ignorer `kicad-automation-scripts` comme dependance runtime du repo
- conserver `InteractiveHtmlBom` comme reference adjacente pour la couche doc/fabrication, hors scope direct de `K-025`
