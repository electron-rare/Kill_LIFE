# Spec - refonte globale YiACAD / Kill_LIFE (2026-03-20)

## Probleme

Le projet est deja riche et largement outille, mais sa complexite operationnelle grandit plus vite que sa couche de pilotage globale. Les briques sont presentes; ce qui manque encore est une convergence forte entre audit global, lots suivants, IA d'orchestration, shells natifs YiACAD, plans, TODOs, et cockpit operateur.

## Objectifs

- Fournir une vue globale unique de la refonte YiACAD.
- Prioriser les integrations IA a forte valeur sans augmenter la dette de coordination.
- Clarifier les zones matures, les zones fragmentees et les prochaines priorites.
- Outiller une TUI dediee avec logs pour piloter cette refonte globale.
- Relier explicitement la refonte globale a `T-UX-004` et au backend YiACAD futur.

## Non-objectifs

- Refaire tous les manifests existants.
- Compiler ou tester les forks CAD dans cette passe.
- Remplacer immediatement `yiacad_native_ops.py` par un backend compile.

## Utilisateurs

- Operateur principal
- Agents de coordination / planning
- Agents CAD / UI / docs
- Agents mesh / ZeroClaw / MCP

## Surfaces concernees

- `README.md`
- `docs/*`
- `specs/*`
- `tools/cockpit/*`
- `tools/cad/*`
- `.runtime-home/cad-ai-native-forks/*`

## Workstreams

### WS1 - Audit global

- produire un audit structurel priorise
- identifier matures / fragmente / opportunites

### WS2 - Integration IA

- produire la matrice d'integration IA par surface
- definir les garde-fous et priorites

### WS3 - Documentation et cartes

- produire feature map globale
- relier README, plan, todo, spec et recherche

### WS4 - Pilotage operateur

- fournir une TUI globale YiACAD avec logs
- aligner la documentation operatoire avec cette nouvelle entree

## Criteres d'acceptation

- un audit global court et priorise existe
- une evaluation des integrations IA prioritaires existe
- une feature map Mermaid globale existe
- une TUI globale YiACAD existe avec logs
- README + plan + todo global referencent les nouveaux livrables
- la gouvernance agentique est explicitement rattachee a cette nouvelle passe

## Prochain lots relies

- `T-UX-004`: command palette, review center, inspector persistant
- `T-ARCH-101`: backend YiACAD plus stable que le runner Python local
- `T-OPS-118`: rationalisation des TUI et de la retention logs
