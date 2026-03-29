# YiACAD KiCad Plugin

KiCad action plugin for the YiACAD desktop lane.

## Scope

- runs YiACAD backend actions from inside KiCad
- keeps product logic in YiACAD, not in the plugin
- acts as the fast-moving KiCad surface for review, BOM audit, sync, and artifact access

## Current model

- transport: `service-first` through `tools/cad/yiacad_backend_client.py`
- product surface: `yiacad-desktop`
- integrated actions:
  - `board-review`
  - `erc-drc-assist`
  - `bom-footprint-audit`
  - `ecad-mcad-sync`

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
