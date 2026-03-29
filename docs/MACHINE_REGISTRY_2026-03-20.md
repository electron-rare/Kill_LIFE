# Registre machine/capacite — Kill_LIFE

Date: `2026-03-29`
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
2. `photon` -> `root@192.168.0.119`
3. `kxkm-ai` -> `kxkm@100.87.54.119`
4. `grosmac` -> `electron@100.80.178.42`
5. `cils` -> `cisl@100.126.225.111`

## Regles operatoires encodees

- `tower` reste le noeud principal de collaboration, data plane et observabilite.
- `photon` doit rester edge minimal et ne pas devenir un fourre-tout applicatif.
- `kxkm-ai` porte l'inference GPU, le CAD headless et les traitements IA lourds.
- `grosmac` est un poste operateur local et un point de validation de proximite, pas un coeur de production.
- `cils` reste une reserve legacy et ne doit pas remonter en hebergement nominal.

## CLI cockpit associee

- `bash tools/cockpit/machine_registry.sh --action summary --json`
- `bash tools/cockpit/machine_registry.sh --action list`
- `bash tools/cockpit/machine_registry.sh --action show --machine photon --json`
- `bash tools/cockpit/machine_registry.sh --action clean-logs --days 14`

## Suite prevue

- `mesh_sync_preflight.sh` doit consommer ce registre pour les roles, ports, priorites, placement et la reserve runtime
- `ssh_healthcheck.sh` doit charger ses cibles SSH directement depuis le registre et ignorer automatiquement les entrees non applicables
- le workflow `.github/workflows/mesh_contracts.yml` doit valider ce registre pour bloquer toute derive
- le runbook multi-machine reference ce registre comme source de verite operatoire