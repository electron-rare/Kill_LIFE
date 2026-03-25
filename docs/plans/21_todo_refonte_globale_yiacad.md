# TODO 21 - refonte globale YiACAD (2026-03-20)

## P0

- [x] Produire un audit global priorise du repo
- [x] Produire une evaluation des integrations IA prioritaires
- [x] Produire une feature map Mermaid globale
- [x] Produire une recherche OSS globale YiACAD
- [x] Produire une spec globale YiACAD
- [x] Ajouter une TUI globale YiACAD avec logs
- [x] Raccorder le README a ce bundle global

## P1

- [x] Formaliser le backend YiACAD cible derriere `yiacad_native_ops.py`
- [x] Publier l'architecture backend locale, le `context broker` et les contrats associes
- [x] Introduire le module `tools/cad/yiacad_backend.py` et les artefacts `context.json` / `uiux_output.json`
- [x] Ouvrir et distribuer `T-UX-004`
- [x] Executer `T-UX-004` sur KiCad/FreeCAD (`palette`, `review center`, `inspector`)
  - Note 2026-03-25: T-UX-004A livre (palette legere + review center leger sur KiCad plugin et FreeCAD workbench, cf. Delta 2026-03-21)
- [x] Rationaliser les TUI proches autour d'un index operateur stable
- [x] Resumer les zones `ai-agentic-embedded-base`, `zeroclaw`, `openclaw` dans une vue canonique unique
  - Note 2026-03-25: fait dans docs/CANONICAL_SUBSYSTEM_VIEW.md

## P2

- [x] Ajouter un tableau de maturite par lane
  - Note 2026-03-25: fait dans docs/CANONICAL_SUBSYSTEM_VIEW.md
- [x] Ajouter des KPI de densite documentaire et de fragmentation
  - Note 2026-03-25: fait dans docs/CANONICAL_SUBSYSTEM_VIEW.md
- [x] Faire converger logs, handoffs et resumés hebdomadaires dans une seule entree cockpit
  - Note 2026-03-25: fait via tools/cockpit/unified_ops_entry.sh

## Consolidation canonique 2026-03-20

- `T-UX-004` n'est plus un point d'ouverture; c'est maintenant un lot d'execution.
- le point d'ouverture architecture restant est le backend YiACAD cible derriere `yiacad_native_ops.py`.
- le front architecture encore ouvert correspond maintenant au passage de backend local partage vers service/backend plus stable (`T-ARCH-101C`).
- le point d'entree operateur canonique est maintenant `bash tools/cockpit/yiacad_operator_index.sh --action status`.

## Delta 2026-03-21

- `T-OPS-118` ferme:
  - `tools/cockpit/yiacad_operator_index.sh`
  - `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`
  - `yiacad_refonte_tui.sh` et `yiacad_uiux_tui.sh` pointent maintenant vers cet index
- `T-ARCH-101` ferme:
  - `tools/cad/yiacad_backend.py`
  - `tools/cad/yiacad_native_ops.py`
  - `tools/cad/yiacad_backend_service.py`
  - `docs/YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md`
  - `specs/yiacad_backend_architecture_spec.md`

## Delta 2026-03-21 - progression lots YiACAD
- `T-UX-004A` avance avec palette legere + review center leger livres sur KiCad plugin et FreeCAD workbench.
- `T-ARCH-101C` est ferme sur les surfaces actives.
- `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur stable.

## Delta 2026-03-21 - progression review center
- `T-UX-005` est livre.
- le prochain lot produit ouvert est `T-UX-006`.

## Delta 2026-03-21 - progression T-ARCH-101C

- [x] rerouter la jonction shell KiCad vers `yiacad_backend_service.py` via `_native_common.py`
- [x] rerouter le helper principal FreeCAD vers la meme facade backend locale
- [x] rerouter `yiacad_uiux_tui.sh --action status` sur le meme client `service-first`
- [ ] rerouter les surfaces FreeCAD compilees restantes seulement si un write-set plus large devient necessaire
  - Note 2026-03-25: blocked: requires C++ fork compilation
- [x] publier une preuve operateur unifiee `KiCad + FreeCAD -> facade backend -> uiux output`

## Delta 2026-03-21 - progression inspector
- `T-UX-006` est livre sur les surfaces deja YiACAD.
- le front prioritaire restant remonte vers `T-ARCH-101C`.

## Delta 2026-03-21 - backend service progression
- `T-ARCH-101C` est livre sur les surfaces actives Python.
- le prochain arbitrage porte maintenant sur `T-UX-003`, `T-UX-004` et `T-RE-209`.

## Delta 2026-03-21 - T-UX-006D
- [x] Ajouter une vue de contexte de revue opérable au-dessus de la session persistée
- [x] Raccorder cette vue dans l’index opérateur global

## 2026-03-21 - Lot update
- `T-ARCH-101C` est maintenant ferme: les surfaces actives KiCad / FreeCAD et la TUI UI/UX passent en `service-first` via `tools/cad/yiacad_backend_client.py`, avec auto-start du service local et fallback direct vers `tools/cad/yiacad_native_ops.py`.
- `T-OPS-119` consolide: `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur stable avec `status`, `uiux`, `global`, `backend`, `proofs` et des alias de compatibilite conserves.
- Validation executee: `bash tools/cockpit/yiacad_backend_proof.sh --action run --json` retourne `status=done`.
- Risque residuel: l'extension aux call sites compiles restants doit etre traitee dans `T-UX-003`, et la persistance produit dans `T-UX-004`.

## 2026-03-21 - Proofs lane
- Nouveau point d'entree: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Objectif: centraliser `backend`, `review-session`, `review-history`, `review-taxonomy` et l'hygiene des logs dans une surface canonique sans casser les alias historiques.
- Documentation: `docs/YIACAD_PROOFS_TUI_2026-03-21.md`.
