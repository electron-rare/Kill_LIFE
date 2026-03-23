# Mesh Contracts Spec

Version: `mesh-contract/v1`
Date: `2026-03-20`

## Scope

Cette spec regroupe les contrats publics minimaux necessaires au fonctionnement tri-repo maillé entre `Kill_LIFE`, `mascarade` et `crazy_life`.

## MCP Status Contract

| Value | Meaning | Required behavior |
| --- | --- | --- |
| `ready` | runtime operationnel | outils exposes, dependances critiques presentes |
| `degraded` | operation partielle acceptable | outils/services exposes sans crash silencieux, dependance non critique absente |
| `blocked` | operation impossible ou interdite | justification explicite, aucune ambiguite pour l'operateur |

## Agent Handoff Contract

Required keys:

- `lot_id`
- `owner_repo`
- `owner_agent`
- `write_set`
- `preflight`
- `validations`
- `evidence`
- `sync_targets`

## Repo Snapshot Contract

Required keys:

- `machine`
- `repo`
- `branch`
- `sha`
- `remote`
- `dirty_set`
- `required_script`
- `ssh_health`

## Workflow Schema Handshake

- versioning obligatoire
- compat ascendante par defaut
- validation croisee `Kill_LIFE` producteur / `crazy_life` consommateur
- preuve de smoke pour tout changement de schema

## Artefacts machine-readables

Schemas publies:

- `specs/contracts/agent_handoff.schema.json`
- `specs/contracts/repo_snapshot.schema.json`
- `specs/contracts/workflow_handshake.schema.json`

Exemples d'instances:

- `specs/contracts/examples/agent_handoff.mesh.json`
- `specs/contracts/examples/repo_snapshot.mesh.json`
- `specs/contracts/examples/workflow_handshake.mesh.json`

Checker local:

- `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/agent_handoff.schema.json --instance specs/contracts/examples/agent_handoff.mesh.json`
- `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/repo_snapshot.schema.json --instance specs/contracts/examples/repo_snapshot.mesh.json`
- `python3 tools/specs/mesh_contract_check.py --schema specs/contracts/workflow_handshake.schema.json --instance specs/contracts/examples/workflow_handshake.mesh.json`

## Concurrency Contract

- aucun write hors `write_set`
- aucun revert de changement externe
- tout conflit ou drift relance `preflight -> refresh -> replan`
