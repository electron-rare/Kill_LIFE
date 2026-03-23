# Registre machine/capacite — Kill_LIFE

Date: `2026-03-20`
Source de verite machine-readable:

- `specs/contracts/machine_registry.mesh.json`
- schema: `specs/contracts/machine_registry.schema.json`

Objectif: publier un registre unique pour les roles, ports, priorites et restrictions de placement afin de reduire le drift entre documentation, preflight mesh et runbooks cockpit.

## Contenu porte par le registre

- id machine stable
- cible SSH ou label local
- role operatoire
- port
- priorite de scheduling
- type de placement (`primary`, `secondary`, `quota`, `local`, `reserve`)
- profils actifs (`tower-first`, `photon-safe`)
- liste des repos critiques autorises
- politique non essentielle
- drapeau `reserve_only`
- biais d'ordre de charge

## Ordre canonique actuel

1. `tower` -> `clems@192.168.0.120`
2. `kxkm` -> `kxkm@kxkm-ai`
3. `cils` -> `cils@100.126.225.111`
4. `local`
5. `root-reserve` -> `root@192.168.0.119`

## Regles operatoires encodees

- `cils` reste en quota et ne porte que `Kill_LIFE` en critique.
- `photon-safe` garde `cils` atteignable, mais sans charge applicative non essentielle.
- `root-reserve` reste une reserve stricte et ne remonte pas devant `local` en fonctionnement nominal.

## CLI cockpit associee

- `bash tools/cockpit/machine_registry.sh --action summary --json`
- `bash tools/cockpit/machine_registry.sh --action list`
- `bash tools/cockpit/machine_registry.sh --action show --machine cils --json`
- `bash tools/cockpit/machine_registry.sh --action clean-logs --days 14`

## Suite prevue

- `mesh_sync_preflight.sh` consomme maintenant ce registre pour les roles, ports, priorites, placement et la reserve runtime
- `ssh_healthcheck.sh` charge maintenant ses cibles SSH directement depuis le registre et ignore automatiquement l'entree `local` (port `0`)
- `run_alignment_daily.sh` capture maintenant un resume JSON du registre et l'embarque dans ses artefacts/JSON de synthese
- externaliser ensuite les derniers candidats de chemins repo pour eliminer le drift restant cote preflight
