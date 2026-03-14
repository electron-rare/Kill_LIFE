# Repo Deep Analysis Plan — Kill_LIFE — 2026-03-11

## Mission

Rendre `Kill_LIFE` plus lisible comme socle canonique runtime/spec-first:

- diagrammes de sequence d'execution
- carte fonctionnelle des surfaces produit
- README et docs/plans relies au contrat multi-repo courant

## Agents actifs

| Role | Mission |
| --- | --- |
| `embedded-systems-auditor` | cadrage global et priorisation |
| `workflow-map-curator` | carte fonctionnelle `specs/workflows/tools/hardware/firmware` |
| `mcp-runtime-analyst` | sequences `workflow -> local action/github dispatch -> evidence` |
| `firmware-doctor` | audit firmware/PlatformIO si blocages ou regressions runtime |
| `readme-curator` | alignement README/docs/plans |

## Deliverables

- diagrammes de sequence `local` et `github`
- carte fonctionnelle canonique
- README enrichi de pointeurs vers le plan actif

## Status

- `K-DA-001` ferme par `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md`
- `K-DA-002` ferme par `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- `K-DA-003` ferme par `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`
- `K-DA-004` ferme par la synchronisation `docs/RUNBOOK.md`, `docs/index.md`, `docs/workflows/README.md`, `docs/AI_WORKFLOWS.md`, `docs/evidence/evidence_pack.md`
- `K-DA-006` ferme par `.github/workflows/evidence_pack.yml`, `docs/evidence/evidence_pack.md` et `docs/EVIDENCE_ALIGNMENT_2026-03-11.md`
- `K-DA-007` ferme par `tools/bootstrap_python_env.sh`, `tools/ci_runtime.py`, `tools/collect_evidence.py`, `.github/workflows/evidence_pack.yml` et `test/test_firmware_evidence.py`
- `K-DA-008` ferme par `.github/workflows/evidence_pack.yml`, `tools/compliance/requirements-platformio.txt` et la mise en cache `pip` / `PlatformIO`
- `K-DA-009` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et la doc evidence/GitHub workflow
- `K-DA-010` ferme par `tools/auto_check_ci_cd.py`, `docs/evidence/ci_cd_audit_summary.md` et la doc evidence/GitHub workflow
- `K-DA-011` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et le focus automatique sur les lanes en echec
- `K-DA-012` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et la compaction des chemins absolus dans le rendu Markdown evidence
- `K-DA-013` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et la reduction des signaux listeux en resumes courts
- `K-DA-014` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et l'extraction d'un bloc `Artifact summary` dedie dans le rendu Markdown evidence
- `K-DA-015` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et l'exposition `required_files` / `missing` dans `Artifact summary`
- `K-DA-016` ferme par `tools/auto_check_ci_cd.py`, `test/test_auto_check_ci_cd.py` et la detection de drift `summary ok` dans `Artifact summary`

## Next tasks

- `K-DA-017` montrer plus explicitement les artefacts encore presents quand `Drift` est detecte
