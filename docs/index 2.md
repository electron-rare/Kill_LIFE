# Kill_LIFE — Documentation opérateur

## Démarrage

- Installation : `docs/INSTALL.md`
- Runbook opérateur : `docs/RUNBOOK.md`
- FAQ : `docs/FAQ.md`
- Runtime home : `docs/RUNTIME_HOME.md`
- Pont compagnon : `docs/MASCARADE_BRIDGE.md`
- Architecture de référence : `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md`
- Référence des séquences : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`, `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`
- Manifeste refonte : `docs/REFACTOR_MANIFEST_2026-03-20.md`
- Web research OSS : `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md`
- Stratégie CAD IA-native : `docs/CAD_AI_NATIVE_FORK_STRATEGY.md`
- Lot YiACAD : `tools/cad/yiacad_fusion_lot.sh`
- Surfaces GUI YiACAD : `docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`
- Hooks natifs YiACAD : `docs/CAD_AI_NATIVE_HOOKS_2026-03-20.md`
- Audit UI/UX Apple-native : `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`
- Points d’insertion natifs : `docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md`
- Index operateur YiACAD : `bash tools/cockpit/yiacad_operator_index.sh --action status`
- TUI UI/UX : `tools/cockpit/yiacad_uiux_tui.sh`

## Workflows opérationnels

- `docs/workflows/README.md`
- Templates d’issues : `.github/ISSUE_TEMPLATE/`
- Dispatch GitHub : `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`
- Validation locale : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`

## Plans

- `docs/plans/README.md`
- `docs/plans/12_plan_gestion_des_agents.md`
- `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`
- `docs/plans/REPO_DEEP_ANALYSIS_2026-03-11.md`
- `docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md`
- `docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md`
- `docs/plans/20_todo_refonte_ui_ux_yiacad_apple_native.md`

## Gestion agents / IA

- Gestion des agents : `docs/plans/12_plan_gestion_des_agents.md`
- Orchestration IA : `docs/AI_WORKFLOWS.md`
- Paysage agentique : `docs/AGENTIC_LANDSCAPE.md`
- Matrice agentique spec/module : `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`

## Evidence et rituels

- Evidence pack : `docs/evidence/evidence_pack.md`
- Rituels : `docs/rituals/`
- Handoffs : `docs/handoffs/`
- Templates : `docs/templates/`

## Références mémoire

- [Synthèse globale](../SYNTHESE_AGENTIQUE.md)
- [Rapport détaillé](assets/rapport/rapport_agentique.md)
- [Diagramme agentique](assets/rapport/diagramme_agentique.md)
- [Correspondance agents/systèmes](assets/rapport/synthese_correspondance_agents_systemes.md)

## Tests et preuve

- [Tests firmware](../firmware/test/)
- [Validation compliance](../compliance/evidence/)
- [Tests MCP](../test/)

## Infrastructure humaine & accès

- Machines SSH opérateur et rôles:

| Machine | Utilisateur | Priorité | Rôle | Port SSH | Port(s) service cible |
|---|---|---:|---|---:|---|
| `clems@192.168.0.120` | `clems` | `1` | Machine de pilotage / orchestration locale | `22` | `22` |
| `kxkm@kxkm-ai` | `kxkm` | `2` | Mac opérateur | `22` | `22` |
| `cils@100.126.225.111` | `cils` | `3` | Mac opérateur secondaire (`photon`, locké: seulement `Kill_LIFE`) | `22` | `22` |
| `root@192.168.0.119` | `root` | `4` | Serveur système / exécution matérielle | `22` | `22` |

- Politique de charge P2P: `Tower -> KXKM -> CILS -> local -> root`.
- `CILS` n’accueille pas de services essentiels ; uniquement le snapshot critique `Kill_LIFE` est autorisé.
- `root` reste la réserve opérationnelle quand `tower`, `kxkm`, `cils`, et le local sont saturés.

### Politique de load balancing (P2P)

```mermaid
flowchart LR
  A[Tower: clems] --> B[KXKM: kxkm-ai]
  B --> C[CILS: cils (photon-safe)]
  C --> D[local]
  D --> E[root (réserve)]
```

### Health-check SSH (script unique)

Exécute le script dédié:

```bash
bash tools/cockpit/ssh_healthcheck.sh
```

Le script écrit un log horodaté dans `artifacts/cockpit/` et sort en erreur si une machine est injoignable.

- `--json` : sortie JSON (utile pour cockpit / automation)
- `--no-log` : désactive la création de log
- `--verbose` : affiche plus de détails
Prérequis: droits SSH valides (clé/agent) déjà configurés et port 22 ouvert côté hôtes.

- Repos GitHub associés:
  - `https://github.com/electron-rare/Kill_LIFE`
  - `https://github.com/electron-rare/mascarade`
  - `https://github.com/electron-rare/crazy-life` (orchestrateur privé référencé localement)
- Snapshot de synchro observé:
  - [Etat machines/repos 2026-03-20](MACHINE_SYNC_STATUS_2026-03-20.md)

---

Index généré automatiquement.

## Delta mesh tri-repo 2026-03-20

- Contrat mesh: [docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md](docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md)
- Contrats publics: [specs/mesh_contracts.md](specs/mesh_contracts.md)
- Todo mesh: [docs/plans/19_todo_mesh_tri_repo.md](docs/plans/19_todo_mesh_tri_repo.md)
- Etat machines/sync: [docs/MACHINE_SYNC_STATUS_2026-03-20.md](docs/MACHINE_SYNC_STATUS_2026-03-20.md)
- TUI cockpit: [tools/cockpit/README.md](tools/cockpit/README.md)

## Full operator lane - 2026-03-20

- `docs/FULL_OPERATOR_LANE_2026-03-20.md`
- `docs/PROVIDER_RUNTIME_COMPAT_2026-03-20.md`

## Bundle global YiACAD 2026

- Audit global: [YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md](YIACAD_GLOBAL_REFACTOR_AUDIT_2026-03-20.md)
- Evaluation IA: [YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md](YIACAD_GLOBAL_AI_INTEGRATION_ASSESSMENT_2026-03-20.md)
- Feature map: [YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md](YIACAD_GLOBAL_FEATURE_MAP_2026-03-20.md)
- Recherche OSS: [YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md](YIACAD_GLOBAL_OSS_RESEARCH_2026-03-20.md)
- Architecture backend: [YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md](YIACAD_BACKEND_ARCHITECTURE_2026-03-20.md)
- Spec: [../specs/yiacad_global_refonte_spec.md](../specs/yiacad_global_refonte_spec.md)
- Spec backend: [../specs/yiacad_backend_architecture_spec.md](../specs/yiacad_backend_architecture_spec.md)
- Plan: [plans/21_plan_refonte_globale_yiacad.md](plans/21_plan_refonte_globale_yiacad.md)
- TODO: [plans/21_todo_refonte_globale_yiacad.md](plans/21_todo_refonte_globale_yiacad.md)
- Index operateur: [YIACAD_OPERATOR_INDEX_2026-03-21.md](YIACAD_OPERATOR_INDEX_2026-03-21.md)
- TUI: `bash tools/cockpit/yiacad_refonte_tui.sh --action status|backend-architecture`

## 2026-03-21 - Canonical operator entry
- Entree publique recommandee: `bash tools/cockpit/yiacad_operator_index.sh --action status`.
- Surface de preuves: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Surface de logs: `bash tools/cockpit/yiacad_logs_tui.sh --action status`.
- Les routes directes historiques restent compatibles, mais ne sont plus l'entree publique recommandee.
