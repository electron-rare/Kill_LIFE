# Repo Deep Analysis Plan — Kill_LIFE — 2026-03-20

## Mission

Rendre le projet totalement pilotable via:
- spec-first,
- carte fonctionnelle explicitée (Mermaid),
- séquences opérationnelles complètes,
- gestion TUI des actions + logs,
- gouvernance agentique cohérente.

## Agents actifs (actifs à date)

| Role | Mission |
| --- | --- |
| `PM` | arbitrage, priorisation, suivi des lots, clôture des jalons |
| `Architect` | cartes fonctionnelles + séquences d’exécution + ADR |
| `Firmware` | revue chaîne firmware/CI locale |
| `Hardware` | revue CAD/hardware + loops matériels |
| `QA` | sécurité, compliance, tests, preuves |
| `Doc` | alignement docs/README/runbooks |

## Livrables de la refonte

- `docs/REFACTOR_MANIFEST_2026-03-20.md` (manifest opérationnel)
- `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md` (carte fonctionnelle)
- `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md` (sequence locale)
- `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md` (sequence GitHub)
- `docs/AGENTIC_LANDSCAPE.md` (topologie agentic)
- `docs/plans/12_plan_gestion_des_agents.md` (gestion agents)
- `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md` (lot-chain)
- `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` (veille OSS intégrée)

## Analyse IA intégrée

- Evaluer les overlays IA utilisés (`ZeroClaw`, `LangGraph`, `AutoGen`, MCP) en mode pilote,
- valider les points d’orchestration hors dépendance bloquante,
- encadrer les appels externes par label/scope/gates,
- documenter chaque expérimentation dans une note de lot avec seuil de rollback.

## Plan d’exécution

- Prioriser P0 : cohérence docs/plans/README + cartes/séquences.
- P1 : durcir la gestion des logs (lecture, analyse, purge) et la preuve des actions.
- P2 : améliorer la matrice de sous-agents + rapports hebdo.

## Développements de plan suivants

- `K-DA-001` à `K-DA-004` clos via les artefacts de carte/séquence/couverture.
- `K-DA-020` à traiter via `tools/repo_state` simplifié puis re-vérification CI.
- Toutes les itérations doivent pointer vers un lot en cours dans `specs/04_tasks.md`.

## Etat courant (à réactualiser via lot-chain)

1. Alignement manifeste/specs/plans: `en cours`
2. Cartographie + séquences: `en cours`
3. Révisions repo-state et logs TUI: `en cours`
4. Matrices agents/sous-agents: `en cours`
