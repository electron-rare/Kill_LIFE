# YiACAD Git EDA platform - 2026-03-22

## Scope

Translate the Git-first SaaS architecture into an actual repo slice that can grow incrementally:

- `web/` for the product surface
- GraphQL as the HTTP aggregation boundary
- a separate Yjs websocket lane for collaboration
- Git-tracked `.excalidraw` files inside the project tree

## Implemented scaffold

- `web/app/` now exposes four surfaces:
  - `/`
  - `/diagram`
  - `/pcb`
  - `/review`
- `web/app/api/graphql/route.ts` is the API gateway entry
- `web/app/api/project-files/[...segments]/route.ts` serves Git-backed project files to browser viewers
- `web/lib/project-store.ts` is the local project service and diagram service seed
- `web/realtime/server.mjs` starts the dedicated Yjs websocket server with persistence

## Stored project shape

```text
web/project/
├── diagrams/
│   ├── system.excalidraw
│   └── power.excalidraw
├── pcb/
│   └── README.md
└── .ci/
    ├── queue.json
    ├── artifacts.json
    └── pull-requests.json
```

## Why this shape

- `.excalidraw` remains plain JSON, so Git diff and PR review stay cheap
- KiCad files remain canonical and are only projected into API/view models
- CI outputs and review state have their own lane under `.ci/` instead of mutating source files

## Product surface map

### Dashboard

- project files
- PR list
- CI runs
- artifact counts

### Diagram editor

- Excalidraw canvas
- Git-backed save
- local queue trigger for KiBot and KiCad headless

### PCB viewer

- KiCanvas lane
- artifact summary

### PR review

- KiCad diff placeholder
- Excalidraw diff placeholder
- artifact preview readiness

## Next hard problems

- bind Excalidraw scene state into Yjs without creating a second source of truth
- add a real queue backend instead of a local JSON queue stub
- add a real worker/orchestrator contract for KiCad CLI, KiBot, KiAuto, Gerber, STEP, BOM, PDF
- replace placeholder PR/artifact JSON with outputs derived from real Git and CI state
