# Nettoyage des dirty-sets inter-machines

Last updated: 2026-03-20 15:45 CET

## Objectif

Aligner les dirty-sets des lanes mesh `*-main` entre `local`, `clems`, `kxkm`, `root` et `cils`, sans ecraser les worktrees historiques ni casser le `cils-lockdown`.

## Script utilise

- `bash tools/cockpit/mesh_dirtyset_sync.sh --json`

Log principal:

- `artifacts/cockpit/mesh_dirtyset_sync_20260320_152929.log`

## Actions realisees

- synchronisation des fichiers reellement dirty depuis les lanes mesh locales vers les lanes mesh distantes
- purge des artefacts Apple:
  - `._*`
  - `.DS_Store`
- purge des `artifacts/` transitoires dans `mascarade-main` et `crazy_life-main`

## Etat Git reel apres nettoyage

| Target | `Kill_LIFE-main` | `mascarade-main` | `crazy_life-main` |
| --- | --- | --- | --- |
| `local` | `27` | `6` | `6` |
| `clems@192.168.0.120` | `27` | `6` | `6` |
| `kxkm@kxkm-ai` | `27` | `6` | `6` |
| `root@192.168.0.119` | `27` | `6` | `6` |
| `cils@100.126.225.111` | `27` | `6` | `6` |

## Interpretation

- Les dirty-sets inter-machines sont maintenant alignes.
- Le `mesh_status=degraded` peut encore subsister:
  - a cause du `cils-lockdown` volontaire pour `mascarade` et `crazy_life`,
  - ou a cause du parseur/snapshot mesh qui peut doubler une entree transitoire avant l'entree `ready`.
- Ce `degraded` n'indique plus une divergence reelle des dirty-sets.
