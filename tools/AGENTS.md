<!-- Parent: ../AGENTS.md -->
# tools/ AGENTS

## Purpose
MCP servers (10+), validators, CI runtime orchestration, CAD Docker stack, compliance gates.

## Directory Structure
```
tools/
  __init__.py
  validate_specs.py              # RFC2119 + schema validation
  ci_runtime.py                  # Orchestrates 21 GitHub workflows
  scope_guard.py                 # Anti-injection, label enforcement
  cockpit/
    cockpit.py                   # TUI: gate_s0, fw, lots-status, lots-run
    aperant_bridge.sh            # Autonomous agent framework gateway
  hw/
    run_kicad_mcp.sh             # KiCad MCP launcher
    hw_check.sh                  # DRC/ERC validation wrapper
    cad_stack.sh                 # Docker Compose for CAD tools
  compliance/
    validate.py                  # EMC, LVD, SBOM checks
    check_emc_radio_lvd.py       # Radio EMC + voltage safety
    generate_sbom_badge.py       # Dependency audit badge
    scan_rfc2119.py              # RFC2119 keyword scanner
  ai/
    [MCP server implementations]
  aperant/
    [Autonomous agent framework]
```

## MCP Servers (mcp.json Registry)
| Server | Location | Tools | Smoke Test |
|--------|----------|-------|------------|
| kicad | hw/run_kicad_mcp.sh | open, export, drc, erc | test_freecad_mcp.py (contracts) |
| freecad | run_freecad_mcp.sh | open, export, simulate | test_freecad_mcp.py |
| openscad | run_openscad_mcp.sh | render, export | test_openscad_mcp.py |
| ngspice | run_ngspice_mcp.sh | simulate, netlist | (simulation contracts) |
| platformio | run_platformio_mcp.sh | build, test, upload | test_mcp_runtime_status.py |
| validate-specs | run_validate_specs_mcp.sh | check-rfc2119, validate-schema | test_validate_specs.py |
| knowledge-base | run_knowledge_base_mcp.sh | search, retrieve | test_knowledge_base_mcp.py |
| github-dispatch | run_github_dispatch_mcp.sh | trigger-workflow, status | test_github_dispatch_mcp.py |

## CI Runtime
```python
# ci_runtime.py orchestrates:
- Build firmware (pio run)
- Run tests (pytest, pio test -e native)
- Validate specs (python tools/validate_specs.py)
- Check compliance (python tools/compliance/validate.py --strict)
- Export CAD (KiBot .kibot.yaml)
- Update evidence packs (docs/evidence/)
```

Triggered by:
- GitHub Actions (push to main, PR opened)
- Manual: `make lots-run` (via cockpit TUI)

## Scope Guard
**gate_scope.sh** enforces PR label → directory mapping:
- `ai:spec` → allow: specs/, docs/, README.md
- `ai:impl` → allow: firmware/, hardware/, tools/ (limited)
- `ai:qa` → allow: test/, docs/evidence/
- `ai:docs` → allow: docs/

Blocks:
- `.github/workflows/` (requires explicit human approval)
- Secrets in commits
- RFC2119 ambiguities without acceptance criteria

## Compliance Suite
```bash
python tools/compliance/validate.py --strict
```

Checks:
- EMC radio silence (spectrum masks, radiated emissions limits)
- LVD safety (voltage isolation, circuit protection)
- SBOM generation (dependencies, licenses)
- RFC2119 coverage (all specs have testable criteria)

## CAD Docker Stack
```bash
make cad-up                                 # Start KiCad, FreeCAD, OpenSCAD, ngspice
make cad-down                               # Stop
make cad-ps                                 # Status
make cad-kicad CAD_ARGS='version'           # kicad-cli command
make cad-freecad CAD_ARGS='-c "..."'        # FreeCAD script
```

Stack (docker-compose.yml):
- KiCad 8.x headless
- FreeCAD 1.0+ with Python API
- OpenSCAD
- ngspice 42+
- PlatformIO CLI

## Agent Workflows

### QA Agent (compliance)
1. After spec finalization: `python tools/validate_specs.py` ✓
2. Before firmware PR: `python tools/compliance/validate.py --strict` ✓
3. Generate evidence: `make cad-up && make cad-kicad CAD_ARGS='...'`
4. Archive to docs/evidence/

### Architect (scope + contracts)
1. Validate all MCP servers: `make cad-ps`
2. Test each MCP smoke test: `pytest test/test_*_mcp.py`
3. Enforce scope: `python tools/scope_guard.py --check-pr`

## See Also
- ../CLAUDE.md for full command reference
- mcp.json for server registry
- test/ for MCP contract validation
- docker-compose.yml for CAD stack compose
