# 12) Plan de gestion des agents

Last updated: 2026-03-29

Ce plan acte le hard switch vers le catalogue 2026. La source de vérité des agents `Kill_LIFE` est désormais `specs/contracts/kill_life_agent_catalog.json`. Les sous-agents restent documentés comme metadata de lane, mais seuls les agents top-level ci-dessous sont canoniques et publiquement exposables.

## Source de vérité

- Contrat canonique: `specs/contracts/kill_life_agent_catalog.json`
- Schéma du contrat: `specs/contracts/agent_catalog.schema.json`
- Docs humaines: `agents/*`, `.github/agents/*`
- Prompts catalogués: `.github/prompts/start_<agent>.prompt.md`, `.github/prompts/plan_wizard_<agent>.prompt.md`
- Validation: `python3 tools/specs/validate_agent_catalog.py --json`

## Catalogue top-level 2026

| Agent canonique | Mission | Sous-agents metadata | Write set principal |
| --- | --- | --- | --- |
| `PM-Mesh` | intake, priorisation, plans et lots | `Plan-Orchestrator`, `Intake-Guard`, `Todo-Tracker` | `specs/`, `docs/plans/`, `.github/prompts/` |
| `Arch-Mesh` | architecture, ADR, frontières et contrats | `Contract-Guard`, `Mesh-Contracts` | `specs/`, `docs/`, `kill_life/` |
| `Docs-Research` | docs canoniques, navigation, recherche, récit catalogue | `Doc-Entry`, `Plan-Recorder`, `Agent-Catalog` | `docs/`, `README.md`, `README_FR.md`, `agents/`, `.github/agents/` |
| `Runtime-Companion` | runtime IA, MCP, provider bridges, dégradation maîtrisée | `MCP-Health`, `Provider-Bridge`, `Runtime-Guard` | `tools/ai/`, `tools/ops/`, `mcp.json`, `specs/mcp_agentics_target_backlog.md` |
| `QA-Compliance` | tests, schémas, gates, evidence release-ready | `Constraint-Gate`, `Contract-Tests`, `Release-Gates` | `test/`, `compliance/`, `.github/workflows/`, `tools/specs/` |
| `Embedded-CAD` | KiCad, FreeCAD, OpenSCAD, fab et CAD host-first | `CAD-Bridge`, `HW-BOM`, `CAD-Fusion` | `tools/cad/`, `tools/hw/`, `hardware/`, `specs/kicad_mcp_scope_spec.md` |
| `Web-CAD-Platform` | web YiACAD, GraphQL, realtime, workers, review | `Project-Service`, `EDA-CI-Orchestrator`, `Realtime-Collab`, `Review-Assist`, `Artifacts-Bridge` | `web/`, `specs/yiacad_git_eda_platform_spec.md` |
| `UX-Lead` | UX YiACAD, shell natif, recherche design, UI contracts | `Apple-HIG`, `CAD-UX`, `UI-Research` | `docs/YIACAD_*`, `docs/CAD_AI_NATIVE_*`, `specs/yiacad_uiux_apple_native_spec.md` |
| `Firmware` | implémentation PlatformIO, tests, validation embarquée | `FW-Build`, `FW-Test`, `FW-Evidence` | `firmware/`, `docs/evidence/esp/` |
| `SyncOps` | cockpit, logs, incidents, SSH, mesh ops | `TUI-Ops`, `Log-Ops`, `Mesh-Cluster`, `Doc-Runbook` | `tools/cockpit/`, `artifacts/cockpit/`, `docs/MESH_*` |
| `Schema-Guard` | schémas, validateurs, invariants structurels | `Handoff-Schema`, `Evidence-Schema`, `Workflow-Schema` | `specs/contracts/`, `tools/specs/` |
| `KillLife-Bridge` | surfaces workflow/evidence inter-repo et bridge applicatif | `Workflow-Editor`, `Evidence-Runner`, `Schema-Consumer` | `workflows/`, `specs/contracts/ops_*`, `specs/contracts/artifact_*` |

## Taxonomie de lanes

La taxonomie commune utilisée dans ce repo est maintenant:

| Lane | Owner top-level | Sorties attendues |
| --- | --- | --- |
| Program Governance | `PM-Mesh` | plans, backlog, arbitrages, next lots |
| Architecture Contracts | `Arch-Mesh` | specs, ADR, interfaces, migrations |
| Documentation Catalog | `Docs-Research` | README, index, plans, catalog narrative |
| Runtime Gateway | `Runtime-Companion` | santé runtime/MCP, provider bridges, fallback |
| Quality Gates | `QA-Compliance` | tests, validateurs, evidence packs |
| CAD Native | `Embedded-CAD` | CAD host-first, fab outputs, CAD smokes |
| Web EDA | `Web-CAD-Platform` | Next.js, GraphQL, Yjs, BullMQ, review |
| UX Native | `UX-Lead` | UI audits, design contracts, shell native |
| Firmware Delivery | `Firmware` | builds, unit tests, firmware evidence |
| Operations Mesh | `SyncOps` | cockpit JSON, logs, incidents, SSH |
| Schema Governance | `Schema-Guard` | schemas, contract validators, drift gates |
| Cross-Repo Bridge | `KillLife-Bridge` | workflow bridge, handoffs, shared evidence |

## Règles de gouvernance

1. Un `owner_agent` doit toujours être l'un des 12 IDs canoniques.
2. Les sous-agents comme `Plan-Orchestrator`, `CAD-Bridge`, `Review-Assist` et `Constraint-Gate` sont de la metadata, pas des agents API.
3. Chaque lot doit publier `owner_repo`, `owner_agent`, `write_set`, `status` et `evidence`.
4. Les prompts, docs agents, README et matrice doivent rester alignés avec le contrat machine-readable.
5. Les alias historiques de l'ancienne surface BMAD à 6 agents sont retirés du runtime public et ne doivent plus être documentés comme surfaces actives.

## Routage et handoffs

- `/agents` expose uniquement le catalogue 2026.
- `/agents/{name}/run` accepte uniquement les IDs top-level canoniques.
- Les alias historiques de la surface BMAD retirée renvoient un `410 Gone` avec hint de migration vers le catalogue canonique.
- Les handoffs et preuves conservent leurs schémas existants, mais `owner_agent` doit résoudre vers le catalogue.

## Routine opératoire

1. Mettre à jour le contrat catalogué avant toute extension du catalogue.
2. Régénérer ou ajuster `agents/*`, `.github/agents/*` et les prompts par agent.
3. Valider la parité avec `tools/specs/validate_agent_catalog.py`.
4. Mettre à jour les producteurs `tools/cockpit/*`, `tools/autonomous_next_lots.py` et les contrats `specs/contracts/*`.
5. Archiver les preuves de validation dans `artifacts/ci/` et `docs/evidence/`.

## Delta 2026-03-29

- `PM-Mesh`, `Arch-Mesh`, `Docs-Research`, `Runtime-Companion`, `QA-Compliance`, `Embedded-CAD`, `Web-CAD-Platform`, `UX-Lead`, `Firmware`, `SyncOps`, `Schema-Guard` et `KillLife-Bridge` deviennent la seule couche top-level canonique.
- Les docs agents et prompts historiques de la surface BMAD à 6 agents sont retirés du runtime et remplacés par la surface catalogue 2026.
- Les producteurs de gouvernance doivent désormais publier les owners top-level et déplacer les détails de lane dans `owner_subagent`.

### Revalidation baseline / miroir / stable suite

- Baseline catalogue/runtime rejouée et archivée:
  - `artifacts/ci/agent_catalog_contract.json`
  - `artifacts/ci/validate_specs.json`
  - `artifacts/ci/catalog_runtime_pytest.log`
- Miroir `ai-agentic-embedded-base/specs` resynchronisé; validation stricte verte via:
  - `artifacts/ci/validate_specs_require_mirror_sync.json`
  - `artifacts/specs/mirror_sync_report.md`
- Gouvernance revalidée avec owners canoniques:
  - `artifacts/ci/governance_owner_agents.json`
- Suite stable rejouée avec succès:
  - `artifacts/ci/stable_suite.log`
- Blocage YiACAD traité dans `tools/cad/yiacad_backend.py`: la détection des engines est maintenant bornée par timeout et n'exécute plus le binaire GUI FreeCAD pour lire la version.
