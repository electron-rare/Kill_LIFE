# Kill_LIFE Evidence Alignment - 2026-03-11

## Scope

Fermer `K-DA-006`: verifier que la voie locale, la voie GitHub et la documentation parlent bien du meme evidence pack.

## Mismatch trouve

- `.github/workflows/evidence_pack.yml` pointait vers `tools/evidence/validate_evidence_pack.py`, fichier absent du repo.
- La documentation parlait encore d'une structure generique `artifacts/<run-id>/...` alors que les scripts actifs ecrivent deja dans `docs/evidence/`.
- Le contrat CI et le contrat docs n'avaient donc plus la meme sortie canonique.

## Contrat canonique retenu

- La CI `evidence_pack.yml` utilise maintenant `bash tools/bootstrap_python_env.sh` puis `./.venv/bin/python tools/auto_check_ci_cd.py`.
- Le rapport global attendu est `docs/evidence/ci_cd_audit_summary.json`.
- Chaque cible ecrit ses preuves dans `docs/evidence/<target>/`:
  - `build.result.json` ou `test.result.json`
  - `build.stdout.txt` ou `test.stdout.txt`
  - `build.stderr.txt` ou `test.stderr.txt`
  - `summary.json`
- L'artifact GitHub `evidence-pack` embarque un snapshot complet de `docs/evidence/`, meme si le job echoue.

## Verification locale

Commande executee:

```bash
./.venv/bin/python tools/auto_check_ci_cd.py
```

Observation du 2026-03-11:

- `compliance`: `rc=0`
- `linux`: evidence pack present et verifie dans `docs/evidence/linux/`
- `esp`: evidence pack partiel, car aucun artefact firmware n'etait disponible dans l'etat du run local

Cette execution confirme que le repo sait deja produire des preuves exploitables meme en cas d'echec partiel. La correction principale consistait donc a faire pointer la CI GitHub sur cette chaine reelle et a documenter la granularite des sorties.

## Consequence operateur

- Un echec CI ne doit plus masquer l'evidence pack: les logs et resumes restent telechargeables via l'artifact `evidence-pack`.
- La doc locale et la doc GitHub parlent maintenant des memes chemins.
- Le prochain lot pertinent n'est plus l'alignement documentaire, mais la stabilisation de la lane ESP pour obtenir un `summary.json` complet en CI Ubuntu.

## Next lot

- `K-DA-007`: stabiliser la production d'artefacts firmware `esp` en CI pour que `docs/evidence/esp/summary.json` sorte en `status=ok` sur la lane nominale.
