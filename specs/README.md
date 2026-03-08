# Specs (Spec-driven)

Flux conseille (iteratif) :
1) `00_intake.md` : idee brute + contexte
2) `01_spec.md` : spec claire + AC
3) `02_arch.md` : architecture + ADR
4) `03_plan.md` : plan decoupe, risques, validations
5) `04_tasks.md` : backlog executable (issues / PRs)
6) Implementation (firmware/hardware) + tests + doc

Le fichier `constraints.yaml` est la **source de verite** des contraintes non-fonctionnelles et regles repo.

Specs complementaires:

- `github_mcp_conversion_spec.md`: prep de conversion de `workflow_dispatch` vers une surface MCP future.
- `cad_modeling_tasks.md`: backlog canonique `FreeCAD/OpenSCAD` pour la stack CAD locale hors MCP.
- `kicad_mcp_scope_spec.md`: perimetre fonctionnel, hors scope et criteres d'acceptation du MCP KiCad supporte.
- `mcp_agentics_target_backlog.md`: backlog cible 2026 -> 2028 pour `MCP`, `agentics`, `A2A`, avec ownership par repo.
- `mcp_tasks.md`: backlog canonique des actions MCP locales, partage entre runtime, doc et gouvernance.
- `knowledge_base_mcp_spec.md`: spec canonique du bridge et du MCP knowledge base (`memos` / `docmost`).
- `zeroclaw_dual_hw_orchestration_spec.md`: architecture d'orchestration ZeroClaw multi-repo + double materiel.
- `zeroclaw_dual_hw_todo.md`: backlog operationnel court terme pour autonomie controlee.

Synchronisation `spec_kit`:

- `specs/` (racine repo) est la source de verite canonique.
- `ai-agentic-embedded-base/specs/` est un miroir exporte.
- Apres toute mise a jour canonique, synchroniser le miroir avec:
  - `rsync -a --delete specs/ ai-agentic-embedded-base/specs/`
- Verifier l'absence d'ecart avec:
  - `diff -ru ai-agentic-embedded-base/specs specs`
