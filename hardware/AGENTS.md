<!-- Parent: ../AGENTS.md -->
# hardware/ AGENTS

## Purpose
KiCad schematics, PCB layouts, modular blocks, BOM generation, EMC/LVD compliance.

## Directory Structure
```
hardware/
  README.md                 # Overview + block registry
  REGISTRY.md              # Canonical list of blocks, interconnections
  blocks/
    i2s_dac/
      gen_i2s_dac.py      # Procedural schematic generator
      i2s_dac.kicad_sch   # Generated schematic
      i2s_dac.kicad_pro   # Project file
    power_usbc_ldo/       # USB-C power + LDO regulator
      gen_power_usbc_ldo.py
      power_usbc_ldo.kicad_sch
    uart_header/          # Debug serial (3.3V)
      gen_uart_header.py
      uart_header.kicad_sch
    spi_header/           # SPI connector (generic)
      gen_spi_header.py
      spi_header.kicad_sch
  esp32_minimal/           # Main schematic assembling blocks
    esp32_minimal.kicad_sch
  rules/                    # Design rule sets (.pretty, fp-lib-table)
  .kibot.yaml              # CI/CD export rules (PNG, PDF, BOM, Gerber)
  fp-lib-table             # Footprint library table
  sym-lib-table            # Symbol library table
```

## Key Files
| File | Purpose |
|------|---------|
| REGISTRY.md | Source of truth: blocks, versions, pin assignments, constraints |
| blocks/*/gen_*.py | Procedural generators (creates .kicad_sch from params) |
| esp32_minimal.kicad_sch | Main schematic (imports blocks via hierarchy) |
| .kibot.yaml | KiBot export pipeline (BOM, Gerber, PDF) |

## Design Rules
- Modular blocks: each block is self-contained, tested independently
- Hierarchy: esp32_minimal.kicad_sch imports blocks as sheets
- Generators: gen_*.py scripts are idempotent (re-run anytime)
- Symbol/Footprint libraries in rules/

## Validation
```bash
make hw SCHEM=hardware/esp32_minimal/esp32_minimal.kicad_sch
```

Checks:
- ERC (Electrical Rule Check): no floating nets, no short circuits
- DRC (Design Rule Check): trace width, clearance, via sizes
- BOM: all parts have LCSC/MPN references
- Gerber: valid for manufacturing

## Agent Workflow (HW Schematic Agent)
1. Read spec → specs/constraints.yaml (voltage rails, current budgets)
2. Update REGISTRY.md with new block definition
3. Generate block: `python blocks/*/gen_*.py`
4. Integrate into esp32_minimal.kicad_sch (KiCad GUI)
5. Validate: `make hw SCHEM=...`
6. Export (KiBot): PNG, PDF, Gerber, BOM
7. Evidence: schematic snapshot + ERC/DRC report to docs/evidence/

## CI Integration
- kicad_mcp.py: ["open", "export", "drc", "erc"] tools for agents
- .kibot.yaml: automated export on each push
- Scope guard: ai:impl label required for hardware/ PRs

## Compliance
- EMC: trace routing, layer stackup (see rules/)
- LVD: voltage ratings, clearances per constraints.yaml
- BOM: manufacturer links, ROHS certification

## See Also
- REGISTRY.md for modular block catalog
- ../CLAUDE.md for hardware build commands
- ../tools/compliance/ for EMC/LVD validation
