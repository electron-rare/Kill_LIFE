# YiACAD KiCad Plugin

KiCad action plugin for the YiACAD desktop lane.

## Scope

- runs YiACAD backend actions from inside KiCad
- keeps product logic in YiACAD, not in the plugin
- acts as the fast-moving KiCad surface for review, BOM audit, sync, and artifact access

## Current model

- transport: `service-first` through `tools/cad/yiacad_backend_client.py`
- actions: registry-backed from `specs/contracts/yiacad_action_registry.json`
- product surface: `yiacad-desktop`
- integrated actions:
  - `kicad-erc-drc`
  - `bom-review`
  - `ecad-mcad-sync`
  - `status`

## Install in local KiCad

From the `Kill_LIFE` repo root:

```bash
bash tools/cad/install_yiacad_native_gui.sh install
```

This links the plugin into:

- `~/Library/Application Support/kicad/scripting/plugins/yiacad_kicad_plugin`

## Notes

- This plugin is the YiACAD working surface used to move quickly on KiCad integration.
- This plugin is independent and remains under YiACAD control as the canonical KiCad integration surface.
- Context discovery prefers explicit KiCad runtime hints when available and falls back to project path inference otherwise.
