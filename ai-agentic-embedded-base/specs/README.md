# Specs (Spec-driven)

Flux conseillé (itératif) :
1) `00_intake.md` : idée brute + contexte
2) `01_spec.md` : spec claire + AC
3) `02_arch.md` : architecture + ADR
4) `03_plan.md` : plan découpé, risques, validations
5) `04_tasks.md` : backlog exécutable (issues / PRs)
6) Implémentation (firmware/hardware) + tests + doc

Le fichier `constraints.yaml` est la **source de vérité** des contraintes non-fonctionnelles et règles repo.

Specs complémentaires:

- `zeroclaw_dual_hw_orchestration_spec.md`: architecture d'orchestration ZeroClaw multi-repo + double matériel.
- `zeroclaw_dual_hw_todo.md`: backlog opérationnel court terme pour autonomie contrôlée.

Synchronisation `spec_kit`:

- `specs/` (racine repo) et `ai-agentic-embedded-base/specs/` doivent rester alignés.
- Après toute mise à jour, synchroniser avec:
  - `rsync -a --delete specs/ ai-agentic-embedded-base/specs/`
- Vérifier l'absence d'écart avec:
  - `diff -ru ai-agentic-embedded-base/specs specs`
