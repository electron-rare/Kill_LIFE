# Kill_LIFE KiCad benchmark report

- date_utc: 2026-03-14T11:01:16Z
- generated_by: bash tools/tui/kicad_benchmark_review.sh report
- guardrail: `bash tools/tui/cad_mcp_audit.sh audit` remains mandatory before promoting CAD/MCP runtime changes
- canonical_doc: `docs/KICAD_BENCHMARK_MATRIX.md`

## Scope

- benchmark the backlog references `KiAuto` and `kicad-automation-scripts`
- keep the canonical chain `kicad-cli` + `kicad-mcp`
- avoid installing external dependencies by default

## Environment snapshot

- date_utc=2026-03-14T11:01:16Z
- root_dir=/Users/electron/Kill_LIFE
- guardrail_cmd=bash tools/tui/cad_mcp_audit.sh audit
- default_dependency_policy=no external benchmark dependency is installed by default
- path[tools/tui/cad_mcp_audit.sh]=present
- path[tools/tui/kicad_benchmark_review.sh]=present
- path[tools/hw/cad_stack.sh]=present
- path[tools/hw/run_kicad_mcp.sh]=present
- path[docs/KICAD_BENCHMARK_MATRIX.md]=present
- path[docs/MCP_CAD_PROVENANCE_2026-03-14.md]=present
- cmd[bash]=/opt/homebrew/bin/bash
- cmd[python3]=/opt/homebrew/bin/python3
- cmd[docker]=/usr/local/bin/docker
- cmd[kicad-cli]=missing
- operator_note=K-025 stays doc-first; KiAuto and kicad-automation-scripts remain optional references until an explicit future lot installs or vendors them.

## Comparison matrix

| Surface / chaine | Provenance | Dependance externe par defaut | ERC / DRC | Export / doc | Fit `Kill_LIFE` | Decision | Position operatoire |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `kicad-cli` + `kicad-mcp` | officiel + custom local | aucune nouvelle dependance | fort | fort | maximal | keep | chaine canonique; deja supportee par `tools/hw/cad_stack.sh` et `tools/hw/run_kicad_mcp.sh` |
| `KiAuto` | community valide | oui, explicite et optionnelle | fort | moyen a fort | moyen | adopt | appoint cible si un lot KiCad reclame des exports ou checks au-dela de la chaine canonique |
| `kicad-automation-scripts` | community valide | oui, explicite et optionnelle | moyen | moyen | faible | ignore | reference historique de patterns Docker/doc, pas une dependance runtime a introduire dans ce repo |

## Durable decision

- `kicad-cli` + `kicad-mcp`: `keep`
- `KiAuto`: `adopt` only as an explicit, opt-in adjunct when a future lot needs extra ERC/DRC/export coverage not already served by the canonical chain
- `kicad-automation-scripts`: `ignore` as a runtime dependency; keep it as historical inspiration for documentation or Docker loop design only

## Operator workflow

```bash
bash tools/tui/cad_mcp_audit.sh audit
bash tools/tui/kicad_benchmark_review.sh report
bash tools/tui/kicad_benchmark_review.sh purge --yes
```
