# Contrat d’alignement inter-machines — Kill_LIFE

Date: `2026-03-20`
Objectif: maintien d’une base commune opérationnelle sur les 4 cibles SSH et la stratégie de répartition de charge.

Ordre de pilotage opérationnel cible:

1. `clems@192.168.0.120` (Tower)
2. `kxkm@kxkm-ai` (KXKM)
3. `cils@100.126.225.111` (CILS, usage non essentiel)
4. Local (`/Users/electron/Documents/Lelectron_rare/Kill_LIFE`)
5. `root@192.168.0.119` (Réserve de reprise)

## État de base (contrôles de référence)

- `git` commit attendu (branche `main`): `bd3f7b99154f86057ba18b9948d940df55722b12`
- Remote attendu: `https://github.com/electron-rare/Kill_LIFE.git`
- Script de maintenance attendu: `tools/repo_state/repo_refresh.sh`
- Port SSH attendu: `22` (toutes machines)
- Source machine-readable associée: `specs/contracts/machine_registry.mesh.json`

## Contrat machine

### Politique de répartition de charge P2P

- Ordre de charge prioritaire de base: `Tower (clems)` -> `KXKM` -> `CILS` -> `local` -> `root`.
- Le scheduler calcule un score `load_ratio = loadavg / CPUs`, puis `score = priorité_base + int(load_ratio * 1000)` et réordonne les hôtes par score croissant.
- `root` reste la cible de reprise si les 3 premiers sont surchargés, hors cas dégradés.
- `root` est strictement maintenu en réserve: il ne remonte pas devant `local` dans le `host_order` tant que `tower-first` fonctionne.
- En surcharge (par défaut `load_ratio > 1.8`), seuls les contrôles critiques (`Kill_LIFE`) sont exécutés.
- `cils` est verrouillé en opération standard (`tower-first`) : seul `Kill_LIFE` est vérifié.
- `cils` en mode `photon-safe` ne reçoit **aucun** précheck applicatif (charge totale zéro, uniquement reachabilité SSH implicite).
- `CILS` reste hôte secondaire (photon): pas d’hébergement de services essentiels persistants; seulement les snapshots critiques (`Kill_LIFE`) sont acceptés en `tower-first`.
- `root` est la réserve de calcul pour reprendre le relais en cas de besoin (pas cible prioritaire).
- `root` reste en réserve de capacité de calcul pour les bascules de charge.
- En cas de doute opérationnel, forcer `--load-profile photon-safe` pour les préchecks.

### Spécification hôtes

- `clems@192.168.0.120`
  - rôle: machine de pilotage / orchestration locale
  - port: `22`
  - path repo: `/home/clems/Kill_LIFE-main`
  - priorité: `1`
  - état cible: Git repo proprement monté, branche `main`, commit cible, `SCRIPT_OK`

- `kxkm@kxkm-ai`
  - rôle: Mac opérateur
  - port: `22`
  - path repo: `/home/kxkm/Kill_LIFE-main`
  - priorité: `2`
  - état cible: Git repo proprement monté, branche `main`, commit cible, `SCRIPT_OK`

- `cils@100.126.225.111`
  - rôle: Mac opérateur secondaire
  - port: `22`
  - path repo: `/Users/cils/Kill_LIFE-main`
  - priorité: `3`
  - état cible: Git repo proprement monté, branche `main`, commit cible, `SCRIPT_OK`
  - contrainte: ne pas y héberger de services persistants critiques; en `tower-first`, précheck non-essentiel verrouillé (`cils-lockdown`) ; en `photon-safe`, aucun précheck applicatif SSH-only.

- `root@192.168.0.119`
  - rôle: serveur système / exécution matérielle
  - port: `22`
  - path repo: `/root/Kill_LIFE-main`
  - priorité: `5`
  - état cible: Git repo proprement monté, branche `main`, commit cible, `SCRIPT_OK`

## Health-check SSH (référence opérationnelle)

- Exécuter depuis la machine pilote:
  - `bash tools/cockpit/ssh_healthcheck.sh --json`
- Sorties attendues:
  - un statut `OK`/`KO` par entrée
  - rôle et port associés à chaque cible
  - cibles SSH résolues depuis `specs/contracts/machine_registry.mesh.json` (`local` exclu automatiquement car port `0`)
  - fichier log horodaté `artifacts/cockpit/ssh_healthcheck_<YYYYMMDD>_<HHMMSS>.log`
- Matrix opérationnelle cible:
  - P1 `clems@192.168.0.120` (`22`) → rôle `Machine de pilotage / orchestration locale`
  - P2 `kxkm@kxkm-ai` (`22`) → rôle `Mac opérateur`
  - P3 `cils@100.126.225.111` (`22`) → rôle `Mac opérateur secondaire`
  - P4 `root@192.168.0.119` (`22`) → rôle `Serveur système / exécution matérielle`

## Check-list de conformité (quotidienne)

1. `bash tools/cockpit/ssh_healthcheck.sh --json`
2. `cd /home/<user>/Kill_LIFE-main && git status --short` (ou équivalent remote via SSH)
3. `bash tools/repo_state/repo_refresh.sh --header-only`
4. Vérifier que `docs/REPO_STATE.md` et `docs/repo_state.json` restent cohérents avec la source de vérité

## Règles de dérive

- Les changements locaux non souhaités sur `Kill_LIFE` sont prohibés hors workflow défini.
- Les références obsolètes de machine/référence doivent être retirées du périmètre opérationnel avant publication.
- En cas de divergence commit:
  - trancher sur la branche/commit cible (standard: `origin/main`)
  - documenter la déviation dans `docs/MACHINE_SYNC_STATUS_2026-03-20.md`
  - réaligner via `git fetch --all --prune && git reset --hard origin/main`

## Routine quotidienne de contrôle

- Exécuter une fois par jour:
  - Machine de pilotage: `bash tools/cockpit/run_alignment_daily.sh --json --mesh-load-profile tower-first`
  - Machines de support: `bash tools/cockpit/run_alignment_daily.sh --skip-healthcheck --skip-mesh --json`
  - Cibles élargies: `clems`, `kxkm`, `cils`, `root`
  - Optionnel: `--purge-days <N>` pour ajuster la rétention des logs (défaut: `14`)
- Optionnel: forcer le mode `photon-safe` sur une exécution spécifique :
  - `bash tools/cockpit/run_alignment_daily.sh --json --skip-healthcheck --mesh-load-profile photon-safe`
- Exemple cron:
  - `05 06 * * * cd /chemin/vers/Kill_LIFE && bash tools/cockpit/run_alignment_daily.sh --json --purge-days 14 >> artifacts/cockpit/cron.out 2>&1`
- Logs:
  - `artifacts/cockpit/machine_alignment_daily_<YYYYMMDD>_<HHMMSS>.log`

## Sortie de dérogation

- Toute machine hors contrat doit être remontée immédiatement avec:
  - machine/port
  - rôle
  - écart constaté
  - preuve de commande
  - ETA de remise en conformité
