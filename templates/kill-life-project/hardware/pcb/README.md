# PCB — KiCad Projects

Place KiCad project directories here (`.kicad_pro`, `.kicad_sch`, `.kicad_pcb`).

## Conventions

- One subdirectory per board variant (e.g. `main_board/`, `power_board/`)
- Keep library symbols/footprints in a `libs/` subdirectory if project-specific
- The Kill_LIFE `kicad` MCP server runs ERC/DRC checks against files in this directory

## Agent Integration

The `forge` agent generates design reviews from schematics found here.
The `qa-agent` runs ERC/DRC via the kicad MCP and reports results to `docs/reviews/`.
