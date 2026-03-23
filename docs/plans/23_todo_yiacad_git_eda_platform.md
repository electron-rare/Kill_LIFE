# Todo 23 - YiACAD Git EDA platform

- [x] Create `web/` scaffold for Next.js + GraphQL + Yjs transport
- [x] Store `.excalidraw` diagrams as Git-tracked JSON under `web/project/diagrams`
- [x] Expose product routes for dashboard, diagram editor, PCB viewer, and PR review
- [x] Add local GraphQL gateway with project, diagram, CI, artifact, and PR review data
- [x] Add dedicated realtime server launcher for Yjs websocket transport
- [x] Install `web/` dependencies and produce a successful first `next build`
- [x] Vendor the official KiCanvas bundle into `web/public/vendor/kicanvas.js`
- [x] Replace the JSON queue stub with a Redis-backed queue contract via `BullMQ`
- [x] Add a real EDA worker entry wired to KiCad headless, STEP export, KiBot fallback, and KiAuto hooks
- [x] Fold `plan 23` into the intelligence lane and assign dedicated owners for `web/*`, realtime, and workers
- [ ] Bind Excalidraw scene updates into Yjs room state
- [x] Replace PR/artifact placeholder JSON with real Git and CI derived state
- [ ] Surface worker, queue, and realtime health into the intelligence memory and runtime gateway
- [ ] Add a first read-only review-assist surface backed by changed files, ERC/DRC outputs, and ops summary
