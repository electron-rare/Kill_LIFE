# YiACAD Backend Operator Proof - 2026-03-21

## Objectif

Publier une preuve opérateur canonique qui valide, sans ouvrir les GUI complètes, la chaîne:

- helper shell KiCad
- helper workbench FreeCAD
- façade locale `tools/cad/yiacad_backend_service.py`
- contrat `uiux_output`

## Entrée canonique

- commande: `bash tools/cockpit/yiacad_backend_proof.sh --action run`

## Ce que la preuve vérifie

1. la façade locale YiACAD répond via `status`
2. la façade locale répond via `invoke status`
3. le helper KiCad passe bien par la façade et restitue un payload YiACAD structuré
4. le helper FreeCAD passe bien par la façade et restitue un payload YiACAD structuré
5. les champs canoniques `component`, `surface`, `action`, `execution_mode`, `status`, `severity`, `summary`, `artifacts`, `next_steps` sont présents

## Artefacts produits

- `artifacts/yiacad_backend_proof/<timestamp>/backend_status.json`
- `artifacts/yiacad_backend_proof/<timestamp>/backend_invoke_status.json`
- `artifacts/yiacad_backend_proof/<timestamp>/kicad_transport.json`
- `artifacts/yiacad_backend_proof/<timestamp>/freecad_transport.json`
- `artifacts/yiacad_backend_proof/<timestamp>/summary.json`
- `artifacts/yiacad_backend_proof/<timestamp>/summary.md`
- alias:
  - `artifacts/yiacad_backend_proof/latest.json`
  - `artifacts/yiacad_backend_proof/latest.md`

## Lecture opérateur

- `status=done` signifie que la preuve de transport et de contrat est bonne
- un payload métier peut rester `blocked` dans la preuve si l’entrée est volontairement invalide; cela ne casse pas la preuve tant que:
  - le transport fonctionne,
  - le contrat est respecté,
  - les artefacts sont produits

## Décision

- cette preuve ne ferme pas `yiacad-fusion`
- le blocage `kicad-host-entrypoint` reste distinct et externe à `Kill_LIFE`
- cette preuve, combinée au reroutage `service-first` de `yiacad_uiux_tui.sh`, ferme `T-ARCH-101C` pour les surfaces actives
- les suites de travail restent suivies séparément dans:
  - `T-UX-003` pour les surfaces compilées plus profondes
  - `T-UX-004` pour la persistance complète `review center / inspector`
  - `T-RE-209` pour le lot opérateur YiACAD complet

## Delta 2026-03-21 - T-UX-006F

- la preuve backend n'utilise plus des chemins `/tmp/nonexistent*` jetables
- elle s'appuie maintenant sur des fixtures stables du repo:
  - `tools/cad/proof_fixtures/yiacad_backend_proof/probe_board.kicad_pcb`
  - `tools/cad/proof_fixtures/yiacad_backend_proof/probe_model.FCStd`
- le statut metier reste volontairement `blocked` sur `review.bom`, mais le contexte operateur devient stable et traçable
