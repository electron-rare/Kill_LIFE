<!-- Parent: ../AGENTS.md -->
# specs/ AGENTS

## Purpose
Source of truth for all requirements. Spec-first, machine-readable, RFC2119-compliant contracts.

## Directory Structure
```
specs/
  00_intake.md              # Raw requirements, use cases, constraints
  01_spec.md               # RFC2119 spec with acceptance criteria
  02_arch.md               # Architecture, interfaces, data models
  03_plan.md               # Roadmap, phases, dependencies
  04_tasks.md              # Actionable tasks tied to specs
  README.md                # Overview and navigation
  constraints.yaml         # Hardware/power/timing/EMC constraints
  contracts/               # 19+ machine-readable JSON schemas
    *.schema.json
```

## Key Files
| File | Owner | Validation |
|------|-------|-----------|
| 00_intake.md | PM | Anti-ambiguity: define all terms |
| 01_spec.md | Architect | RFC2119 + acceptance criteria + NFRs (power, latency, memory) |
| 02_arch.md | Architect | Block diagrams, interfaces, test strategy |
| 03_plan.md | PM | Phases, milestones, resource allocation |
| 04_tasks.md | PM | Sprints, story points, blockers |
| constraints.yaml | Architect | Voltage rails, current budgets, thermal, EMC targets |
| contracts/*.schema.json | QA | JSON Schema for API/HW contracts |

## Validation
```bash
python tools/validate_specs.py           # Runs all checks
python tools/validate_specs.py --rfc2119 # RFC2119 only
python tools/validate_specs.py --schema  # JSON schema validation
```

Validation checks:
- RFC2119 keywords (MUST/SHOULD/MAY) present in 01_spec.md
- All acceptance criteria testable (no vague language)
- contracts/ schemas are valid JSON Schema
- 00_intake terms defined in glossary
- Architecture diagrams (Mermaid/ASCII) render

## Agent Workflows

### PM (intake + plan)
1. Read user request → 00_intake.md (raw capture)
2. Extract constraints → constraints.yaml
3. Present to Architect for spec writing

### Architect (arch + contracts)
1. Read 01_spec.md from PM
2. Design system → 02_arch.md (block diagrams, interfaces)
3. Formalize contracts → contracts/*.schema.json
4. Return to PM with acceptance criteria

### All Agents
- Before work starts: `python tools/validate_specs.py` must pass
- PR scope label must match target spec section
- Changes to specs/ require QA evidence link
- Mark assumptions as `[ASSUMPTION]` in spec sections

## Glossary
Define ambiguous terms here:
- **Control plane:** FastAPI server orchestrating agents, MCP dispatch
- **Evidence pack:** Timestamped log + artifact bundle in docs/evidence/
- **RFC2119:** Internet Standard (MUST, SHOULD, MAY, MUST NOT, etc.)
- **MCP:** Model Context Protocol server (tool registry for AI agents)

## See Also
- ../CLAUDE.md for build/test commands
- ../agents/ for detailed role responsibilities
