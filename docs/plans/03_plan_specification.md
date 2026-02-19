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
- [ ] Créer `specs/<id>-<slug>/README.md`
- [ ] Ajouter `requirements.md` (RFC2119)
- [ ] Ajouter `verification.md` (tests/mesures)

### 2. Écrire les exigences RFC2119
Checklist :
- [ ] MUST/SHOULD/MAY, phrases courtes
- [ ] Pas d’ambiguïté (“rapide”, “simple”) sans métrique
- [ ] Chaque exigence doit être vérifiable

### 3. Critères d’acceptation
- [ ] AC fonctionnels
- [ ] AC non‑fonctionnels (latence, conso, stabilité)

### 4. Plan de vérification
- [ ] Unit tests (native)
- [ ] Tests intégration (HIL si hardware)
- [ ] Mesures (power profiling, timing)

### 5. Validation
- [ ] Lancer la validation specs (si script dispo)

Exemple :
```bash
python tools/validate_specs.py || true
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