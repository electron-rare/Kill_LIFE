# Kill_LIFE Project Template

## Overview

The Kill_LIFE project template provides a standard directory structure for hardware/firmware client projects. It sets up the directories, CI workflows, and configuration that Kill_LIFE agents need to operate on a repo.

## Template Location

```
templates/kill-life-project/
```

## Directory Structure

```
.kill-life.yaml                     # Links project to Kill_LIFE orchestrator
hardware/
  pcb/                              # KiCad projects (.kicad_pro, .kicad_sch, .kicad_pcb)
  simulation/                       # LTspice/ngspice simulation files
  bom/                              # Normalized BOMs (CSV/JSON)
firmware/
  src/                              # ESP32/STM32 source code
  platformio.ini                    # PlatformIO build config
docs/
  reviews/                          # Auto-generated Forge design reviews
  specs/                            # Project specifications and requirements
  client/                           # Client-facing documentation
fabrication/                        # Gerbers, drill files, JLCPCB archives
.github/workflows/kill-life-ci.yml  # CI: ERC/DRC, BOM check, firmware build
Makefile                            # Common targets
```

## Usage

### Initialize a new or existing repo

```bash
./tools/project_init.sh <github_repo_url> <project_name> [client_name]
```

Example for the Hypnoled project:

```bash
./tools/project_init.sh git@github.com:electron-rare/hypnoled.git hypnoled "Hypnoled SAS"
```

This will:
1. Clone the repo to `/tmp/kill-life-init/hypnoled/`
2. Create the standard directory structure
3. Copy template files (skips files that already exist)
4. Generate `.kill-life.yaml` with the project and client names filled in
5. Commit the changes

You can override the working directory with `KILL_LIFE_WORK_DIR`:

```bash
KILL_LIFE_WORK_DIR=~/projects ./tools/project_init.sh ...
```

### After initialization

Push the changes and verify CI runs:

```bash
cd /tmp/kill-life-init/hypnoled
git push
```

### Migrating existing projects (e.g. Hypnoled)

For repos that already have content in a flat structure (like `DALI PCB/`):

1. Run the init script to add the template structure
2. Move existing KiCad files into `hardware/pcb/`
3. Move existing scripts/firmware into `firmware/src/`
4. Update the Makefile if the project has custom targets
5. Commit and push

Example migration for Hypnoled:

```bash
cd /tmp/kill-life-init/hypnoled
mv "DALI PCB"/*.kicad_* hardware/pcb/
mv scripts/* firmware/src/ 2>/dev/null || true
git add -A && git commit -m "refactor: migrate to Kill_LIFE project structure"
git push
```

## .kill-life.yaml Reference

| Field | Description |
|---|---|
| `kill_life.version` | Config format version (currently `1`) |
| `kill_life.project` | Project short name |
| `kill_life.client` | Client or organization name |
| `kill_life.mascarade_url` | Mascarade LLM gateway URL |
| `kill_life.agents` | List of Kill_LIFE agents enabled for this project |
| `kill_life.mcp_servers` | MCP servers the agents can use |
| `kill_life.hardware.*` | Paths to hardware directories |
| `kill_life.firmware.*` | Firmware framework and source path |

## Makefile Targets

| Target | Description |
|---|---|
| `make help` | List all available targets |
| `make erc` | Run KiCad Electrical Rules Check |
| `make drc` | Run KiCad Design Rules Check |
| `make review` | Full design review (ERC + DRC) |
| `make bom-export` | Export BOM from KiCad schematic |
| `make bom-check` | Validate BOM completeness |
| `make fabrication-prep` | Generate Gerbers and JLCPCB files |
| `make firmware-build` | Build firmware with PlatformIO |
| `make firmware-flash` | Flash firmware to connected board |
| `make clean` | Remove build artifacts |

## CI Workflow

The included GitHub Actions workflow (`.github/workflows/kill-life-ci.yml`) runs on push/PR to `main`:

1. **ERC/DRC** — Runs KiCad ERC and DRC on all schematics/PCBs using the `kicad8_auto` container
2. **BOM Check** — Validates that a BOM file exists
3. **Firmware Build** — Builds firmware with PlatformIO (only if `platformio.ini` exists)
