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

## Next tasks

- `K-DA-002` diagramme de sequence `workflow local`
- `K-DA-003` diagramme de sequence `workflow github`
- `K-DA-004` synchroniser README, plans et doc operator
