# Kill_LIFE Feature Map - 2026-03-20

## Scope

Carte de référence de toutes les surfaces stables du projet, alignée avec le manifeste de refonte.

## Feature map

```mermaid
flowchart TD
    KL[Kill_LIFE]

    KL --> SPECS[specs/ (00_intake -> 04_tasks)]
    KL --> PLANS[docs/plans/*]
    KL --> WORKFLOWS[workflow lanes + workflow.schema]
    KL --> TOOLS[tools/ runtime, validation, CAD/MCP]
    KL --> AGENTS[agents/ + .github/agents + prompts]
    KL --> BMAD[bmad/ gates + rituels + templates]
    KL --> HW[hardware/ + rules]
    KL --> FW[firmware/ PlatformIO]
    KL --> COMP[compliance/ + evidence + CI gates]
    KL --> DOCS[docs/ operator, evidence, on-boarding]
    KL --> GH[.github/workflows + issue templates]
    KL --> MCPR[MCP setup + serveur runtime]
    KL --> TUI[tools/cockpit]

    SPECS --> SPECCHAIN[00_intake -> 01_spec -> 02_arch -> 03_plan -> 04_tasks]
    SPECS --> CONSTRAINTS[specs/constraints.yaml]

    WORKFLOWS --> WF_REG[spec-first.json + embedded-ci-local.json + compliance-release.json]
    WORKFLOWS --> WF_SCHEMA[workflow.schema.json]
    WORKFLOWS --> WF_CATALOG[.github/workflows/*.yml]

    TOOLS --> VS[tools/validate_specs.py]
    TOOLS --> CPR[tools/compliance/]
    TOOLS --> CAD_RUNTIME[tools/hw/cad_stack.sh + cad_runtime]
    TOOLS --> MCP_TOOLS[run_*_mcp.sh + mcp_runtime_status]
    TOOLS --> REPO_STATE[tools/repo_state/*]
    TOOLS --> CAD_FUSION[tools/cad/ai_native_forks.sh + yiacad_fusion_lot.sh]

    AGENTS --> AG_MERGE[PM / Architect / FW / HW / QA / Doc]
    AGENTS --> GITHUB_PROMPTS[.github/prompts/*]

    HW --> HW_BLOCKS[blocks + rules + previews]
    FW --> FW_SRC[firmware/src]
    FW --> FW_TEST[firmware/test]

    COMP --> PROFILE[active_profile.yaml + standards]
    COMP --> GATES[evidence + checks]

    MCPR --> KICAD_MCP[kicad MCP]
    MCPR --> VALIDATE_MCP[validate-specs MCP]
    MCPR --> GH_DISPATCH[github-dispatch MCP]
    MCPR --> DOC_MCP[knowledge-base + freecad + openscad + HF]
    MCPR --> MESH[docs/MCP_SETUP.md + docs/MCP_SUPPORT_MATRIX.md]

    TUI --> REFONTE_TUI[refonte_tui.sh]
    TUI --> LOT_CHAIN[lot_chain.sh + run_next_lots_autonomously.sh]
    TUI --> LOGS[artifacts/refonte_tui/*.log]

    DOCS --> HANDOFFS[handoffs + rituals + workflows docs]
    DOCS --> EVIDENCE_DOCS[docs/evidence/*]

    GH --> G_TEMPLATE[templates + issue labels]
    GH --> GH_RELEASE[release_signing + repo_state]

    TUI --> EXEC[actions auto + log analysis + log purge]
```

## Surfaces canoniques

| Surface | Rôle canonical | Anchors |
| --- | --- | --- |
| `specs/` | point d’entrée spec-first | `specs/00_intake.md`, `specs/01_spec.md`, `specs/02_arch.md`, `specs/03_plan.md`, `specs/04_tasks.md`, `specs/constraints.yaml` |
| `docs/plans/*` | contrats opératoires lot-chain | `docs/plans/REPO_DEEP_ANALYSIS_2026-03-11.md`, `docs/plans/12_plan_gestion_des_agents.md`, `docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`, `specs/03_plan.md`, `specs/04_tasks.md` |
| `workflows/` | exécutable JSON + schéma | `workflows/spec-first.json`, `workflows/embedded-ci-local.json`, `workflows/compliance-release.json`, `workflow.schema.json` |
| `tools/cockpit/*` | pilotage TUI + lot-chain | `tools/cockpit/refonte_tui.sh`, `tools/autonomous_next_lots.py`, `tools/cockpit/lot_chain.sh`, `tools/run_autonomous_next_lots.sh`, `tools/cockpit/run_next_lots_autonomously.sh` |
| `tools/repo_state/*` | état global + contrat header | `tools/repo_state/collect.py`, `tools/repo_state/repo_refresh.sh`, `tools/repo_state/lint_header_contract.py`, `docs/REPO_STATE_HEADER_CONTRACT.md` |
| `tools/` | outillage runtime | `tools/validate_specs.py`, `tools/compliance/*`, `tools/hw/*`, `tools/mcp_runtime_status.py`, `tools/quality/*` |
| `tools/cad/*` | lot-fusion CAD IA-native | `tools/cad/ai_native_forks.sh`, `tools/cad/yiacad_fusion_lot.sh`, `docs/CAD_AI_NATIVE_FORK_STRATEGY.md` |
| `hardware/` | blocs réutilisables + règles | `hardware/blocks/`, `hardware/rules/` |
| `firmware/` | implémentation embarquée | `firmware/src/`, `firmware/test/` |
| `docs/` | documentation opérateur + evidence | `docs/evidence/*`, `docs/MCP_SETUP.md`, `docs/AI_WORKFLOWS.md`, `docs/index.md` |
| `.github/` | automatisation et prompts | `.github/prompts/`, `.github/agents/`, `.github/workflows/` |
| `test/` | assurance qualité | `test/test_validate_specs.py`, `test/test_github_dispatch_mcp.py`, `test/test_freecad_mcp.py`, `test/test_mcp_runtime_status.py` |

## Lignes d’exécution

- spec lane: `specs/00_intake.md` -> ... -> `specs/04_tasks.md`
- workflow lane: workflows JSON -> validation locale -> execution locale/GitHub
- tooling lane: `tools/cockpit/refonte_tui.sh`, `tools/specs/sync_spec_mirror.sh`
- cad fusion lane: `tools/cad/yiacad_fusion_lot.sh` -> `artifacts/cad-fusion`
- hardware lane: `hardware/*` -> `tools/hw/*`
- firmware lane: `firmware/*` -> evidence + CI
- compliance lane: `compliance/*` -> evidence + headers
- operator lane: `.github/workflows/` + docs -> contribution contrôlée

## Contrat source-of-truth

- `Kill_LIFE` reste la source de vérité des specs, du catalogue workflow, de la gouvernance compliance, de l’outillage et de la carte fonctionnelle.
- `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` documente les références OSS intégrables.
- Les dépôts compagnon (`mascarade`, `crazy_life`) restent des surfaces d’exploitation, pas de remplacement du contrat local.
