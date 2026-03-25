# Cockpit

Entrée outillage/TUI canonique pour piloter `Kill_LIFE` en local.

## Entrées recommandées

- `bash tools/cockpit/yiacad_operator_index.sh --action status` : point d'entrée opérateur public
- `bash tools/cockpit/intelligence_tui.sh --action status --json` : point d'entrée gouvernance intelligence/agents/MCP/IA
- `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json` : synthèse canonique runtime/MCP/IA, avec surface auxiliaire `firmware_cad`, à partir de la mémoire intelligence, du mesh, de Mascarade et des preuves firmware/CAD
- `bash tools/cockpit/refonte_tui.sh --action status` : raccourcis historiques et lots de refonte
- `bash tools/cockpit/full_operator_lane.sh status --json` : lane opérateur consolidée
- `bash tools/cockpit/run_alignment_daily.sh --json` : routine quotidienne santé + preuves

Les sorties JSON cockpit convergent vers le contrat `cockpit-v1`: `contract_version`, `component`, `action`, `status`, `contract_status`, `artifacts`, `degraded_reasons`, `next_steps`.

## Surfaces principales

- `menu` : menu simple
- `gate_s0` : check “spec ready”
- `fw` : build/test firmware
- `hw` : gates hardware (ERC/netlist/BOM)
- `mesh_sync_preflight.sh` : snapshot tri-repo (`Kill_LIFE`, `mascarade`, `crazy_life`) local + SSH, statut `ready|degraded|blocked`
- `mesh_health_check.sh` : rapprochement consolidé `mesh_sync_preflight` + `readme_repo_coherence` + `log_ops` (avec `mesh_host_order`).
- `log_ops.sh` : synthèse JSON, purge contrôlée et inventaire des artefacts de logs.
- `lots-status` : état des lots locaux utiles + prochaine vraie question + resynchronisation de `docs/plans/18_*`
- `lots-run` : enchaîne les lots auto-fix, la lane `autonomous_next_lots`, les validations, puis met à jour le suivi.
- `run_next_lots_autonomously.sh` : enchaîne automatiquement tous les lots utiles détectés, un à un.
- `runtime_ai_gateway.sh` : agrège la mémoire `intelligence_tui`, le mesh health et le runtime Mascarade/Ollama en un statut unique `ready|degraded|blocked`, expose une surface auxiliaire `firmware_cad`, publie `firmware_cad_summary_short_latest.json`, et dégrade vite le mode `--refresh` si une probe dépasse son timeout.
- `bash tools/ai/zeroclaw_integrations_lot.sh verify` : validate ZeroClaw/n8n + smoke workflow.
- `bash tools/ai/zeroclaw_integrations_lot.sh verify` remonte désormais un échec si le runtime n8n reste `degraded` ou `blocked`.
- `ssh_healthcheck.sh` : check en lot de connectivite SSH sur les machines operateurs.
- `mascarade_runtime_health.sh` : health-check live Mascarade/Ollama, smoke agent low-cost, artefacts JSON `latest.*`.
- `mascarade_logs_tui.sh` : lecture, analyse, inventaire et purge contrôlée des artefacts Mascarade/Ollama.
- `mascarade_incidents_tui.sh` : vue TUI dédiée des incidents Mascarade/Ollama (`summary|watch|brief|registry|queue|daily`).
- `render_mascarade_incident_brief.sh` : export Markdown court des incidents/runtime Mascarade/Ollama pour la revue opérateur.
- `mascarade_incident_registry.sh` : registre Markdown/JSON horodaté des incidents Mascarade/Ollama à partir des artefacts cockpit/opérateur.
- `render_mascarade_incident_queue.sh` : file d’incidents Markdown/JSON triée par priorité, sévérité puis récence pour la revue opérateur.
- `render_mascarade_incident_watch.sh` : watchboard Markdown/JSON ultra-court avec rollup priorité/sévérité, top queue et prochaines actions.
- `render_mascarade_watch_history.sh` : historique Markdown/JSON des watchboards pour suivre l’évolution des `P1/P2/P3` et `high/medium/low` sur plusieurs runs.
- `render_daily_operator_summary.sh` : synthèse quotidienne Markdown/JSON pour l’opérateur à partir du daily log, du brief, du registre et de la queue.
- `full_operator_lane.sh` : runbook TUI `status|dry-run|live|all|logs|purge` pour la lane operateur.
- `bash tools/cockpit/full_operator_lane.sh logs --json --logs-action summary|latest|list|purge` : surface native lane operateur pour piloter les logs Mascarade/Ollama.
- `full_operator_lane_sync.sh` : propagation conservative du patchset operateur vers les lanes mesh, avec option `--mode clems-live`.
- `yiacad-fusion` : préparation et smoke de la couche IA-native CAD (KiCad + FreeCAD) avec logs dédiés.
- `intelligence_tui.sh` : index TUI de la gouvernance intelligence (audit, spec, plan, TODO, research, owners, memory, next-actions, logs) couvrant le lot 22 et le plan 23 `web/`.
- `bash tools/cockpit/intelligence_tui.sh --action scorecard --json` : score de fragmentation documentaire, maturite par lane et artefacts `scorecard_latest.*`.
- `bash tools/cockpit/intelligence_tui.sh --action comparison --json` : comparaison inter-repos entre `Kill_LIFE`, `ai-agentic-embedded-base`, `kill-life-studio`, `kill-life-mesh` et `kill-life-operator`.
- `bash tools/cockpit/intelligence_tui.sh --action recommendations --json` : file de recommandations IA priorisee issue de l'audit et de la veille OSS.
- `intelligence_program_tui.sh` : alias de compatibilité vers `intelligence_tui.sh` pour les anciens runbooks.
- `lot_chain.sh` rafraîchit `intelligence_tui --action memory --json` avant d’écrire son statut et ses prochains choix manuels.
- `bash tools/cockpit/refonte_tui.sh --action yiacad-fusion[:prepare|smoke|status|logs|clean-logs]` : exécute le lot YiACAD (préparation, vérification, statut, logs, purge).
- `bash tools/cockpit/refonte_tui.sh --action intelligence|intelligence:plan|intelligence:todo|intelligence:research` : pont de compatibilité depuis la TUI refonte.
- `bash tools/cockpit/intelligence_tui.sh --action memory --json` : écrit `artifacts/cockpit/intelligence_program/latest.json` et `latest.md` pour la continuité opérateur.
- `bash tools/cockpit/intelligence_tui.sh --action scorecard|comparison|recommendations --json` : met aussi à jour les artefacts `scorecard_latest.*`, `repo_comparison_latest.*` et `recommendation_queue_latest.*`.
- `bash tools/cockpit/intelligence_tui.sh --action next-actions` : derive les prochaines actions prioritaires depuis `TODO 22`, `TODO 23`, puis `specs/04_tasks.md`.
- `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json` : met à jour et lit la passerelle consolidée runtime/MCP/IA.
- `bash tools/cad/install_yiacad_native_gui.sh install` : installe le plugin KiCad et le workbench FreeCAD de YiACAD.
- `weekly-summary` : synthèse hebdomadaire opératoire pour lots, logs et état machine.
- `bash tools/cockpit/refonte_tui.sh --action weekly-summary` : génère `artifacts/cockpit/weekly_refonte_summary.md`.
- Journaux YiACAD: `artifacts/cad-fusion/`.
- `bash tools/cockpit/yiacad_uiux_tui.sh --action logs-summary|logs-list|logs-latest|purge-logs` : lecture/analyse/purge des logs UI/UX.
- `bash tools/cockpit/yiacad_uiux_tui.sh --action program-audit|next-spec|next-feature-map` : audit global YiACAD, spec du lot suivant et feature map Mermaid.
- `bash tools/cockpit/yiacad_refonte_tui.sh --action status|backend-architecture|audit|ai-assessment|feature-map|spec|plan|todo|research|logs-summary|logs-list|logs-latest|purge-logs` : bundle global YiACAD (audit, backend, IA, plan, TODO, veille, logs).
- `bash tools/cockpit/yiacad_operator_index.sh --action incident-watch|incident-history` : raccourcis opérateur très courts vers le watchboard Mascarade et son historique.
- `bash tools/cockpit/machine_registry.sh --action summary|list|show --json` : registre canonique machines/capacités/placements.
- `mesh_sync_preflight.sh` consomme le registre canonique pour les rôles, ports, priorités de charge, placements et cible de réserve.
- `refonte_tui.sh --action mesh-preflight` : exécution TUI du préflight mesh.
- `refonte_tui.sh --action mesh-preflight --mesh-load-profile photon-safe` : même préflight en mode allègement CILS.
- `refonte_tui.sh --action ssh-health` : exécution TUI du health-check SSH.
- `refonte_tui.sh --action mascarade-health` : exécution TUI du health-check Mascarade/Ollama.
- `refonte_tui.sh --action mascarade-logs` : raccourci TUI vers `full_operator_lane.sh logs --logs-action summary`.
- `refonte_tui.sh --action mascarade-logs-summary|mascarade-logs-latest|mascarade-logs-list|mascarade-logs-purge` : raccourcis TUI directs vers la surface logs native opérateur.
- `refonte_tui.sh --action mascarade-incidents|mascarade-incidents-watch|mascarade-incidents-brief|mascarade-incidents-registry|mascarade-incidents-queue|mascarade-incidents-daily` : vues TUI directes pour le watchboard, le brief, le registre, la queue et la synthèse quotidienne Mascarade.
- `refonte_tui.sh --action log-ops` : résumé centralisée logs avec JSON.
- `refonte_tui.sh --action logs` : affichage + analyse courte des logs récents.
- `refonte_tui.sh --action weekly-summary` : synthèse markdown prête pour revue d’agent / opérateur.
- `refonte_tui.sh --action clean-logs --days 14 --yes-auto` : purge ciblée de logs plus anciens en mode non interactif
- `mesh_sync_preflight.sh` : vérification convergence tri-repo (commande canonique)

Note:
- `lots-run` peut sortir avec le code `3` quand la chaîne est saine mais qu'un vrai choix opérateur reste nécessaire.
- Tous les outputs → `artifacts/`.

## 1) Health-check SSH (script de routine)

- Script: `bash tools/cockpit/ssh_healthcheck.sh --json`
- Cibles standard (priorité P2P):

| Machine | Port | Priorité | Rôle |
| --- | --- | --- | --- |
| `clems@192.168.0.120` | 22 | 1 | Machine de pilotage / orchestration locale |
| `kxkm@kxkm-ai` | 22 | 2 | Mac opérateur |
| `cils@100.126.225.111` | 22 | 3 | Mac opérateur secondaire (photon, non essentiel) |
| `root@192.168.0.119` | 22 | 4 | Serveur système / exécution matérielle (réserve) |

- Référence de preuve: `artifacts/cockpit/ssh_healthcheck_<YYYYMMDD>_<HHMMSS>.log`
- Politique P2P de charge (réseau 4 cibles): priorité `Tower -> KXKM -> CILS -> local -> root`,
  chargement dynamique par score `load_ratio = loadavg / CPUs` + priorité statique.
  `cils` est verrouillé en `tower-first`: seuls les snapshots critiques `Kill_LIFE` sont lancés par défaut.
  mode `photon-safe` force `cils` en "no load": tout précheck applicatif distant CILS est ignoré (`cils-lockdown-photon-safe`).
  Les hôtes non critiques surchargés (`load_ratio > 1.8`) sont marqués en `degraded` sur cette passe.
  Les sorties SSH inattendues / non conformes ne cassent plus la passe: elles sont marquées `unreachable` ou `degraded` et restent dans le journal JSON.
  Priorité opérationnelle: `Tower` (`clems`) -> `KXKM` -> `CILS` (quota contrôlé) -> `local` -> `root` (réserve).

  - `bash tools/cockpit/mesh_sync_preflight.sh --load-profile tower-first`
  - `bash tools/cockpit/mesh_sync_preflight.sh --load-profile photon-safe`
  - `bash tools/cockpit/mesh_sync_preflight.sh --photon-safe`

## 2) Routine quotidienne recommandée (runbook)

1. health-check SSH ciblé
2. health-check Mascarade/Ollama live
3. refresh header repo (refresh docs d'état)
4. lecture + purge de logs via `tools/cockpit/log_ops.sh`
5. préflight mesh avec stratégie de charge (tower-first par défaut)

Exemple:

```bash
bash tools/cockpit/ssh_healthcheck.sh --json
bash tools/cockpit/mascarade_runtime_health.sh --json
bash tools/repo_state/repo_refresh.sh --header-only
bash tools/cockpit/log_ops.sh --action summary --json
bash tools/cockpit/mesh_health_check.sh --json
```
Consolidé journalier:

```bash
bash tools/cockpit/run_alignment_daily.sh --json --mesh-load-profile tower-first
bash tools/cockpit/log_ops.sh --action summary --json
bash tools/cockpit/render_weekly_refonte_summary.sh
```
Forcer le mode photon-safe:

```bash
bash tools/cockpit/run_alignment_daily.sh --json --skip-healthcheck --mesh-load-profile photon-safe --skip-log-ops
```

Si l’hôte est saturé, le preflight mesh peut être désactivé au passage:

```bash
bash tools/cockpit/run_alignment_daily.sh --json --skip-mesh --skip-healthcheck
```

Purge contrôlée:

```bash
bash tools/cockpit/log_ops.sh --action purge --apply --retention-days 14
```

`run_alignment_daily` expose maintenant un résumé JSON dédié `mascarade_health_status`, `mascarade_runtime_status`, `mascarade_provider`, `mascarade_model`, `mascarade_health_artifact`, `log_ops_summary_status`, `log_ops_stale`, `log_ops_purge_status` et `log_ops_purged`, et propose la purge de logs en contrôle de routine.

`run_alignment_daily` capture aussi désormais `mascarade_logs_status`, `mascarade_logs_artifact`, `mascarade_brief_status`, `mascarade_brief_artifact` et `mascarade_brief_markdown`, afin que `machine_alignment_daily_latest.log` embarque un snapshot logs/runtime Mascarade/Ollama et un brief opérateur court.

`run_alignment_daily` exporte aussi désormais `mascarade_registry_status`, `mascarade_registry_artifact`, `mascarade_registry_markdown`, `mascarade_queue_status`, `mascarade_queue_artifact`, `mascarade_queue_markdown`, `daily_operator_summary_status`, `daily_operator_summary_artifact` et `daily_operator_summary_markdown`.

`run_alignment_daily` exporte aussi désormais `mascarade_watch_status`, `mascarade_watch_artifact` et `mascarade_watch_markdown` pour fournir un artefact de garde plus court que la synthèse quotidienne complète.

`run_alignment_daily` exporte aussi désormais `mascarade_watch_history_status`, `mascarade_watch_history_artifact` et `mascarade_watch_history_markdown` pour garder une trace courte de l’évolution des priorités sur plusieurs runs.

`run_alignment_daily` recalcule maintenant son `result` et son `contract_status` après la génération de la synthèse opérateur quotidienne, afin que le statut final reflète aussi un échec ou une dégradation sur `daily_operator_summary`.

`render_daily_operator_summary.sh` et `render_weekly_refonte_summary.sh` intègrent désormais aussi la `mascarade incident queue`, afin que la priorisation opératoire apparaisse dans l’handoff quotidien comme dans la synthèse hebdomadaire.

`render_daily_operator_summary.sh` affiche aussi un rollup ultra-court `priority P1/P2/P3` et `severity high/medium/low` pour accélérer la lecture opérateur.

`render_mascarade_watch_history.sh` fournit désormais un mini registre temporel des watchboards pour suivre l’évolution des incidents courts sans relire chaque artefact daily.

`full_operator_lane.sh` capture aussi automatiquement un snapshot `logs --logs-action latest` après `dry-run|live|all`, afin de conserver l’état Mascarade/Ollama le plus récent dans les artefacts opérateur.

`full_operator_lane.sh` embarque désormais aussi la file d’incidents Mascarade (`mascarade_queue_*`), le watchboard court (`mascarade_watch_*`) et la synthèse opérateur quotidienne (`daily_operator_summary_*`) dans son contrat JSON natif.

`full_operator_lane.sh --json` expose aussi désormais `priority_counts` et `severity_counts` au niveau top-level pour une lecture immédiate côté opérateur ou automation.

`render_weekly_refonte_summary.sh` rafraîchit désormais aussi le brief, le registre, la queue, le watchboard incident et son historique Mascarade/Ollama avant de générer la synthèse hebdomadaire.

Contrat JSON commun `cockpit-v1`:

- champs communs introduits sur les sorties JSON cockpit/TUI ciblées: `contract_version`, `component`, `action`, `status`, `contract_status`, `artifacts`, `degraded_reasons`, `next_steps`
- helper partagé: `tools/cockpit/json_contract.sh`
- `mesh_sync_preflight.sh --json` expose aussi `registry_file`, `registry_status` et des `host_profiles` enrichis (`id`, `placement`, `reserve_only`)
- `run_alignment_daily.sh --json` expose aussi `mascarade_health_status`, `mascarade_runtime_status`, `mascarade_provider`, `mascarade_model` et `mascarade_health_artifact`

## 3) Delta mesh tri-repo 2026-03-20

- `mesh_sync_preflight.sh`: vérifie convergence multi-machines/multi-repos.
- `log_ops.sh`: synthèse et purge contrôlée des logs avec sortie JSON exploitable.

## Delta 2026-03-21 - entree operateur YiACAD

- `bash tools/cockpit/yiacad_operator_index.sh --action status|uiux|global|backend|proofs|logs-summary|logs-list|logs-latest|purge-logs` : entree operateur stable entre la lane UI/UX, la lane globale et le backend service.
- `backend-proof`, `review-session`, `review-history` et `review-taxonomy` restent compatibles mais pointent vers les routes canoniques.

## Delta 2026-03-21 - backend service YiACAD

- `bash tools/cockpit/yiacad_backend_service_tui.sh --action status|health|logs-summary|logs-list|logs-latest|purge-logs` : surface operatoire du backend service YiACAD.
- Elle est la destination canonique de `backend` depuis l'index opérateur.

## 2026-03-21 - Canonical operator entry
- Entree publique recommandee: `bash tools/cockpit/yiacad_operator_index.sh --action status`.
- Surface de preuves: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Surface de logs: `bash tools/cockpit/yiacad_logs_tui.sh --action status`.
- Les routes directes historiques restent compatibles, mais ne sont plus l'entree publique recommandee.

## Delta 2026-03-21 - Mascarade Tower / dispatch mesh

- `tower` (`clems@192.168.0.120`) est maintenant normalise comme premiere cible lourde Mascarade/Ollama.
- Runtime:
  - `bash tools/ops/deploy_mascarade_tower_runtime.sh --action status --json`
  - `bash tools/ops/deploy_mascarade_tower_runtime.sh --action apply --json`
- Seed agents Tower:
  - `bash tools/ops/sync_mascarade_agents_tower.sh --action plan --json`
  - `bash tools/ops/sync_mascarade_agents_tower.sh --action sync --apply --json`
- Dispatch mesh:
  - `bash tools/cockpit/mascarade_dispatch_mesh.sh --action summary --json`
  - `bash tools/cockpit/mascarade_dispatch_mesh.sh --action route --profile tower-code --json`
  - `bash tools/cockpit/mascarade_dispatch_mesh.sh --action route --profile kxkm-analysis --json`
- Politique P2P retenue:
  - charges lourdes: `tower -> kxkm -> local -> cils -> root-reserve`
  - texte interactif / docs: `kxkm -> tower -> local -> cils -> root-reserve`
- Contrats:
  - `specs/contracts/mascarade_model_profiles.tower.json`
  - `specs/contracts/mascarade_dispatch.mesh.json`

## Delta 2026-03-21 - contrat produit ops / Mascarade / kill_life

- Contrat commun:
  - `specs/contracts/ops_mascarade_kill_life.contract.json`
- Doc de cadrage:
  - `docs/OPS_MASCARADE_KILL_LIFE_PRODUCT_CONTRACT_2026-03-21.md`
- Objectif:
  - `ops` montre l'etat reel et declenche l'action
  - `Mascarade` recommande avec `trust_level` et routing explicites
  - `kill_life` persiste `resume_ref`, decision et handoff
- Prochain lot recommande:
  - projeter `status`, `decision`, `owner`, `artifacts`, `next_step`, `resume_ref`, `trust_level`, `routing` et `memory_entry` dans les sorties JSON cockpit prioritaires

## Delta 2026-03-21 - projection contrat produit

- Writer memoire:
  - `bash tools/cockpit/write_kill_life_memory_entry.sh --component run_alignment_daily --json`
- `full_operator_lane.sh --json` expose maintenant aussi:
  - `owner`
  - `decision`
  - `resume_ref`
  - `trust_level`
  - `routing`
  - `memory_entry`
- `run_alignment_daily.sh --json` expose maintenant aussi:
  - `owner`
  - `decision`
  - `resume_ref`
  - `trust_level`
  - `routing`
  - `memory_entry`
- la continuité `kill_life` est matérialisée dans:
  - `artifacts/cockpit/kill_life_memory/latest.json`
  - `artifacts/cockpit/kill_life_memory/latest.md`

## Delta 2026-03-21 - surfaces Mascarade courtes alignées

- `mascarade_runtime_health.sh --json` expose maintenant aussi:
  - `owner`
  - `decision`
  - `resume_ref`
  - `trust_level`
  - `routing`
  - `memory_entry`
- `mascarade_incidents_tui.sh --json` relit désormais la continuité `kill_life` latest et remonte:
  - `resume_ref`
  - `trust_level`
  - `routing`
  - `memory_entry`
- `render_daily_operator_summary.sh` et `render_weekly_refonte_summary.sh` affichent aussi la reprise `kill_life` dans le Markdown de handoff.

## Delta 2026-03-21 - surfaces Mascarade très courtes alignées

- `render_mascarade_incident_brief.sh`, `render_mascarade_incident_queue.sh`, `render_mascarade_incident_watch.sh` et `render_mascarade_watch_history.sh` relisent aussi désormais:
  - `trust_level`
  - `resume_ref`
  - `routing`
  - `memory_entry`
- les résumés Markdown Mascarade n'obligent plus à basculer vers une autre surface pour comprendre la reprise opérateur.

## Delta 2026-03-21 - correction mémoire kill_life et dernières surfaces

- `write_kill_life_memory_entry.sh` exporte désormais correctement les `artifacts` vers sa charge Python.
- `mascarade_incident_registry.sh` relit maintenant aussi:
  - `trust_level`
  - `resume_ref`
  - `routing`
  - `memory_entry`
- `mascarade_logs_tui.sh` remonte désormais ces champs sur les vues `summary`, `list` et `latest`.

## Delta 2026-03-21 - gouvernance et points d'entrée

- `yiacad_operator_index.sh` affiche maintenant explicitement la continuité `kill_life` dans son statut:
  - `artifacts/cockpit/kill_life_memory/latest.md`
  - `artifacts/cockpit/daily_operator_summary_latest.md`
- `intelligence_tui.sh --action memory` relie aussi la mémoire de gouvernance à la mémoire de reprise `kill_life`.

## Delta 2026-03-21 - chaînes de pilotage cockpit

- `refonte_tui.sh --action status` pointe désormais aussi vers:
  - `artifacts/cockpit/kill_life_memory/latest.json`
  - `artifacts/cockpit/kill_life_memory/latest.md`
  - `artifacts/cockpit/daily_operator_summary_latest.md`
- `lot_chain.sh` publie maintenant la continuité `kill_life` dans:
  - `artifacts/cockpit/useful_lots_status.md`
  - le bloc `AUTO LOT-CHAIN PLAN` de `specs/03_plan.md`
  - le bloc `AUTO LOT-CHAIN TASKS` de `specs/04_tasks.md`
- objectif:
  - garder le même point de reprise entre la TUI courte, la chaîne de lots et les handoffs cockpit

## Delta 2026-03-21 - audit statique du contrat produit

- `bash tools/cockpit/product_contract_audit.sh`
- sorties:
  - `artifacts/cockpit/product_contract_audit/latest.json`
  - `artifacts/cockpit/product_contract_audit/latest.md`
- objectif:
  - vérifier sans relance runtime que les surfaces cockpit et les points d'entrée gardent visibles les ancrages `resume_ref`, `trust_level`, `routing` et `memory_entry`
- cartographie associée:
  - `docs/OPS_MASCARADE_KILL_LIFE_FEATURE_MAP_2026-03-21.md`

## Delta 2026-03-21 - handoff produit minimal

- `bash tools/cockpit/render_product_contract_handoff.sh`
- sorties:
  - `artifacts/cockpit/product_contract_handoff/latest.json`
  - `artifacts/cockpit/product_contract_handoff/latest.md`
- objectif:
  - agréger l'audit de contrat, la mémoire `kill_life` latest et le handoff quotidien dans un seul brief opérateur court

## Delta 2026-03-21 - handoff produit auto-régénérant

- `bash tools/cockpit/render_product_contract_handoff.sh`
  - défaut: tente de régénérer les prérequis légers `kill_life` et `daily_operator_summary`
  - mode strict: `bash tools/cockpit/render_product_contract_handoff.sh --no-refresh`
- champs JSON ajoutés:
  - `degraded_reasons`
  - `prereqs_refreshed`
  - `kill_life_refresh_status`
  - `daily_refresh_status`
  - `markdown_file`
  - `latest_markdown_file`
- intégration dans les chemins opérateur:
  - `run_alignment_daily.sh --json`
  - `full_operator_lane.sh --json`
  - `yiacad_operator_index.sh --action status`
  - `refonte_tui.sh --action status`
- garde-fou:
  - `product_contract_audit.sh` vérifie maintenant aussi la présence du handoff et son exposition dans les points d'entrée opérateur
- distinction retenue:
  - audit statique = cohérence source des surfaces
  - handoff runtime léger = disponibilité réelle du point de reprise canonique

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
