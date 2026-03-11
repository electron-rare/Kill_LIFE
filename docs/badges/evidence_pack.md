# Guide Workflow Evidence Pack Validation

## Objectif
Garantir la présence et la validité des artefacts de conformité (evidence pack) à chaque étape du CI/CD.

## Outils utilisés
- `bash tools/bootstrap_python_env.sh`
- `./.venv/bin/python tools/auto_check_ci_cd.py`
- `docs/evidence/ci_cd_audit_summary.json`
- `docs/evidence/<target>/summary.json`

## Logique du workflow
- Bootstrap du venv repo-local sur GitHub Actions
- Exécution de la chaîne canonique `compliance -> build/test -> collect -> verify`
- Upload de `docs/evidence/` dans l’artifact `evidence-pack`, même si le job échoue

## Critères de conformité
- Résumé global présent dans `docs/evidence/ci_cd_audit_summary.json`
- Résumés par cible présents dans `docs/evidence/<target>/summary.json`
- Artefacts accessibles et traçables dans l’artifact GitHub `evidence-pack`

## Badge dynamique
- Endpoint JSON : docs/badges/evidence_pack_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut de validation de l’evidence pack
- Les artefacts sont accessibles dans l’artifact CI `evidence-pack`
- Le contrat réel est documenté dans `docs/evidence/evidence_pack.md` et `docs/EVIDENCE_ALIGNMENT_2026-03-11.md`

---

[Retour à la liste des workflows](../badges/)
