# Spec - YiACAD 2026 stack target

## Intent

Fix the 2026 source-of-truth stack for YiACAD so product, backend, desktop, web, QA, and CI/CD all target the same engine baseline and the same integration boundaries.

## Baseline date

- Canonical baseline fixed on `2026-03-29`.

## Product rules

- `YiACAD` is the product shell and the product boundary.
- `KiCad`, `FreeCAD`, `KiBot`, `KiAuto`, and CAD runtimes are integrated engines inside YiACAD.
- `desktop` is the canonical authoring surface.
- `web` is the canonical review, collaboration, artifact, and orchestration surface.
- `AI` belongs above the YiACAD backend and project graph, not inside ad hoc GUI automation.
- `MCP` is an adapter boundary, not the product core.

## Version floor

| Layer | Canonical target | Why it is selected | Boundary |
| --- | --- | --- | --- |
| ECAD authoring | `KiCad 10.0.x` | modern IPC API, `kicad-python`, `kicad-cli`, active 2026 baseline | integrated desktop engine |
| MCAD authoring | `FreeCAD 1.1.x` | stable post-1.0 base, native Assembly/CAM trajectory, mature Python surface | integrated desktop engine |
| Manufacturing automation | `KiBot` latest stable supported by pinned runner image | deterministic outputs and bundle generation | Linux/Docker worker lane |
| Validation automation | `KiAuto` latest stable supported by pinned runner image | ERC/DRC and replay automation where headless GUI automation is still needed | Linux/Docker worker lane |
| Web viewer | `KiCanvas` current read-only embedding line | useful for review, not canonical editing | web review surface only |
| Collaboration | `Yjs` + `y-websocket` | mature CRDT collaboration transport | web collaboration surface |
| Product orchestration | YiACAD backend service-first boundary | normalized outputs, evidence, engine isolation | shared product boundary |

## Stack shape

### 1. Desktop authoring lane

- `KiCad 10.0.x` for schematic, PCB, rules, exports, and design review entrypoints.
- `FreeCAD 1.1.x` for MCAD inspection, sync, enclosure/fixture work, and downstream model exports.
- YiACAD desktop shell drives both engines through backend actions and engine adapters.

### 2. Backend and AI lane

- YiACAD backend remains the only product orchestration boundary.
- AI agents consume normalized `context.json`, `uiux_output.json`, project metadata, and artifact indexes.
- AI suggestions must stay traceable, reversible, and artifact-backed.

### 3. Manufacturing lane

- `KiBot` runs in Linux/Docker workers for reproducible bundles.
- `KiAuto` runs in Linux/Docker workers for replay, ERC/DRC automation, and regression gates.
- macOS desktop machines are not the canonical place to validate manufacturing automation.

### 4. Web lane

- `KiCanvas` is viewer/review only.
- `Next.js` client renders status, review, artifacts, comments, approvals, and project context.
- `Yjs` + `y-websocket` handle collaborative review state.
- Browser-side CAD editing is not part of the 2026 source-of-truth baseline.

## Approved integration boundaries

### KiCad

- `IPC API` for live integration.
- `kicad-python` for typed client access.
- `kicad-cli` for deterministic batch work.
- `Plugin and Content Manager` only for packaging/distribution of the YiACAD KiCad extension, not for product logic ownership.

### FreeCAD

- Python API and workbench integration for UI and model automation.
- Addon packaging for distribution and update flow when needed.
- FreeCAD remains an integrated engine, not the YiACAD shell.

### Automation

- `KiBot` and `KiAuto` stay behind YiACAD backend actions.
- direct worker invocations from product clients are disallowed.

## Explicit non-goals

- full browser-first ECAD or MCAD editing as 2026 core
- product architecture based on KiCad/FreeCAD forks
- dependence on deprecated KiCad SWIG bindings
- AI strategy based primarily on screen scraping or GUI event playback
- making third-party AI plugins the product source of truth

## Known maturity notes

- `KiCanvas` remains valuable for review, but it is still not a canonical authoring surface.
- `KiAuto` remains Linux-oriented in practice and is best treated as a CI worker capability.
- third-party AI plugins in KiCad and FreeCAD remain useful probes, not the core YiACAD architecture.
- package rollout lag can exist across platforms even after an upstream release announcement; version pinning must be explicit in bootstrap and CI.

## Acceptance criteria

- all YiACAD specs reference `KiCad >= 10.0` and `FreeCAD >= 1.1` as the 2026 floor
- desktop and web documents agree on `desktop-first authoring` and `web-first review`
- CI/CD documents route `KiBot` and `KiAuto` into Linux/Docker lanes
- backend and UX specs agree that YiACAD, not KiCad or FreeCAD, owns the product boundary

## External references

- KiCad `10.0.0` release, `2026-03-20`: <https://www.kicad.org/blog/2026/03/Version-10.0.0-Released/>
- KiCad developer APIs and bindings: <https://dev-docs.kicad.org/en/apis-and-binding/>
- KiCad `kicad-python` docs: <https://docs.kicad.org/kicad-python-main/>
- KiCad `10.0` reference manual: <https://docs.kicad.org/master/en/kicad/kicad.html>
- FreeCAD `1.1` release, `2026-03-25`: <https://blog.freecad.org/2026/03/25/freecad-version-1-1-released/>
- FreeCAD `1.0` release, `2024-11-19`: <https://blog.freecad.org/2024/11/19/freecad-version-1-0-released/>
- FreeCAD upstream repo: <https://github.com/FreeCAD/FreeCAD>
- FreeCAD Addon Manager: <https://github.com/FreeCAD/AddonManager>
- KiBot install docs: <https://kibot.readthedocs.io/en/latest/installation.html>
- KiAuto upstream: <https://github.com/INTI-CMNB/KiAuto>
- KiCanvas home: <https://kicanvas.org/home/>
- Yjs `y-websocket` docs: <https://docs.yjs.dev/ecosystem/connection-provider/y-websocket>
