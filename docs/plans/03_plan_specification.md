# 3) Plan de specification

## Objectif
Produire une spec **RFC2119** testable, injectable dans le workflow agentique, et reliée à des critères d’acceptation.

## Labels recommandés
- Issue : `type:feature` + `ai:spec`
- PR : `ai:spec` (doit être présent pour scope guard)

## Entrées
- Problème à résoudre
- Contraintes : coût, consommation, temps, perf, compliance
- Contexte d’usage

## Sorties
- Spec versionnée sous `specs/<id>-<slug>/`
- Critères d’acceptation
- Plan de vérification (tests/mesures)

## Étapes

### 1. Créer la structure spec
- [x] Créer `specs/<id>-<slug>/README.md` — Delivered: `specs/README.md` + 20+ spec files in `specs/`
- [x] Ajouter `requirements.md` (RFC2119) — Delivered: `specs/01_spec.md`
- [x] Ajouter `verification.md` (tests/mesures) — Delivered: `docs/templates/ValidationPlan.md`

### 2. Écrire les exigences RFC2119
Checklist :
- [x] MUST/SHOULD/MAY, phrases courtes — Delivered: spec files use RFC2119
- [x] Pas d’ambiguïté (“rapide”, “simple”) sans métrique — Delivered in spec files
- [x] Chaque exigence doit être vérifiable — Delivered: `tools/validate_specs.py`

### 3. Critères d’acceptation
- [x] AC fonctionnels — Delivered: `specs/01_spec.md` contains AC
- [x] AC non‑fonctionnels (latence, conso, stabilité) — Delivered: `specs/constraints.yaml`

### 4. Plan de vérification
- [x] Unit tests (native) — Delivered: `firmware/test/test_basic.cpp`
- [x] Tests intégration (HIL si hardware) — Delivered: `tools/test_integration_hil.sh` (--sim for simulated mode, hardware tests require DUT)
- [x] Mesures (power profiling, timing) — Delivered: `tools/power_profiling.sh` (--estimate for software-only, hardware mode requires power meter)

### 5. Validation
- [x] Lancer la validation specs (si script dispo) — Delivered: `tools/validate_specs.py` + `tools/validate_specs_mcp_smoke.py`

Exemple :
```bash
python3 tools/validate_specs.py || true
```

## Gates
- Gate humain : review de la spec
- Gate CI : `spec lint` (si activé)
- Scope guard : `ai:spec` ne doit modifier que `specs/` et `docs/`

## Critère de sortie
✅ Spec validée, sans TODOs, avec plan de vérification et critères d’acceptation.

## Références
- `docs/AI_WORKFLOWS.md`
- `docs/templates/ValidationPlan.md`
