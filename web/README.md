# YiACAD Web

This directory hosts the web-facing YiACAD scaffold:

- `app/` provides the Next.js frontend and GraphQL route handler.
- `components/` holds the Excalidraw canvas, KiCanvas viewer shell, project tree, and realtime status cards.
- `project/` is the Git-tracked source-of-truth for `.excalidraw` diagrams and local KiCad inputs.
- `realtime/server.mjs` launches the separate Yjs websocket server with persistence.

Product routes:

- `/` project dashboard
- `/diagram` Excalidraw editor
- `/pcb` KiCanvas viewer lane
- `/review` PR review surface

Key commands:

- `npm install`
- `npm run dev`
- `npm run dev:realtime`
- `npm run worker:eda`
- `npm run vendor:kicanvas`

The current realtime layer exposes a Yjs room and transport status.
Binding Excalidraw scene data into the CRDT document is intentionally left as the next incremental lot.

AI / intelligence overlay:

- keep Git as the source of truth
- keep Yjs as collaboration transport only
- keep workers as the execution boundary
- introduce review assist only as a read-only overlay once Git/CI/artifact read models are real

Queue and workers:

- GraphQL enqueues EDA jobs through Redis-backed `BullMQ`
- `npm run worker:eda` consumes the queue and calls existing repo tools
- `kicad-headless` uses `tools/cad/yiacad_native_ops.py`
- `kibot` prefers a real `kibot` binary when configured, then falls back to `tools/cockpit/fab_package_tui.sh`
- `kiauto-checks` is wired as a real queue pipeline and requires `KIAUTO_BIN`

Environment:

- copy values from `.env.example`
- `REDIS_URL` is required for the queue/worker path
- `KIBOT_CONFIG` is optional until a real KiBot recipe is added to the project
