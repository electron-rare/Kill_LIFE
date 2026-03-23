# Plan 23 - YiACAD Git EDA platform

## Goal

Turn YiACAD into a Git-native web EDA platform with a credible path from viewer and CI to review, collaboration, and eventual browser editing.

## Workstreams

### WS1 - Git core

- self-hosted repo integration
- project-per-repo model
- tenant and namespace boundaries

### WS2 - EDA engine

- queue contract
- worker contract
- KiCad CLI, KiBot, KiAuto runner envelope

### WS3 - Product web

- dashboard
- diagram editor
- PCB viewer
- PR review

### WS4 - Realtime

- Yjs room model
- websocket deployment
- comments and presence

### WS5 - Data and parts

- graph metadata
- component indexing
- pricing and sourcing lane

### WS6 - Intelligence overlay

- review hints in read-only mode
- MCP or service-first tool boundaries for CI, artifacts, parts and ops summary
- health bridge from workers and realtime into the intelligence lane

## Immediate scope

- finish MVP surfaces
- keep Git as source of truth
- keep GraphQL small and explicit
- avoid premature browser-side EDA editing
- keep AI assist as overlay, not as source of truth

## 2026-03-22 status

- `web/` dependencies install cleanly and `next build` passes
- KiCanvas is vendored from the official bundle path into `web/public/vendor/kicanvas.js`
- the queue path is now Redis-backed through `BullMQ`
- `web/workers/eda-worker.mjs` is the first real worker entry for `kicad-headless`, `kibot`, `kiauto-checks`, and `step-export`
- project/review state is now derived from a local Git read model instead of static `.ci/pull-requests.json`
- artifacts are now exposed through a dedicated `/api/artifacts/*` route and surfaced as web links in the product
- remaining hard blocker for runtime validation is external infra: a live Redis instance and actual KiCad/KiBot/KiAuto binaries/config
- the open product gap is now the read model: real Git/PR state, live artifact URLs, Yjs scene binding, and an intelligence overlay that stays read-only
