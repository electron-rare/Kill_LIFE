# Lot provenance MCP/CAD — 2026-03-14

Lot documentaire et de backlog pour `Kill_LIFE`, mene sans toucher a `git` et sans lancer de tests.

## References utilisees

- `/Users/electron/.codex/memories/electron_rare_chantier/MANIFEST_EASTER_EGGS_REF_2026-03-11.md`
- `/Users/electron/.codex/memories/electron_rare_chantier/WEB_NOTES_2026-03-13_GATEWAY_MCP.md`
- `/Users/electron/.codex/memories/electron_rare_chantier/WEB_2026_TO_BACKLOG_2026-03-14.md`

## Garde-fou conserve

Commande jouee:

```bash
bash tools/tui/cad_mcp_audit.sh audit
```

Resultat durable extrait du rapport:

- `raw_hits`: `4`
- `ignored_hits`: `4`
- `actionable_hits`: `0`
- `doc_anchor_hits`: `103`
- rapport conserve: `.ops/cad-mcp-audit/report.md`

Le lot provenance n'assouplit donc pas l'allowlist CAD/MCP existante.

## Decisions retenues

- `officiel`
  - surfaces MCP distantes publiees par leur owner: `huggingface`
  - runtimes CAD amont: `KiCad`, `FreeCAD`, `OpenSCAD`
- `community valide`
  - references de benchmark ou d'appoint: `KiAuto`, `kicad-automation-scripts`, `InteractiveHtmlBom`
- `custom local`
  - launchers, wrappers, serveurs et garde-fous maintenus dans `Kill_LIFE` ou `mascarade`: `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad`, `component_database`, `kicad_tools`, `nexar_api`, `tools/tui/cad_mcp_audit.sh`

## Actions durables

- mise a jour des docs canoniques MCP: `docs/MCP_SETUP.md`, `docs/MCP_SUPPORT_MATRIX.md`, `docs/MCP_ECOSYSTEM_MATRIX.md`
- mise a jour de la doc CAD: `deploy/cad/README.md`
- mise a jour du plan canonique: `docs/plans/15_plan_mcp_runtime_alignment.md`
- mise a jour du TODO canonique: `specs/mcp_tasks.md`
- `K-025` absorbe via `docs/KICAD_BENCHMARK_MATRIX.md` et `tools/tui/kicad_benchmark_review.sh`

## Politique logs

- les logs bruts vivent temporairement dans `.ops/cad-mcp-audit/*.log`
- seul le rapport Markdown `.ops/cad-mcp-audit/report.md` est conserve comme trace durable
- apres extraction des conclusions, les `.log` bruts doivent etre purges
