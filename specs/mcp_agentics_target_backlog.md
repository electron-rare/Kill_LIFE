# Backlog cible `MCP` / `agentics` / `A2A`

Last updated: 2026-03-08

Backlog canonique de convergence 2026 -> 2028 pour les trois repos.

References:

- plan canonique: `docs/plans/17_plan_target_architecture_mcp_agentics_2028.md`
- backlog KiCad MCP: `specs/mcp_tasks.md`
- backlog CAD modelling local: `specs/cad_modeling_tasks.md`
- frontiere d'architecture compagnon: `mascarade/docs/MCP_AGENTICS_ARCHITECTURE.md`

Familles d'IDs:

- `F-*` = `FreeCAD`
- `O-*` = `OpenSCAD`
- `A-*` = `agentics` / orchestration / `A2A`
- `G-*` = `GitHub`
- `N-*` = `knowledge base`

## Regles

- `KiCad` reste suivi dans `specs/mcp_tasks.md`
- chaque tache doit porter un owner repo explicite
- `A2A` reste differe tant qu'un besoin multi-agent inter-runtime n'est pas prouve

## Etat courant

- `kicad`, `validate-specs`, `freecad`, `openscad`, `huggingface` remontent `ready` dans `/api/ops/summary`
- `knowledge-base` (MCP de compat vers `memos|docmost`) et `github-dispatch` sont `ready`, avec validations live fermees
- `FreeCAD` et `OpenSCAD` ont chacun un runtime headless, un smoke JSON, un launcher MCP et un smoke MCP
- `OpsHub` et `Logs` savent relancer un probe MCP par serveur
- `A2A` reste ferme
- restes specialises actifs:
  - aucun blocker MCP/agentics local actif sur la machine de reference
  - `K-012` reste une validation host-native optionnelle tant que le runtime canonique KiCad est le conteneur
  - `nexar_api` a son chemin live valide; le token de reference atteint Nexar mais reste limite par un quota externe (`part limit of 0`)

## Backlog

- [x] N-001 — Valider le MCP knowledge base en live
  - Owner: `Kill_LIFE`
  - Status: done
  - AC: `search_pages` et `read_page` sont verifies sur le provider knowledge base actif.
  - Resultat: smoke live ferme sur le provider actif `memos`, avec `search_pages` et `read_page` valides.

- [x] G-001 — Valider `GitHub dispatch MCP` en live
  - Owner: `Kill_LIFE`
  - Status: done
  - AC: `list_allowlisted_workflows` et `dispatch_workflow` sont verifies sur une cible reelle autorisee.
  - Resultat: validation live fermee via token GitHub persiste dans `runtime-secrets`, avec `list_allowlisted_workflows`, `dispatch_workflow` et `get_dispatch_status` verifies.

- [x] F-001 — Ajouter un smoke `FreeCAD` versionne
  - Owner: `Kill_LIFE`
  - AC: `FreeCAD` est qualifie en headless avec sortie JSON canonique.
  - Evidence: `python3 tools/hw/freecad_smoke.py --json`

- [x] F-002 — Classer `FreeCAD` comme `supporte`
  - Owner: `Kill_LIFE`
  - AC: la doc operateur et la matrice de support ne laissent plus de statut implicite.
  - Evidence: `deploy/cad/README.md`, `specs/cad_modeling_tasks.md`

- [x] O-001 — Ajouter le runtime `OpenSCAD` a la stack CAD
  - Owner: `Kill_LIFE`
  - AC: compose + image + wrapper `cad_stack.sh openscad` existent.
  - Evidence: `deploy/cad/Dockerfile.openscad-headless`, `deploy/cad/docker-compose.yml`, `tools/hw/cad_stack.sh`

- [x] O-002 — Ajouter un smoke `OpenSCAD` versionne
  - Owner: `Kill_LIFE`
  - AC: `OpenSCAD` version, rendu minimal et export local sont verifies en headless.
  - Evidence: `python3 tools/hw/openscad_smoke.py --json`

- [x] O-003 — Classer `OpenSCAD` comme `supporte` ou `experimental`
  - Owner: `Kill_LIFE`
  - AC: la doc operateur porte un statut explicite.
  - Decision: `supporte` en headless local.

- [x] F-101 — Implementer `FreeCAD MCP v1`
  - Owner: runtime `Kill_LIFE`, observabilite `mascarade`
  - AC: un serveur `freecad-mcp` expose les operations v1 retenues sans UI graphique obligatoire.
  - Evidence: `tools/run_freecad_mcp.sh`, `tools/freecad_mcp.py`, `python3 tools/freecad_mcp_smoke.py --json`

- [x] O-101 — Implementer `OpenSCAD MCP v1`
  - Owner: runtime `Kill_LIFE`, observabilite `mascarade`
  - AC: un serveur `openscad-mcp` expose une surface stateless `render/export/validate`.
  - Evidence: `tools/run_openscad_mcp.sh`, `tools/openscad_mcp.py`, `python3 tools/openscad_mcp_smoke.py --json`

- [x] A-001 — Ajouter un modele de statut unifie par serveur MCP
  - Owner: `mascarade`
  - AC: `ops-agent` et `/api/ops/summary` exposent un etat stable pour `kicad`, `knowledge-base`, `github-dispatch`, `freecad` et `openscad`.
  - Evidence: `/api/ops/summary`, `POST /api/ops/mcp/probe/:serverKey`

- [x] A-002 — Ajouter des spans OTel par serveur MCP
  - Owner: `mascarade`
  - AC: chaque serveur MCP emet au minimum `initialize`, `tools/list`, `tools/call` et erreurs dans la telemetrie.
  - Resultat: `ops-agent` emet des evenements OTLP structures `source=mcp-probe` pour `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` et `huggingface`, visibles dans Loki avec `server_key`, `probe_phase`, `probe_status`, `protocol_version`, `runtime_mode` et compteurs.
  - Resultat: le core emet des traces metier `mcp_call_started`, `mcp_call_completed`, `mcp_call_failed`, avec `mcp_server`, `mcp_tool`, `mcp_status`, `mcp_transport`, `mcp_latency_ms`, `mcp_protocol_version`.
  - Resultat: `/api/ops/logs/query` et la page `Logs` savent filtrer `source=mcp-probe` ainsi que `mcp_server`, `mcp_tool`, `mcp_status`.
  - Resultat: le dashboard Grafana `Mascarade AI Runtime` inclut maintenant des panneaux MCP (`MCP Probes / 15m`, `MCP Call Failures / 15m`, `MCP Calls By Server`, `Recent MCP Call Failures`).

- [x] A-003 — Brancher l'orchestrateur sur les MCP specialises
  - Owner: `mascarade`
  - AC: l'orchestrateur utilise les serveurs MCP pour la knowledge base, `GitHub`, `FreeCAD` et `OpenSCAD` au lieu de chemins ad hoc.
  - Resultat: un client MCP interne commun existe maintenant dans `core/mascarade/mcp/client.py`.
  - Resultat: les routes core `knowledge-base/*` et `agents/knowledge-scribe/run-and-push` passent par `knowledge-base` MCP.
  - Resultat: les routes core `mcp/github-dispatch/*` existent, et le chemin d'execution `github-dispatch` du workflow editor passe par le core MCP au lieu d'un appel GitHub direct cote API.
  - Resultat: les routes core et API `FreeCAD` / `OpenSCAD` passent maintenant par le client MCP interne, avec `run_id` propage et erreurs MCP explicites.
  - Resultat: les integrations directes restantes ne sont plus le chemin runtime canonique; elles restent seulement comme compat/tests.

- [x] A-004 — Specifier la frontiere `MCP` vs `A2A`
  - Owner: `mascarade`
  - AC: une doc d'architecture explique ce qui reste en `MCP` et ce qui pourrait migrer en `A2A`.
  - Evidence: `mascarade/docs/MCP_AGENTICS_ARCHITECTURE.md`

- [x] A-201 — Ajouter une vue cockpit par serveur MCP
  - Owner: `crazy_life`
  - AC: le cockpit expose le detail `ready / degraded / failed` pour les serveurs supportes.
  - Evidence: `src/pages/OpsHub.tsx`, `src/pages/Logs.tsx`

- [x] A-202 — Ajouter des actions operateur ciblees
  - Owner: `crazy_life`
  - AC: l'UI peut declencher les smokes et afficher les erreurs actionnables sans reimplementer les serveurs.
  - Evidence: route `POST /api/ops/mcp/probe/:serverKey` + boutons `run probe`

- [x] A-203 — Ajouter une vue de supervision `agentics`
  - Owner: `crazy_life`
  - AC: l'operateur visualise les runs, handoffs et appels MCP lies a un `run_id`.
  - Resultat: carte `Run supervision` et correlation `run_id` disponibles dans `Orchestrate`.
  - Resultat: la timeline `Orchestrate` filtre par `mcp_server`, `mcp_tool`, `mcp_status` et affiche les appels MCP correles au `run_id`.
  - Resultat: validations live fermees sur `github-dispatch`, `FreeCAD` et `OpenSCAD`, avec traces `mcp_call_started` puis `mcp_call_completed` visibles pour le meme `run_id`.

- [x] A-005 — Evaluer l'introduction de `A2A`
  - Owner: `mascarade`
  - Status: done
  - Decision: `A2A` reste differe / not now.
  - Motif: la couche MCP specialisee couvre deja le tool plane, l'orchestrateur `mascarade` couvre le besoin courant, et aucun besoin prouve de handoff inter-agents entre runtimes ou domaines de confiance distincts n'est etabli.
  - Condition de reouverture: un besoin multi-agent reel doit apparaitre et ne pas pouvoir etre satisfait proprement avec l'orchestrateur actuel + MCP.

## Prochaine sequence canonique

1. sortir les bundles locaux multi-repo restants sans rouvrir de chantier `MCP/agentics`
2. ne rejouer `K-012` que si le host-native devient une exigence runtime
3. n'ouvrir un chantier `nexar_api` supplementaire que si un plan/quota Nexar utile devient necessaire
4. rouvrir `A2A` seulement si un besoin inter-runtime reel apparait
