# TODO Mesh Tri-Repo 2026-03-20

## État de bord (2026-03-20 15:33)

- `mesh_status`: `degraded`
- Cause principale observée:
  - Le preflight remonte en `degraded` pour `cils` sur les dépôts non-critiques (policy `cils-lockdown`) et pour `README.md` en `degraded`.
  - `mesh_host_order` est conforme au profil `tower-first` : `clems@192.168.0.120 -> kxkm@kxkm-ai -> cils@100.126.225.111 -> local -> root@192.168.0.119`.
  - La prochaine cause bloquante restante est la dérive de conformité docs/repo (specs/workflows count, via `readme_repo_coherence`).
- Source de preuve: `artifacts/cockpit/machine_alignment_daily_20260320_152957.json` + `artifacts/cockpit/health_reports/mesh_health_check_mesh_20260320_153202.json`.
- Priorité principale:
  - stabiliser la conformité docs/repo (cohérence `specs/` et workflows) pour faire remonter le niveau `readme_status` à `ready`.
  - maintenir la politique `cils-lockdown` (service non-essentiel uniquement).
  - poursuivre `mesh_governance` dès résolution de la dérive `readme`.
- Source de vérité: `docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md` + `docs/REFACTOR_MANIFEST_2026-03-20.md`.

## P0

- [x] Formaliser le contrat mesh tri-repo versionne.
- [x] Ajouter un preflight TUI de convergence multi-machines/multi-repos.
- [x] Formaliser les statuts `ready | degraded | blocked` pour les surfaces MCP.
- [x] Mettre a jour la gouvernance agents/sous-agents pour un mode multi-contributeurs.
- [x] Propager le contrat mesh dans `mascarade` (`T-MESH-005`).
  - Lot attendu: `T-MESH-005`
  - Propriétaire: `PM-Mesh` + `Arch-Mesh`
- [x] Propager le handshake workflow dans `crazy_life` (`T-MESH-006`).
  - Lot attendu: `T-MESH-006`
  - Propriétaire: `PM-Mesh` + `Runtime`
- [x] Valider la lane opérateur `dry-run` et `live` sur `clems`.
  - Lot attendu: `T-OL-001`
  - Propriétaire: `Runtime-Companion` + `SyncOps`
- [x] Uniformiser les artefacts lot-tracking (`specs/03_plan.md` + `specs/04_tasks.md`) avec ce contrat.
  - Lot attendu: `T-MESH-007`
  - Commandes canoniques:
    - `bash tools/run_autonomous_next_lots.sh status`
    - `bash tools/cockpit/lot_chain.sh plan --yes`
  - Dépendance: `T-RE-302`
- [x] Propager le patchset `post-E2E hardening` sur les lanes mesh et rétablir la visibilité preflight sur `clems`.
  - Lot attendu: `T-OL-002`
  - Propriétaire: `SyncOps`

## P1

- [x] Ajouter une TUI d'analyse/purge de logs avec sortie JSON.
- [x] Rafraichir la veille OSS officielle et la relier a la gouvernance mesh.
- [x] Faire consommer le contrat de handoff par tous les lots `autonomous_next_lots` validés en mode `autonomous next lots`.
- [x] Ajouter une validation CI du workflow schema handshake (`T-CI-001`).
  - Lot attendu: `T-CI-001`
- [x] Uniformiser les handoff de lot (`lot_id`, `owner_repo`, `owner_agent`, `write_set`) dans les logs d’exécution.
  - Lot attendu: `T-LC-007`
  - Réalisé par la génération JSON de `tools/autonomous_next_lots.py` (`lot_id`, `owner_repo`, `owner_agent`, `write_set`).
- [x] Ajouter le load balancing P2P dynamique du preflight mesh, avec cils verrouillé (`Kill_LIFE` prioritaire) et arbitrage par load_ratio.
  - Lot attendu: `T-LB-001`
  - Réalisé par: `tools/cockpit/mesh_sync_preflight.sh --load-profile`
- [x] Formaliser la stratégie de garde CILS dans le contrat opérationnel (load profile + photo-safe + non-essentiel).
  - Lot attendu: `T-LB-005`
  - Réalisé par: `docs/MACHINE_ALIGNMENT_CONTRACT_2026-03-20.md`, `tools/cockpit/ssh_healthcheck.sh`, `docs/plans/12_plan_gestion_des_agents.md`
- [x] Durcir le parsing du payload distant pour éviter les sorties SSH non-conformes et garantir un JSON stable.
  - Lot attendu: `T-LB-002`
  - Réalisé par: `tools/cockpit/mesh_sync_preflight.sh` (`snapshot_repo_remote`)
- [x] Ajouter une passe de rapprochement des métriques d’exécution `ready/degraded/blocked` entre `mesh_sync_preflight`, `readme_repo_coherence`, `log_ops`.
  - Lot attendu: `T-RE-208`
  - Réalisé par: `tools/cockpit/mesh_health_check.sh`
- [x] Documenter le contrat runtime provider réellement observé sur la lane opérateur.
  - Lot attendu: `T-OL-003`
  - Réalisé par: `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`
- [x] Exposer l’ordre de scheduling P2P dans la sortie JSON du preflight (`host_order`) pour rendre la décision Tower-first/photon-safe transparente.
  - Lot attendu: `T-LB-004`
  - Réalisé par: `tools/cockpit/mesh_sync_preflight.sh`
- [x] Ajouter un outil TUI dédié à la propagation du patchset opérateur.
  - Lot attendu: `T-OL-004`
  - Réalisé par: `tools/cockpit/full_operator_lane_sync.sh`
- [x] Bloquer strictement tout précheck CILS en mode `photon-safe` (hors SSH) pour éviter toute surcharge de `photon`.
  - Lot attendu: `T-LB-003`
  - Réalisé par: `tools/cockpit/mesh_sync_preflight.sh` (règle `photon-safe`)

## P2

- [x] Weekly summary automatique par agent principal.
  - Lot attendu: `T-RE-301`
  - Réalisé par: `tools/cockpit/render_weekly_refonte_summary.sh`
- [x] Evidence packs consolides multi-repos.
  - Lot attendu: `T-EP-001`
  - Réalisé par: `tools/cockpit/evidence_pack_builder.sh`
- [x] Assistant operator pour pilotage de lots controles.
  - Lot attendu: `T-LP-001`
  - Réalisé par: `tools/cockpit/lot_pilot_assistant.sh`
- [x] Checklist de sortie lot avec preuves log + mesh + preflight.
  - Lot attendu: `T-RE-304`
  - Réalisé par: `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md` + `artifacts/cockpit/weekly_refonte_summary.md`
- [x] Outil de suivi "runbook mesh" pour lancer `mesh + lots + logs` dans un ordre canonique.
  - Lot attendu: `T-MESH-010`

- [x] Reporter la matrice d'owners dans les TODOs companions sans toucher aux hotspots `single-writer`.
  - Lot attendu: `T-AG-102`
  - Réalisé par:
    - `mascarade-main/docs/TODO_MESH_TRI_REPO_2026-03-20.md`
    - `crazy_life-main/docs/TODO_MESH_TRI_REPO_2026-03-20.md`

## Agents dédiés à la passe Mesh (2026-03-20)

- `PM-Mesh` (PM-Plan, Risk-Triager): priorisation + résolution `mascarade` branch/clone.
- `Arch-Mesh` (Schema-Guard, Compat-Auditor): revue handshake + compatibilité schema.
- `QA-Compliance` (Spec-Mirror, Evidence-Pack): contrôle evidence + CI contracts.
- `SyncOps` (SSH-Health, Log-Ops): health-check, purge logs, relance contrôlée.

## Matrice de compétences et tâches

| Agent | Compétences | Tâches ouvertes |
| --- | --- | --- |
| PM-Mesh | triage lot, coordination multi-repo, priorisation | `T-MESH-005`, `T-MESH-006`, réconciliation topologie |
| Arch-Mesh | validation schema, compatibilité contractuelle | CI schema handshake, preuve de migration |
| Embedded-CAD | CAD/MCP, fork AI-native | branche `kill-life-ai-native`, préflight host-first |
| Runtime-Companion | providers, logs, providers health | statut MCP runtime + smoke |
| QA-Compliance | tests, trace, evidence packs | validation tickets lot + état `blocked/degraded/ready` |
| Docs-Research | doc delta, Mermaid, veille officielle | `T-OL-003`, README/index/full-operator delta |

## Sous-tâches lot-level ouvertes

- `zeroclaw-integrations` : propriétaire `PM-Mesh`, sous-agent `Runtime-Smoke`, preuve attendue `T-RE-204`.
- `mesh-governance` : propriétaire `Arch-Mesh`, sous-agent `Schema-Guard`, focus `T-MESH-007`.
- `post-e2e-hardening` : propriétaire `Runtime-Companion`, sous-agents `Compat-Guard` + `SyncOps`, focus `T-OL-002`, `T-OL-003`, `T-OL-004`.
- `yiacad-fusion` : propriétaire `Arch-Mesh`, sous-agents `CAD-Bridge` + `CAD-Smoke`, focus `T-RE-209` et `T-RE-210`.
- `weekly-summary` : propriétaire `SyncOps`, sous-agent `Doc-Runbook`, focus `T-RE-301`.

## Actions de convergence ouvertes après preflight

- [x] Restaurer le snapshot exploitable de `mascarade-main` sur `clems@192.168.0.120`.
- [ ] Relancer `mesh_sync_preflight --load-profile tower-first --json` sur la fenêtre `clems` et confirmer `mesh_status=ready`.
- [x] Restaurer le snapshot exploitable de `mascarade-main` sur `clems@192.168.0.120`.
- [x] Vérifier `load_profile: tower-first` dans `host_order` (`clems -> kxkm -> cils -> local -> root`) après correction parser.
- [x] Propager le patchset `post-E2E hardening` via `bash tools/cockpit/full_operator_lane_sync.sh --json`.
- [ ] Lancer `mesh_health_check --load-profile tower-first --json` et consigner `mesh_host_order` dans le lot-log.
- [x] Purger les `._*` apparus sur les lanes companions lorsque la passe de sync sera stabilisée.
- [ ] Harmoniser les lots ouverts (12/18/19 + specs/03/04) via `bash tools/cockpit/lot_chain.sh plan --yes`.
- [x] Relancer `mesh_sync_preflight --load-profile tower-first` pour valider le parsing robuste.

## Delta 2026-03-20 15:45 - owner matrix + dirty-set cleanup

- [x] `T-AG-102` execute: overlay d'owners reporte dans les TODOs companions `mascarade-main` et `crazy_life-main`.
- [x] Dirty-sets mesh inter-machines realignes:
  - `Kill_LIFE-main = 27`
  - `mascarade-main = 6`
  - `crazy_life-main = 6`
  - aligne sur `local`, `clems`, `kxkm`, `root`, `cils`
- [x] Purge des artefacts Apple `._*` et `.DS_Store` effectuee sur les lanes mesh.
- [ ] `mesh_status=ready` reste bloque par la policy `cils-lockdown` et par la convergence des checks de conformite docs/repo, non par un ecart Git reel.

## Delta 2026-03-20 15:55 - regeneration trackers 18*

- [x] `bash tools/run_autonomous_next_lots.sh status` relance pour regenérer les trackers `18_plan` et `18_todo`.
- [x] Le lot suivant est formalise en `T-MESH-007`.
- [x] La commande canonique de synchronisation des plans/todos devient `bash tools/cockpit/lot_chain.sh plan --yes`.
- [x] `bash tools/cockpit/lot_chain.sh plan --yes` execute pour resynchroniser les blocs auto `specs/03_plan.md` et `specs/04_tasks.md`.

## Delta 2026-03-20 14:15 - alignement runbook + tolérance dégradée

- [x] Mise à jour des plans 18* pour intégrer la boucle lot -> incident register -> status sync.
- [x] Hardening préflight mesh: sortie SSH invalide now mapped to state `degraded/unreachable`, sans crash.
- [x] Charge policy et ordonnancement `tower-first/photon-safe` stabilisés pour la passe quotidienne.

## Resolus le 2026-03-20

- [x] Fournir un clone mesh `mascarade-main` exploitable sur `kxkm@kxkm-ai` sans ecraser `/home/kxkm/mascarade`.
- [x] Fournir un clone mesh `mascarade-main` sur `root@192.168.0.119` sans toucher la lane `feat/apple-coreml-runtime-lot` de `/root/mascarade-github`.
- [x] Aligner les miroirs mesh `mascarade-main` sur le SHA `d8bca38d384e47ca17e336b49a11164c579ad3c6`.

## Resolus le 2026-03-20 apres normalisation Kill_LIFE

- [x] Fournir un clone mesh `Kill_LIFE-main` sur local, `clems`, `root` et `kxkm-ai`.
- [x] Aligner les miroirs mesh `Kill_LIFE-main` sur le SHA `bd3f7b99154f86057ba18b9948d940df55722b12`.
- [x] Faire remonter `mesh_status=ready` sur le preflight tri-repo.

## Resolus le 2026-03-20 apres propagation compagnons

- [x] Localiser le contrat mesh runtime dans `mascarade`.
- [x] Localiser le contrat mesh web dans `crazy_life`.
- [x] Reserver des lanes `crazy_life-main` dediees pour la sync controlee.

## Resolus le 2026-03-20 apres propagation machine companion

- [x] Propager le contrat mesh runtime dans `mascarade-main` sur local, `clems`, `root`, `kxkm-ai`.
- [x] Propager le contrat mesh web dans `crazy_life-main` sur local, `clems`, `root`, `kxkm-ai`.
- [x] Etendre le preflight tri-repo aux lanes `crazy_life-main`.
- [x] Faire remonter `mesh_status=ready` apres propagation des trois repos sur les miroirs dedies.

## Resolus le 2026-03-20 apres ajout de `cils`

- [x] Integrer `cils@100.126.225.111` comme cible SSH operateur supplementaire.
- [x] Sauvegarder la lane partielle `Kill_LIFE-main` issue du premier clone rate sans l'ecraser.
- [x] Fournir des miroirs mesh `Kill_LIFE-main`, `mascarade-main`, `crazy_life-main` sur `/Users/cils`.
- [x] Etendre le health-check SSH a `cils`.
- [x] Corriger le preflight tri-repo pour shells distants `zsh` en forcant le snapshot via `bash -s`.
- [x] Faire remonter `mesh_status=ready` sur `clems`, `root`, `kxkm-ai` et `cils`.

## Resolus le 2026-03-20 apres propagation companion + lot schemas

- [x] Ajouter un preflight mesh local a `mascarade-main`.
- [x] Ajouter un preflight mesh local a `crazy_life-main`.
- [x] Etendre les contrats compagnons et leurs README a `cils@100.126.225.111`.
- [x] Publier les schemas machine-readables `agent_handoff`, `repo_snapshot`, `workflow_handshake`.
- [x] Ajouter un checker local sans dependance externe pour les contrats mesh.

## Resolus le 2026-03-20 apres branchement du checker

- [x] Faire consommer `mesh_contract_check.py` par `tools/autonomous_next_lots.py`.
- [x] Faire consommer les schemas mesh par les preflights compagnons `mascarade-main` et `crazy_life-main`.
- [x] Ajouter un workflow CI visible pour les exemples `agent_handoff`, `repo_snapshot`, `workflow_handshake`.
- [x] Executer explicitement le lot `mesh-governance` avec succes sur les 5 validations requises.

## Delta 2026-03-20 14:00 - full operator lane

- [x] Added the `embedded-operator-live` workflow as the stable operator E2E source of truth.
- [x] Added the live-provider evidence contract and example payload.
- [x] Added the TUI runbook `tools/cockpit/full_operator_lane.sh`.
- [x] Added the `operator.live-provider` action in `crazy_life`.
- [x] Aligned companion docs on the live-provider bridge.

## Delta 2026-03-20 14:45 - post-E2E hardening

- [x] Dry-run validated on `clems` with `run_id=4a9adf87-1695-4321-86a2-e066a0988533`.
- [x] Live validated on `clems` with `run_id=5ef4909f-8747-4634-a6a6-d131692787b0`.
- [x] The live bridge is now container-safe through `operator_live_provider_smoke.js`.
- [x] The runtime payload now uses a top-level `system` field instead of a `system` message role.
- [x] Official compatibility note captured in `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`.
- [x] Mesh preflight still needs a conservative recovery pass on `clems` before the lane can return to `ready`.

## Delta 2026-03-20 14:58 - staged sync + preflight

- [x] `bash tools/cockpit/full_operator_lane_sync.sh --json` executed successfully in `staged` mode on the 4 mesh targets.
- [x] `mesh_sync_preflight --json` moved from `blocked` back to `degraded`.
- [x] `Kill_LIFE-main` and `crazy_life-main` are visible again on `clems`.
- [x] `mascarade-main` on `clems` still needs a conservative repair pass before the mesh can return to `ready`.

## Delta 2026-03-20 16:21 - registre machine branche + YiACAD clarifie

- [x] `T-RE-214` cloture:
  - `ssh_healthcheck.sh` charge maintenant les cibles SSH depuis `specs/contracts/machine_registry.mesh.json`
  - `run_alignment_daily.sh` embarque maintenant un resume JSON du registre dans ses artefacts
  - preuves:
    - `bash tools/cockpit/ssh_healthcheck.sh --json`
    - `bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh --skip-log-ops --no-purge`
- [x] Le lot mesh consomme desormais une source unique de roles/ports/priorites sur ses runbooks centraux.
- [ ] `yiacad-fusion` reste bloque, mais la cause est maintenant explicite et stable:
  - `mascarade-main/finetune/kicad_mcp_server` est present comme sous-module non materialise
  - l'entrypoint attendu `dist/index.js` manque, donc `KiCad MCP host smoke` reste `blocked`
  - le mode `auto` retombe maintenant proprement vers `container`
- [ ] Prochaine action mesh utile:
  - rerun `mesh_health_check --json --load-profile tower-first` avec le resume registre embarque
  - reporter l'etat degrade courant sans confondre `yiacad-fusion` bloque et `mesh` documentaire/runbook

## Delta 2026-03-20 16:54 - T-OL-002 restaure sur clems

- [x] `bash tools/cockpit/full_operator_lane_sync.sh --json` relance en mode `staged`: `status=done`, `targets=4`
- [x] `mesh_sync_preflight --json --load-profile tower-first` rerun apres hardening parser:
  - `clems/mascarade-main`: `ready`
  - `clems/crazy_life-main`: `ready`
- [x] `T-OL-002` peut etre considere comme ferme cote visibilite preflight sur `clems`
- [ ] `mesh_status` reste `degraded`, mais pour des motifs distincts du lot operateur:
  - `cils-lockdown` non critique sur `mascarade` et `crazy_life`
  - dirty counts encore divergents entre certaines lanes
  - probe de charge `clems` encore marque `degraded:invalid-load-output`

- 2026-03-20 17:05 +0100 - T-RE-401 done: job GitHub visible ajoute via `.github/workflows/docs_reference_gate.yml`; audit local `bash tools/doc/readme_repo_coherence.sh audit` vert.
