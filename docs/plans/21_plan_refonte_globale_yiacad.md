# Plan 21 - refonte globale YiACAD (2026-03-20)

## Intention

Construire la couche de pilotage globale qui assemble audit, IA, docs, plans, TODOs, TUI et lot suivant autour de YiACAD.

## Lanes et responsables

| Lane | Owner | Sous-agent / role | Competences | Write-set principal |
| --- | --- | --- | --- | --- |
| Audit-Core | Architect / Doc | Audit-Core | analyse repo, synthese, cartes | `docs/YIACAD_GLOBAL_*`, `specs/yiacad_global_refonte_spec.md` |
| AI-Integration | Architect / CAD | AI-Integration | MCP, CAD IA-native, orchestration | `docs/YIACAD_GLOBAL_AI_*`, `docs/YIACAD_GLOBAL_OSS_*` |
| DesignOps-UI | CAD / DesignOps | UI-Orchestrator | palette, inspector, review center | forks CAD + `docs/plans/20_*` |
| CAD-Native | CAD | KiCad-Native, FreeCAD-Native | shells natifs, backend path, context propagation | `.runtime-home/cad-ai-native-forks/*`, `tools/cad/*` |
| Ops-TUI | PM / Doc | TUI-Operator | bash TUI, logs, purge, status | `tools/cockpit/yiacad_refonte_tui.sh`, `artifacts/yiacad_refonte_tui/*` |
| Docs-Continuity | Doc | Docs-Continuity | README, runbook, index, coherence | `README.md`, `docs/index.md`, `docs/RUNBOOK.md` |

## Sequence recommandee

1. Audit global et recherche OSS
2. Spec et feature map globales
3. Plan / TODO / owners / write-sets
4. TUI globale et logs
5. Passage vers `T-UX-004`

## Risques a contenir

- dispersion documentaire
- coexistence de plusieurs TUI proches
- backend YiACAD encore trop leger
- confusion entre lane UI/UX et refonte globale

## Critere de sortie

- tout nouvel arrivant sait ou lire l'audit, la spec, le plan, le TODO, la recherche et la commande TUI d'entree
- le prochain lot est formule explicitement et sans ambiguite

## Etat canonique 2026-03-20

- bundle global publie: audit, IA, cartes, OSS, spec, plan, TODO, TUI
- lot suivant produit: `T-UX-004`
- lot suivant architecture: `T-ARCH-101C`
- lot ops ferme: `T-OPS-118`
- palier architecture livre:
  - backend local `yiacad_backend.py`
  - `context broker` schema + example
  - `uiux_output.json` et `context.json` prepares pour les surfaces produit
- objectif de ce plan:
  - eviter les deltas contradictoires
  - garder une entree lisible entre refonte globale et refonte UI/UX

## Delta 2026-03-21 - T-OPS-118 operator index

- `T-OPS-118` pose une entree operateur stable: `tools/cockpit/yiacad_operator_index.sh`.
- Cette surface ne remplace pas les TUI existantes; elle route explicitement vers `yiacad_uiux_tui.sh` et `yiacad_refonte_tui.sh`.
- La commande d’entree et la doc associee deviennent auditables via `docs/YIACAD_OPERATOR_INDEX_2026-03-21.md`.

## Delta 2026-03-21 - T-ARCH-101 closure

- `T-ARCH-101` est ferme au niveau parent.
- La couche locale YiACAD est maintenant formalisee autour de:
  - `tools/cad/yiacad_backend.py`
  - `tools/cad/yiacad_native_ops.py`
  - `tools/cad/yiacad_backend_service.py`
- Le front architecture encore actif devient `T-ARCH-101C`: reroutage progressif des shells natifs vers la facade backend locale.

## Delta 2026-03-21 - operator entrypoint
- l'entree operateur stable est maintenant `tools/cockpit/yiacad_operator_index.sh`.
- ce point d'entree route explicitement vers la lane UI/UX (`20`) et la lane globale (`21`).

## Delta 2026-03-21 - T-UX-005
- le lot produit suivant execute apres `T-UX-004A` est maintenant livre: review center enrichi sur KiCad et FreeCAD.
- l'enchainement naturel devient `T-UX-006` puis `T-ARCH-101C`.

## Delta 2026-03-21 - T-ARCH-101C tranche KiCad

- premiere tranche de reroutage shell executee sans ouvrir de hotspot compile:
  - le plugin KiCad YiACAD passe maintenant par la facade locale `tools/cad/yiacad_backend_service.py`
  - le fallback direct `yiacad_native_ops.py` reste en place si la facade n'est pas presente
- cette tranche ferme le plus petit write-set utile cote KiCad:
  - `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin/_native_common.py`
- la convergence FreeCAD vers la meme facade reste ouverte dans `T-ARCH-101C`.

## Delta 2026-03-21 - T-ARCH-101C tranche FreeCAD

- deuxieme tranche de reroutage shell executee sur le plus petit helper Python utile:
  - `yiacad_freecad_gui.py` privilegie maintenant `tools/cad/yiacad_backend_service.py`
  - les call sites UI FreeCAD restent inchanges; seul le transport vers le backend a ete reroute
- le fallback direct `yiacad_native_ops.py` reste disponible si la facade locale est absente.

## Delta 2026-03-21 - T-ARCH-101C preuve operateur unifiee

- un runbook canonique de preuve operateur est maintenant publie:
  - `tools/cockpit/yiacad_backend_proof.sh`
  - `docs/YIACAD_BACKEND_OPERATOR_PROOF_2026-03-21.md`
- cette preuve verifie:
  - statut de la facade locale,
  - transport shell KiCad vers la facade,
  - transport workbench FreeCAD vers la facade,
  - presence du contrat `uiux_output` sur les actions de preuve.
- `yiacad_uiux_tui.sh --action status` passe maintenant lui aussi par le client `service-first`.
- `T-ARCH-101C` est ferme pour les surfaces actives; les suites de travail sont reparties entre `T-UX-003`, `T-UX-004` et `T-RE-209`.

## Delta 2026-03-21 - T-UX-006
- la persistance de session de base est maintenant en place sur les deux surfaces deja YiACAD.
- l'enchainement naturel devient `T-ARCH-101C`, puis une session de revue plus riche cote produit.

## Delta 2026-03-21 - backend service
- `T-ARCH-101C` est maintenant livre sur les surfaces actives Python via un backend local et un client `service-first`.
- une surface operatoire dediee existe maintenant: `tools/cockpit/yiacad_backend_service_tui.sh`.

## Delta 2026-03-21 - T-UX-006D raccord global

- la couche produit YiACAD ajoute maintenant une vue de contexte de revue consolidée au-dessus de la session persistée et de l’historique.
- ce palier ferme un besoin opératoire utile sans ouvrir les surfaces compilées plus risquées.

## 2026-03-21 - Lot update
- `T-ARCH-101C` est maintenant ferme: les surfaces actives KiCad / FreeCAD et la TUI UI/UX passent en `service-first` via `tools/cad/yiacad_backend_client.py`, avec auto-start du service local et fallback direct vers `tools/cad/yiacad_native_ops.py`.
- `T-OPS-119` consolide: `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur stable avec `status`, `uiux`, `global`, `backend`, `proofs` et des alias de compatibilite conserves.
- Validation executee: `bash tools/cockpit/yiacad_backend_proof.sh --action run --json` retourne `status=done`.
- Risque residuel: l'extension aux call sites compiles restants et la persistance produit restent traitees par `T-UX-003`, `T-UX-004` et `T-RE-209`.

## 2026-03-21 - Proofs lane
- Nouveau point d'entree: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Objectif: centraliser `backend`, `review-session`, `review-history`, `review-taxonomy` et l'hygiene des logs dans une surface canonique sans casser les alias historiques.
- Documentation: `docs/YIACAD_PROOFS_TUI_2026-03-21.md`.
