# YiACAD Operator Index - 2026-03-21

## Objectif

Fournir un point d’entrée opérateur unique pour ne plus demander à l’utilisateur de choisir implicitement entre la lane UI/UX (`20`), la refonte globale (`21`) et le backend service YiACAD.

## Entrée canonique

- commande: `bash tools/cockpit/yiacad_operator_index.sh --action status`

## Routage

| Besoin | Commande | Lane |
| --- | --- | --- |
| Vue opérateur courte | `bash tools/cockpit/yiacad_operator_index.sh --action status` | index |
| État UI/UX produit | `bash tools/cockpit/yiacad_operator_index.sh --action uiux` | `20` |
| État refonte globale | `bash tools/cockpit/yiacad_operator_index.sh --action global` | `21` |
| Backend service | `bash tools/cockpit/yiacad_operator_index.sh --action backend` | index |
| Contexte de revue compact | `bash tools/cockpit/yiacad_operator_index.sh --action review-context` | index |
| Preuves et docs | `bash tools/cockpit/yiacad_operator_index.sh --action proofs` | index |
| Logs de l’index | `bash tools/cockpit/yiacad_operator_index.sh --action logs-summary --json` | index |

## Décision

- `yiacad_uiux_tui.sh` reste la surface produit et shell/native.
- `yiacad_refonte_tui.sh` reste la surface audit/global/backend.
- `yiacad_backend_service_tui.sh` devient la vue canonique du backend service YiACAD.
- `yiacad_operator_index.sh` devient l’entrée opérateur stable.

## Lots raccordés

- produit: `T-UX-004`
- architecture: `T-ARCH-101C`
- ops: `T-OPS-118`
- session persistante: `T-UX-006`
- contexte compact: `T-UX-006D`

## Preuves

- `tools/cockpit/yiacad_operator_index.sh`
- `tools/cockpit/yiacad_uiux_tui.sh`
- `tools/cockpit/yiacad_refonte_tui.sh`
- `tools/cockpit/yiacad_backend_service_tui.sh`
- `docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md`
- `docs/plans/21_plan_refonte_globale_yiacad.md`

## Delta 2026-03-21 - review context

- nouvelle route opérateur:
  - `bash tools/cockpit/yiacad_operator_index.sh --action review-context`
- cette vue condense:
  - session courante
  - taxonomie
  - trail récent
  - prochaines étapes
