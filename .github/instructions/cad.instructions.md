---
description: "Use when working on YiACAD CAD lanes, KiCad/FreeCAD integrations, backend CAD actions, manufacturing exports, or CAD MCP/runtime scripts."
name: "CAD Domain"
applyTo: ["tools/cad/**", "tools/hw/**", "hardware/**", "specs/yiacad*", "specs/contracts/yiacad*"]
---
# CAD Domain Instructions

## Product Boundary

- Treat YiACAD as product shell.
- Treat KiCad/FreeCAD/KiBot/KiAuto as integrated engines behind backend actions.

## Preferred Paths

- Service-first: `tools/cad/yiacad_backend_service.py` and `tools/cad/yiacad_backend_client.py`.
- Keep outputs normalized through `context.json` and `uiux_output.json`.

## Verify With

- `python3 tools/cad/yiacad_backend_client.py --json-output status`
- `python3 tools/cad/yiacad_native_ops.py status --json-output`
- `python3 tools/validate_specs.py --strict`

## Guardrails

- Do not bypass backend boundary from UI/plugin/worker flows.
- Keep `engine_status` and `degraded_reasons` coherent across contracts and examples.
