# MCP / Service Boundary

Last updated: 2026-03-25

## Principle

**MCP tool** = callable by an LLM agent via the MCP protocol (tool-use).
Suited for: discrete actions, agent-driven workflows, operations that benefit from natural-language orchestration.

**Direct service** = HTTP API or internal function call, not exposed as MCP tools.
Suited for: high-frequency polling, realtime sync, queue plumbing, health/observability, file serving.

Decision rule: if an agent needs to *decide* to do it, it is an MCP tool.
If the web app or CI does it mechanically on every request, it is a service.

---

## Boundary Table

| Capability | Category | Endpoint / Tool | Owner | Rationale |
|---|---|---|---|---|
| **EDA worker jobs** (ERC/DRC, KiBot, STEP export) | MCP tool | `kicad` MCP server (`kicad-erc-drc`, `ecad-mcad-sync`) | `tools/hw/run_kicad_mcp.sh` | Agent chooses which pipeline to run, inspects results, iterates. |
| **Parts search** | MCP tool | `nexar_api` MCP micro-server (`search_component`) + `component_database` | `kicad_kic_ai` auxiliary | Agent queries part availability/specs during design review. Nexar token scoped. |
| **CI trigger** | MCP tool | `github-dispatch` MCP server (`dispatch_workflow`, `get_dispatch_status`) | `tools/run_github_dispatch_mcp.sh` | Agent decides when to trigger CI and which workflow. |
| **Artifact fetch** (read results) | MCP tool | `kicad` MCP server (read artifacts) | `tools/hw/run_kicad_mcp.sh` | Agent needs to inspect DRC reports, BOM, Gerber output to reason about next steps. |
| **Review hints** (design review) | MCP tool | `knowledge-base` MCP server (`search_pages`) + `validate-specs` | `tools/run_knowledge_base_mcp.sh`, `tools/run_validate_specs_mcp.sh` | Agent retrieves design rules and validates specs against them. Requires judgment. |
| **HuggingFace model/dataset search** | MCP tool | `huggingface` MCP server | `https://huggingface.co/mcp` | Agent-driven exploration. |
| EDA queue management (enqueue, retry, drain) | Service | `web/lib/eda-queue.ts` -> BullMQ/Redis | `web/workers/eda-worker.mjs` | Mechanical plumbing. The web app enqueues; the worker dequeues. No agent decision needed. |
| CI run bookkeeping (runs.json, artifacts.json) | Service | `web/lib/ci-enqueue.ts` -> local JSON files | `web/` | Internal state tracking. Agent uses `github-dispatch` MCP to trigger; bookkeeping is automatic. |
| Artifact file serving | Service | `GET /api/artifacts/[...segments]` | `web/app/api/artifacts/` | Static file serving over HTTP. Agent gets URLs from MCP tool results, browser fetches them. |
| Project file serving | Service | `GET /api/project-files/[...segments]` | `web/app/api/project-files/` | Same: static serving, not agent-decided. |
| GraphQL API | Service | `POST /api/graphql` | `web/app/api/graphql/` | Structured queries for the frontend. Not tool-shaped. |
| Health / observability | Service | `/api/ops/summary`, `mcp_runtime_status.py` | `tools/mcp_runtime_status.py` | Polling/dashboard. Agent does not decide to health-check. |
| Realtime sync (WebSocket, SSE) | Service | App-level transport | `web/` | Continuous push, not discrete tool calls. |

---

## How to add a new capability

1. Ask: "Does an agent need to *choose* to invoke this?" If yes -> MCP tool.
2. Ask: "Is this high-frequency, mechanical, or transport-level?" If yes -> service.
3. If both apply (e.g., an agent triggers a build *and* the result streams back), split: MCP tool for the trigger, service for the stream.

## Current MCP servers (reference)

From `mcp.json`:

| Server | Transport | Status |
|---|---|---|
| `kicad` | stdio (local) | ready |
| `validate-specs` | stdio (local) | ready |
| `knowledge-base` | stdio (local) | ready |
| `github-dispatch` | stdio (local) | ready |
| `freecad` | stdio (local) | ready |
| `openscad` | stdio (local) | ready |
| `huggingface` | HTTP (remote) | ready |

Auxiliary micro-servers (via `kicad_kic_ai`): `component_database`, `kicad_tools`, `nexar_api`.
