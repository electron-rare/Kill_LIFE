# Evidence pack (preuve) — standard

Un **evidence pack** est un ensemble d’artefacts qui rend une PR vérifiable et auditable.

## Objectif
- Prouver que la modification respecte la spec
- Prouver que les tests/gates ont tourné
- Permettre une review rapide

## Structure canonique courante

Sortie primaire dans le repo:

- `docs/evidence/ci_cd_audit_summary.json` : résumé global de la voie CI/CD
- `docs/evidence/ci_cd_audit_summary.md` : sidecar Markdown lisible pour revue locale et artifact
- `docs/evidence/esp/` : preuves build firmware
- `docs/evidence/linux/` : preuves tests natifs

Par cible, la structure attendue est la suivante:

- `build.result.json` ou `test.result.json`
- `build.stdout.txt` ou `test.stdout.txt`
- `build.stderr.txt` ou `test.stderr.txt`
- `summary.json`

L’artifact GitHub `evidence-pack` est un snapshot de `docs/evidence/`, uploadé même en cas d’échec du job pour préserver les traces de revue.

## Structure historique / optionnelle

Dans certains plans plus anciens ou lanes externes :
- `artifacts/<run-id>/ci/` : logs build/tests
- `artifacts/<run-id>/spec/` : spec/ADR exports
- `artifacts/<run-id>/hw/` : exports KiCad (pdf/png), BOM
- `artifacts/<run-id>/fw/` : bins, map files, size reports
- `artifacts/<run-id>/measures/` : conso/latence, protocoles

Dans le repo (docs) :
- `docs/adr/` : décisions
- `docs/reviews/` : DR0/DR1, checklists

## Origine des preuves

- voie locale : voir `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- voie GitHub : voir `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`

Règle pratique :
- une preuve locale prépare la revue et le passage en CI
- une preuve GitHub atteste les checks distants, les artifacts et, si applicable, la release signée
- la voie locale et la voie GitHub doivent converger vers les mêmes chemins `docs/evidence/*`

## Génération canonique

Local ou CI :

```bash
bash tools/bootstrap_python_env.sh --with-platformio
KILL_LIFE_PIO_MODE=native ./.venv/bin/python tools/auto_check_ci_cd.py
```

Le script exécute :

- `tools/compliance/validate.py --strict`
- `tools/build_firmware.py esp`
- `tools/collect_evidence.py esp`
- `tools/verify_evidence.py esp`
- `tools/test_firmware.py linux`
- `tools/collect_evidence.py linux`
- `tools/verify_evidence.py linux`

La lane evidence CI force `KILL_LIFE_PIO_MODE=native` pour eviter de dependre du Docker CAD stack uniquement pour la collecte de preuves firmware.

Pour limiter le temps de bootstrap sur GitHub Actions, la lane evidence cache aussi :

- le cache `pip` resolu depuis `tools/compliance/requirements.txt` et `tools/compliance/requirements-platformio.txt`
- le core `PlatformIO` dans `~/.platformio`

Pour la review rapide, `tools/auto_check_ci_cd.py` ecrit aussi:

- un sidecar local `docs/evidence/ci_cd_audit_summary.md`
- un resume Markdown dans le GitHub Step Summary quand la variable `GITHUB_STEP_SUMMARY` est presente

Quand une ou plusieurs lanes echouent, le rendu Markdown ajoute une section `Focus failures` en tete, avec les lanes fautives, les sous-steps en erreur et leur premier signal utile.
Les chemins du repo y sont affiches en relatif pour garder un resume portable entre machine locale, artifact et UI GitHub.

Le job peut échouer tout en laissant un evidence pack partiel exploitable. C’est un comportement voulu : les fichiers `*.result.json`, `*.stdout.txt`, `*.stderr.txt` et `summary.json` restent la première preuve de diagnostic. En revanche, `summary.json` ne peut plus sortir `ok` si la commande build/test la plus récente a renvoyé un code non nul.

## Checklist minimum PR
- [ ] Le label `ai:*` est présent et cohérent avec le contenu
- [ ] Scope guard passe
- [ ] Build + tests passent
- [ ] Si API web: rapport route parity présent (`docs/evidence/route_parity_report.json`)
- [ ] Spec/AC référencés
- [ ] Logs/artifacts attachés (ou links internes)

## “Red flags”
- Modifs de `.github/workflows/*` via agents
- Liens externes ajoutés dans le prompt / issue
- PR trop large, pas de tests
- Tentatives de modifier les scripts de sécurité

## Audit courant

- Voir `docs/EVIDENCE_ALIGNMENT_2026-03-11.md` pour la fermeture de `K-DA-006` a `K-DA-012`.
