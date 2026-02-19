# Evidence pack (preuve) — standard

Un **evidence pack** est un ensemble d’artefacts qui rend une PR vérifiable et auditable.

## Objectif
- Prouver que la modification respecte la spec
- Prouver que les tests/gates ont tourné
- Permettre une review rapide

## Structure recommandée

Dans CI :
- `artifacts/<run-id>/ci/` : logs build/tests
- `artifacts/<run-id>/spec/` : spec/ADR exports
- `artifacts/<run-id>/hw/` : exports KiCad (pdf/png), BOM
- `artifacts/<run-id>/fw/` : bins, map files, size reports
- `artifacts/<run-id>/measures/` : conso/latence, protocoles

Dans le repo (docs) :
- `docs/adr/` : décisions
- `docs/reviews/` : DR0/DR1, checklists

## Checklist minimum PR
- [ ] Le label `ai:*` est présent et cohérent avec le contenu
- [ ] Scope guard passe
- [ ] Build + tests passent
- [ ] Spec/AC référencés
- [ ] Logs/artifacts attachés (ou links internes)

## “Red flags”
- Modifs de `.github/workflows/*` via agents
- Liens externes ajoutés dans le prompt / issue
- PR trop large, pas de tests
- Tentatives de modifier les scripts de sécurité
