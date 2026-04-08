<!-- Parent: ../AGENTS.md -->
# web/ AGENTS

## Purpose
Next.js 14 operator cockpit (Aperant). Real-time multi-agent collaboration UI with Yjs CRDT, WebSocket sync, Excalidraw canvas.

## Directory Structure
```
web/
  README.md                     # Setup + dev guide
  package.json                  # Next.js 14, React 18, dependencies
  app/                          # Next.js App Router
    layout.tsx                  # Root layout
    page.tsx                    # Dashboard
    api/
      [routes]                  # API endpoints (BullMQ, WebSocket)
  components/
    pcb-workbench/              # PCB editing + DRC realtime
      PCBWorkbench.tsx
      useSchematicSync.ts       # Yjs awareness for multi-agent edit
    excalidraw-canvas/          # Diagram tool integration
      ExcalidrawCanvas.tsx
    realtime-status/            # Live agent status + logs
      RealtimeStatus.tsx
      useAgentSync.ts
  lib/
    yjs-provider.ts             # Yjs WebSocket provider
    types.ts                    # TypeScript contracts
  realtime/
    server.mjs                  # WebSocket server (Yjs awareness)
    namespace.mjs               # Socket.io rooms for agents
  workers/
    eda-worker.mjs              # Worker: KiCad export, DRC
    simulation-worker.mjs       # Worker: ngspice circuit sim
  public/
    (static assets)
  tsconfig.json                 # strict mode
  next.config.mjs               # Build config
```

## Key Files
| File | Purpose |
|------|---------|
| app/layout.tsx | Root layout, Yjs provider injection |
| app/page.tsx | Dashboard: agent status, log stream, controls |
| components/pcb-workbench/ | Real-time schematic editing (multi-user) |
| components/excalidraw-canvas/ | Freeform diagram + architecture sketches |
| realtime/server.mjs | WebSocket server, Yjs awareness, message sync |
| workers/eda-worker.mjs | Headless EDA: KiCad DRC, export, netlist |
| package.json | React 18, Next.js 14, Yjs, Excalidraw, BullMQ client |

## Tech Stack
- **Frontend:** React 18, TypeScript, TailwindCSS (strict mode)
- **Realtime:** Yjs (CRDT), Socket.io (awareness), BullMQ client (task status)
- **Backend:** Node.js WebSocket server (realtime/server.mjs)
- **Workers:** EDA worker (KiCad CLI), simulation worker (ngspice)

## Realtime Architecture
```
Aperant Agents          Browser UI (React)
         |                    |
         +<-- WebSocket ----->+
             (Yjs awareness)
             - Schematic edits synced
             - Agent status updates
             - Log stream broadcast
```

## Development
```bash
cd web && npm install
npm run dev                     # Next.js dev server (:3000)
npm run dev:realtime            # Start WebSocket server (:9621)
npm run build && npm start      # Production
npm run test                    # Jest + Playwright
```

## Components

### PCBWorkbench
Collaborative schematic editing:
- Reads schematic from KiCad (JSON export)
- Yjs syncs edits across agents
- Real-time DRC via eda-worker
- WebSocket pushes updates to kicad_mcp.py

### ExcalidrawCanvas
Architecture diagram editor:
- Excalidraw embedded canvas
- Auto-saves to git (docs/diagrams/)
- Agents can sketched block diagrams
- Link to hardware/REGISTRY.md

### RealtimeStatus
Live agent dashboard:
- BullMQ task queue (red/green status)
- Log stream from ci_runtime.py
- Agent role badges (PM, Architect, FW, HW, QA, Doc)
- Evidence pack links

## Agent Workflow (Doc Agent)
1. Start web server: `make aperant-web-dev`
2. Open browser: http://localhost:3000
3. View live agent status + logs
4. Edit architecture diagram (ExcalidrawCanvas)
5. Export to docs/diagrams/ + docs/evidence/

## CI Integration
- GitHub Actions: `npm run build` (verifies TS + next lint)
- Deployment: Node.js server with systemd (production)
- Realtime API: `/api/agents`, `/api/logs`, `/ws` (WebSocket)

## Scope Guard
- ai:docs label for web/ PRs
- No secrets in .env (use GitHub Secrets)
- WebSocket authentication via JWT (see realtime/server.mjs)

## See Also
- ../CLAUDE.md for build/test commands
- ../tools/cockpit/aperant_bridge.sh for deployment
- Makefile: `make aperant-web-dev`, `make aperant-build`
