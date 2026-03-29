# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kill_LIFE is an AI-native embedded systems control plane combining spec-first governance, multi-agent orchestration (BMAD method), hardware/firmware CI/CD, and YiACAD — an AI-native CAD/EDA web platform. The repo is the public control plane; sister repos `kill-life-mesh` (orchestration) and `kill-life-operator` (execution) complete the tri-repo mesh.

**Stack**: Python 3.12+ (FastAPI, Pydantic), PlatformIO (ESP32/STM32), KiCad 10, Next.js 14, Excalidraw, Yjs CRDT.

## Build & Test Commands

```bash
# Python environment
bash tools/bootstrap_python_env.sh

# Tests (stable = no external deps, mcp = MCP integration, all = everything)
bash tools/test_python.sh --suite stable
bash tools/test_python.sh --suite all
bash tools/test_python.sh --list          # list available tests

# Single test file
python3 -m pytest test/test_specific_file.py -v

# Lint
ruff check .

# Coverage
make coverage

# Firmware
cd firmware && pio run -e esp32s3_waveshare   # build
cd firmware && pio test -e native              # unit tests

# Hardware ERC
make hw SCHEM=hardware/esp32_minimal/esp32_minimal.kicad_sch

# CAD stack (Docker)
make cad-up                              # start container
make cad-kicad CAD_ARGS='version'        # KiCad CLI
make cad-freecad CAD_ARGS='-c "..."'     # FreeCAD

# Specs & compliance
python3 tools/validate_specs.py --strict
make compliance
make docs                                # MkDocs build
```

## Architecture

### Spec-First Pipeline (source of truth)
All work flows through `specs/`:
```
00_intake.md → 01_spec.md → 02_arch.md → 03_plan.md → 04_tasks.md
```
Runtime contracts live in `specs/contracts/*.schema.json`. The mirror at `ai-agentic-embedded-base/specs/` is synced via `bash tools/specs/sync_spec_mirror.sh all --yes`.

### BMAD Agents (`agents/`)
Six role-based agents (pm, architect, firmware, hw_schematic, qa, doc) defined as markdown. The FastAPI server (`kill_life/server.py`) bridges agents to the mascarade-core LLM router. Agents are triggered by `ai:*` labels on GitHub issues.

### Cockpit TUI (`tools/cockpit/`)
~66 shell scripts providing operator dashboards. Three canonical entry points:
- `yiacad_operator_index.sh` — public operator dashboard
- `intelligence_tui.sh` — agentic governance & memory
- `runtime_ai_gateway.sh` — consolidated runtime/MCP health

All output `cockpit-v1` JSON to `artifacts/cockpit/`.

### YiACAD (`tools/cad/` + `web/`)
AI-native CAD platform with four layers:
1. Native KiCad plugin + FreeCAD workbench (GUI)
2. Service-first backend (`yiacad_backend.py`, `yiacad_backend_service.py`)
3. Web EDA (`web/`) — Next.js + Excalidraw + KiCanvas + Yjs realtime + BullMQ workers
4. Intelligence overlay (read-only review hints via MCP)

### Firmware (`firmware/`)
PlatformIO project targeting ESP32-S3 Waveshare. Unity for native tests. Wokwi for CI simulation (requires `WOKWI_CLI_TOKEN`).

### Hardware (`hardware/`)
KiCad 10 schematics. KiBot for exports (BOM, SVG, PDF, netlist). ERC validation in CI.

## Key Conventions

- **Language**: Specs and docs are primarily in French; code and comments in English.
- **Python**: Target 3.12+, ruff for linting, line length 120.
- **Lot contract fields**: Every lot must expose `owner_repo`, `owner_agent`, `write_set`, `status`, `evidence`.
- **Label discipline**: Issues require `prio:*`, `risk:*`, `scope:*`, `type:*`. Automation via `ai:*` labels; `ai:hold` blocks automation.
- **Evidence**: Proof artifacts go to `artifacts/` and `docs/evidence/`.

## CI/CD (`.github/workflows/`)

- `ci.yml` — main CI: Python tests, firmware build, hardware ERC
- `release.yml` — tag-triggered release (validates `VERSION` file matches tag)
- `evidence_pack.yml` — evidence artifact generation
- `mesh_contracts.yml` — tri-repo contract validation
- `kicad-exports.yml` — hardware SVG/PDF/BOM/netlist exports

## External Services

- **Mascarade** (`MASCARADE_CORE_URL`, default `http://192.168.0.119:8100`) — LLM router with agentic RAG
- **MCP servers** (10 configured in `mcp.json`) — kicad, freecad, openscad, platformio, github-dispatch, knowledge-base, validate-specs, apify, huggingface, mascarade-bridge
- **n8n** — workflow automation (ZeroClaw integration)
