# Checklist globale — Coordination multi-agent Kill_LIFE

> Source de vérité : `specs/contracts/kill_life_agent_catalog.json` (v1, 2026-03-29)
> Chaque lot multi-agent DOIT passer cette checklist avant handoff.

---

## A. Champs obligatoires par agent dans le lot

| Champ | Attendu | Vérification |
|-------|---------|-------------|
| `owner_repo` | `Kill_LIFE` pour tous les 12 agents canoniques | `jq '.[].owner_repo' catalog.json` |
| `owner_agent` | ID unique parmi les 12 IDs canoniques | Aucun doublon par write set |
| `write_set` | `write_set_roots` non vide, sans overlap non résolu | Voir table ownership §2 |
| `status` | `ready` / `degraded` / `blocked` selon état runtime | Documenté dans le plan de lot |
| `evidence` | Chemins dans `evidence_paths` renseignés et vérifiés | Artefacts présents dans `artifacts/` ou `docs/evidence/` |

---

## B. Gates BMAD à valider

### Gate S0 — Spec ready (tous les agents)
- [ ] `specs/01_spec.md` contient des AC testables
- [ ] `specs/02_arch.md` expose les interfaces et contrats
- [ ] `specs/03_plan.md` définit les commandes et l'evidence attendue
- [ ] Contraintes validées (`constraints.yaml` si applicable)

### Gate S1 — Build & tests (Firmware, Embedded-CAD, QA-Compliance uniquement)
- [ ] `pio run` ok (au moins 1 environnement)
- [ ] `pio test -e native` ok (ou justification documentée)
- [ ] ERC vert si hardware concerné (artefact JSON)
- [ ] Netlist exportable si schéma KiCad concerné

---

## C. Contrats de handoff obligatoires

| Contrat | Owner principal | Consommateurs |
|---------|----------------|---------------|
| `specs/contracts/agent_handoff.schema.json` | Schema-Guard | Tous |
| `specs/contracts/summary_short.schema.json` | Schema-Guard | PM-Mesh, Web-CAD-Platform |
| `specs/contracts/runtime_mcp_ia_gateway.schema.json` | Schema-Guard | Runtime-Companion |
| `specs/contracts/operator_lane_evidence.schema.json` | Schema-Guard | QA-Compliance, Firmware, SyncOps |
| `specs/contracts/fab_package.schema.json` | Schema-Guard | Embedded-CAD |
| `specs/contracts/yiacad_uiux_output.schema.json` | Schema-Guard | Web-CAD-Platform, UX-Lead |
| `specs/contracts/workflow_handshake.schema.json` | Schema-Guard | KillLife-Bridge |

---

## D. Synchronisation et surfaces canoniques

- Evidence cockpit : `artifacts/cockpit/` (owner : SyncOps)
- Evidence CI : `artifacts/ci/` (owner : QA-Compliance)
- Mémoire bridge : `artifacts/cockpit/kill_life_memory/` (owner : KillLife-Bridge)
- Plans : `docs/plans/` (owner : PM-Mesh)
- Docs narrative : `docs/` hors sous-répertoires spécialisés (owner : Docs-Research)

Règle clé : **chaque write set a un seul owner top-level**. Les autres agents lisent seulement.

---

## E. Discipline sous-agents

- Les sous-agents sont **metadata de lane** uniquement.
- Ils ne sont JAMAIS exposés comme agents publics (`public_api_enabled: false` implicite).
- Seuls les 12 agents canoniques ont `public_api_enabled: true`.
- Le sous-agent ne peut pas avoir de `write_set` indépendant de son agent parent.

---

## F. Commande de validation finale

```bash
python3 tools/validate_specs.py --strict
ruff check .
bash tools/test_python.sh --suite stable
```

Checklist signée par l'agent owner du lot avant clôture.