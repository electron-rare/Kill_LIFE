# Kill_LIFE Evidence Alignment - 2026-03-11

## Scope

Fermer `K-DA-006`: verifier que la voie locale, la voie GitHub et la documentation parlent bien du meme evidence pack.

## Mismatch trouve

- `.github/workflows/evidence_pack.yml` pointait vers `tools/evidence/validate_evidence_pack.py`, fichier absent du repo.
- La documentation parlait encore d'une structure generique `artifacts/<run-id>/...` alors que les scripts actifs ecrivent deja dans `docs/evidence/`.
- Le contrat CI et le contrat docs n'avaient donc plus la meme sortie canonique.

## Contrat canonique retenu

- La CI `evidence_pack.yml` utilise maintenant `bash tools/bootstrap_python_env.sh` puis `./.venv/bin/python tools/auto_check_ci_cd.py`.
- La lane evidence `esp` force maintenant `KILL_LIFE_PIO_MODE=native` et installe `platformio` dans le venv repo-local.
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

Correctif complementaire du lot suivant:

- `ci_runtime.py` detecte aussi `PlatformIO` dans `.venv/bin/pio` et via `python -m platformio`.
- `collect_evidence.py` ne valide plus un evidence pack si la derniere commande build/test a echoue, meme si des artefacts plus anciens existent encore dans `.pio/`.

Verification complementaire du 2026-03-11:

```bash
KILL_LIFE_PIO_MODE=native ./.venv/bin/python tools/auto_check_ci_cd.py
```

Resultat:

- `compliance`: `rc=0`
- `esp`: `rc=0`, evidence pack complet dans `docs/evidence/esp/`
- `linux`: `rc=0`, evidence pack complet dans `docs/evidence/linux/`

Acceleration complementaire du 2026-03-13:

- `evidence_pack.yml` active des caches separes pour `pip` et `PlatformIO`.
- La version de `PlatformIO` est figee dans `tools/compliance/requirements-platformio.txt`.
- Le bootstrap Python et la CI evidence s'appuient maintenant sur la meme source de versionnement, ce qui reduit les retelechargements et rend la lane plus stable.

Lisibilite operateur complementaire du 2026-03-13:

- `tools/auto_check_ci_cd.py` ecrit maintenant un resume Markdown dans `GITHUB_STEP_SUMMARY` quand le job tourne sur GitHub Actions.
- Le Step Summary reprend `compliance`, `esp`, `linux`, puis le detail des sous-steps `build/test -> collect -> verify`.
- Le JSON `docs/evidence/ci_cd_audit_summary.json` reste la source canonique; le Step Summary est une projection lisible pour la review.

Sidecar local complementaire du 2026-03-13:

- le meme rendu Markdown est maintenant ecrit dans `docs/evidence/ci_cd_audit_summary.md`
- l'artifact `evidence-pack` embarque donc une version lisible sans passer par l'UI GitHub Actions

Focus erreurs complementaire du 2026-03-13:

- le rendu Markdown ajoute maintenant une section `Focus failures` quand `compliance` ou une lane cible sort en non-zero
- cette section remonte la lane, les sous-steps en echec et le premier signal utile avant le detail complet

Compaction des chemins complementaire du 2026-03-13:

- le rendu Markdown compresse maintenant les chemins absolus du repo en chemins relatifs, par exemple `docs/evidence/esp`
- le JSON `docs/evidence/ci_cd_audit_summary.json` reste inchange; seule la projection Markdown est epuree pour la lecture humaine

## Consequence operateur

- Un echec CI ne doit plus masquer l'evidence pack: les logs et resumes restent telechargeables via l'artifact `evidence-pack`.
- La doc locale et la doc GitHub parlent maintenant des memes chemins.
- Le prochain lot pertinent n'est plus l'alignement documentaire, mais la reduction des signaux trop verbeux dans le resume Markdown evidence.

## Next lot

- `K-DA-013`: reduire les signaux trop verbeux dans le rendu Markdown evidence.
