# Kill_LIFE consolidation audit (2026-03-22)

## Executive summary

`Kill_LIFE` has a credible 2026 control plane now: spec-first governance, cockpit TUIs, runtime/MCP contracts, YiACAD native surfaces, and a buildable `web/` Git EDA scaffold. The main gap is no longer missing surface area. It is drift between what the docs say is canonical and what the code actually uses for intelligence, review, Git state, artifacts, and realtime.

## Strengths

- spec-first governance is real and still central
- `intelligence_tui` and `runtime_ai_gateway.sh` provide machine-readable continuity
- YiACAD now spans KiCad, FreeCAD, backend service-first hooks, and a web slice
- `web/` installs cleanly and `next build` passes
- core OSS choices are pragmatic: `Excalidraw`, `KiCanvas`, `Yjs`, `BullMQ`, `KiBot`, `KiAuto`

## Weaknesses

- lot 22 was drifting toward "done" while the web Git EDA backlog remained outside the intelligence memory
- docs were underspecifying required contract fields compared with the actual JSON Schemas
- the `web/` save/review/PR path is still filesystem- and JSON-demo-first, not Git-first
- realtime is transport-first only; Excalidraw is not yet bound to Yjs scene state
- worker outputs are not yet surfaced as proper product artifacts

## Opportunities

- use `MCP` and service-first tools for review hints, parts search, artifact fetch, and CI triggers
- expose queue/worker/realtime health inside the intelligence lane instead of keeping web ops isolated
- turn the product review surface into the differentiator: KiCad diff, Excalidraw diff, PCB preview, hints
- keep AI as an overlay on top of Git, Yjs and workers rather than as a competing source of truth

## Risks

- too many overlapping "canonical" sources if plan 22, plan 23 and TUI logic diverge again
- a false sense of Git-native collaboration while writes still bypass Git semantics
- premature AI orchestration before Git, artifacts and realtime read models are closed
- multi-tenant/security debt if `/api/project-files/*` and GraphQL stay too open

## Priority matrix

### P0

- Raccorder la lane intelligence aux sources `web/` et maintenir un backlog vivant `TODO 22 + TODO 23 + specs/04_tasks.md`.
- Remplacer le save/review web purement local par un read model Git minimal et explicite.
- Fermer la boucle `worker -> artifacts -> GraphQL -> UI` avec des URLs web-servables et un etat CI visible.

### P1

- Binder Excalidraw a Yjs sans perdre la discipline snapshot Git.
- Faire remonter le statut `queue/worker/realtime` dans la memoire intelligence et preparer le pont vers `runtime_ai_gateway.sh`.
- Ajouter une premiere surface `review hints / ops summary` en lecture seule.

### P2

- Formaliser le boundary `MCP/service-first` pour parts, artifacts, CI et review assist.
- Revenir sur LangGraph / Agents SDK seulement apres fermeture des P0/P1.
- Ouvrir la couche multi-tenant/auth quand le read model Git/CI est reel.
