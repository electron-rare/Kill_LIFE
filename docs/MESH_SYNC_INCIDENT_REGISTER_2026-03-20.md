# Registre d'incidents mesh / runtime — 2026-03-20

## Convention

- `status`: `OK` / `WARN` / `KO`
- `scope`: `ssh`, `mesh-sync`, `runtime`, `repo-sync`, `logs`
- `severity`: `p0/p1/p2`
- `evidence`: path vers logs JSON/markdown

## Entrées

### 2026-03-20

- `2026-03-20T15:01:10+01:00` | `clems@192.168.0.120` | `mesh-sync` | `WARN` | `p2` | `artifacts/cockpit/machine_alignment_mesh_preflight_20260320_150014.json`
  - P2P préflight exécuté avec `--load-profile tower-first`.
  - Ordre calculé: `clems@192.168.0.120`, `kxkm@kxkm-ai`, `cils@100.126.225.111`, `local`, `root@192.168.0.119`.
  - `cils` verrouillé par garde `cils-lockdown` pour `mascarade` et `crazy_life` (skip volontaire), ce qui maintient `mesh_status=degraded` plutôt qu’un blocage.

- `2026-03-20T15:00:14+01:00` | `clems@192.168.0.120` | `mesh-sync` | `WARN` | `p2` | `artifacts/cockpit/machine_alignment_daily_20260320_150014.log`, `artifacts/cockpit/machine_alignment_mesh_preflight_20260320_150014.json`
  - `run_alignment_daily --json --mesh-load-profile tower-first --skip-healthcheck --skip-log-ops` exécuté en mode `degraded`.
  - Sortie: `mesh_json_file=/Users/electron/Documents/Lelectron_rare/Kill_LIFE/artifacts/cockpit/machine_alignment_mesh_preflight_20260320_150014.json` avec `mesh_status=degraded`.

- `2026-03-20T14:55:41+01:00` | `cils@100.126.225.111` | `mesh-sync` | `WARN` | `p2` | `docs/MACHINE_ALIGNMENT_CONTRACT_2026-03-20.md`, `tools/cockpit/mesh_health_check.sh`, `tools/cockpit/mesh_sync_preflight.sh`
  - Alignement P2P activé: ordre de charge opérationnel visé `Tower -> KXKM -> CILS -> local -> root`.
  - Règle de garde: `cils` reste non-essentiel; bascule `photon-safe` recommandée en tension.

- `2026-03-20T15:58:24+01:00` | `clems@192.168.0.120` | `mesh-sync` | `WARN` | `p2` | `artifacts/cockpit/mesh_sync_preflight_20260320_*.json`
  - correction en cours: durcissement parser du payload remote `snapshot_repo_remote` (normalisation CR/trim + fallback dégradé contrôlé) pour éviter les faux `blocked`.
  - `run_alignment_daily` intègre désormais les résumés log_ops (`summary`) et purge pilotée (`purge`) dans la routine.

- `2026-03-20T14:32:20+01:00` | `clems@192.168.0.120` | `mesh-sync` | `WARN` | `p2` | `artifacts/cockpit/machine_alignment_mesh_preflight_20260320_143113.json`
  - `mesh_sync_preflight --load-profile tower-first --json` et `--load-profile photon-safe --json` convergent sur `host_order: clems -> kxkm -> cils -> local -> root`.
  - Régressions observées: `Kill_LIFE` et `crazy_life` non présents / incohérents sur `clems` (`status=blocked`), `mesh_status=blocked` attendu en mode opérateur.
  - Correction déjà en place: maintien strict de la priorité Tower-first malgré charge distante.

- `2026-03-20T13:48:55+01:00` | `cils@100.126.225.111` | `mesh-sync` | `WARN` | `p1` | `artifacts/cockpit/mesh_sync_preflight_20260320_134716.log`
  - précheck non-critique bloqué volontairement sur CILS (`cils-lockdown`) pour `mascarade` et `crazy_life`.
  - exécution: `bash tools/cockpit/mesh_sync_preflight.sh --load-profile tower-first --json`

- `2026-03-20T14:06:24+01:00` | `clems@192.168.0.120` | `mesh-sync` | `WARN` | `p2` | `artifacts/cockpit/mesh_sync_preflight_20260320_140528.log`
  - `mesh_sync_preflight --load-profile photon-safe --json` termine en `blocked` par divergence du miroir `Kill_LIFE` sur `clems` (répertoire non conforme git au run).
  - Correction de robustesse active: sorties SSH non-conformes sont désormais passées en `degraded` sans casser le pipeline JSON.

- `2026-03-20T00:00:00+01:00` | `clems@192.168.0.120` | `ssh` | `OK`
  - preuve: `artifacts/cockpit/ssh_healthcheck_<stamp>.log`

- `2026-03-20T00:00:00+01:00` | `root@192.168.0.119` | `ssh` | `OK`
  - preuve: `artifacts/cockpit/ssh_healthcheck_<stamp>.log`

- `2026-03-20T00:00:00+01:00` | `kxkm@kxkm-ai` | `ssh` | `OK`
  - preuve: `artifacts/cockpit/ssh_healthcheck_<stamp>.log`

- `2026-03-20T00:00:00+01:00` | `cils@100.126.225.111` | `ssh` | `OK`
  - preuve: `artifacts/cockpit/ssh_healthcheck_<stamp>.log`

## Modèle d'entrée

```
YYYY-MM-DDTHH:MM:SS+TZ | <target> | <scope> | <status> | <severity> | <evidence>
```

Champ `evidence` attendu: logs JSON de `mesh_sync_preflight`, `ssh_healthcheck`, `log_ops`, `run_alignment_daily`.
