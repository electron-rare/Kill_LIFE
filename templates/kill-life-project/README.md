# {{PROJECT_NAME}}

> Managed by [Kill_LIFE](https://github.com/electron-rare/Kill_LIFE) agents.

## Structure

```
hardware/
  pcb/          KiCad schematics and PCB layouts
  simulation/   SPICE simulation files
  bom/          Bill of Materials (CSV/JSON)
firmware/
  src/           PlatformIO firmware source
docs/
  reviews/       Auto-generated design reviews
  specs/         Project specifications
  client/        Client-facing documentation
fabrication/     Gerber and manufacturer files
```

## Quick Start

```bash
make help            # list available targets
make erc             # run electrical rules check
make drc             # run design rules check
make review          # full design review
make bom-export      # export BOM from KiCad
make fabrication-prep # generate Gerbers
make firmware-build  # build firmware
```

## Kill_LIFE Integration

This project is connected to the Kill_LIFE orchestrator via `.kill-life.yaml`.
Agents (`forge`, `firmware-agent`, `qa-agent`) operate on this repo through MCP servers.
