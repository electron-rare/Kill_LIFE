<!-- Parent: ../AGENTS.md -->
# test/ AGENTS

## Purpose
Compliance & contract validation. MCP server contracts, firmware evidence, CI state machine.

## Test Structure
```
test/
  test_*_mcp.py                # MCP server contract tests
  test_firmware_evidence.py     # Firmware CI artifact validation
  test_validate_specs.py        # Spec validation contract
  test_intelligence_tui_contract.py          # Cockpit TUI contract
  test_yiacad_native_surface_contract.py     # CAD integration contract
  test_mcp_runtime_status.py     # MCP registry health check
  test_openclaw_sanitizer.py     # GitHub event anti-injection
  __pycache__/
```

## Key Tests
| Test | Purpose | Scope |
|------|---------|-------|
| test_freecad_mcp.py | FreeCAD MCP server responds to open/export | ai:qa |
| test_kicad_mcp.py | KiCad MCP server DRC/ERC contract | ai:qa |
| test_openscad_mcp.py | OpenSCAD render+export contract | ai:qa |
| test_platformio_mcp.py | PlatformIO build/test/upload tools | ai:qa |
| test_validate_specs.py | Spec RFC2119 scanning + acceptance criteria | ai:qa |
| test_firmware_evidence.py | Firmware CI artifacts timestamped/immutable | ai:qa |
| test_github_dispatch_mcp.py | GitHub Actions workflow triggering | ai:qa |
| test_knowledge_base_mcp.py | Knowledge base search contract | ai:qa |
| test_mcp_runtime_status.py | All MCP servers responsive (smoke test) | ai:qa |

## MCP Contract Pattern
Each MCP server has a corresponding test:
```python
# test_freecad_mcp.py example
def test_freecad_mcp_open():
    """FreeCAD can open .FCStd files via MCP tool."""
    # 1. List MCP tools
    tools = list_mcp_tools("freecad")
    assert "open" in tools
    # 2. Call tool with valid .FCStd
    result = call_mcp_tool("freecad", "open", {"path": "..."})
    assert result.status == "ok"

def test_freecad_mcp_export():
    """FreeCAD exports to STEP, STL."""
    result = call_mcp_tool("freecad", "export", {
        "source": "model.FCStd",
        "format": "step",
        "dest": "/tmp/out.step"
    })
    assert os.path.exists("/tmp/out.step")
```

## Running Tests
```bash
pytest                                 # All tests
pytest test/test_*_mcp.py              # MCP contracts only
pytest test/test_firmware_evidence.py  # Firmware artifacts
pytest test/ -v                        # Verbose
pytest test/ -k "freecad"              # Subset by pattern
```

Pytest invocation from repo root (auto-discovers test/).

## Firmware Evidence
test_firmware_evidence.py validates:
- Build artifacts exist (elf, bin)
- Timestamps present in metadata
- Checksums immutable (HMAC-SHA256)
- CI logs linked to evidence pack

Evidence stored in docs/evidence/:
```
docs/evidence/
  <TIMESTAMP>_firmware_build.md       # Build log + checksums
  <TIMESTAMP>_qemu_boot.log           # QEMU execution trace
  <TIMESTAMP>_erc_drc_report.json      # Hardware validation
```

## Agent Workflows (QA Agent)

### Before Merge
1. Run full test suite: `pytest` ✓
2. Check MCP health: `pytest test/test_mcp_runtime_status.py` ✓
3. Validate scope guard: `python tools/scope_guard.py --check-pr` ✓
4. Archive evidence: `python tools/collect_evidence.py`

### PR Review Checklist
- [ ] All test/test_*.py pass
- [ ] No untrusted input (openclaw sanitizer ✓)
- [ ] ai:qa label present
- [ ] Evidence pack linked in PR description

## CI Integration
- GitHub Actions runs `pytest` on every PR
- Failures block merge (required check)
- Evidence artifacts stored in docs/evidence/
- MCP runtime health monitored continuously (test_mcp_runtime_status.py)

## Scope Guard
- ai:qa label required for test/ changes
- Cannot modify .github/workflows/ (security)
- All PR text sanitized via openclaw_sanitizer.py before processing

## See Also
- ../CLAUDE.md for pytest invocation
- ../tools/compliance/ for compliance validation
- ../tools/scope_guard.py for label enforcement
