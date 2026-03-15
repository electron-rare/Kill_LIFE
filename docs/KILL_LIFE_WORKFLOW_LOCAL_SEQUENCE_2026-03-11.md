# Kill_LIFE Workflow Local Sequence - 2026-03-11

## Scope

Ce diagramme fixe la sequence locale canonique quand un workflow `Kill_LIFE` est edite, valide et execute sans passage par le dispatch GitHub.

## Sequence

```mermaid
sequenceDiagram
    autonumber
    participant OP as Operateur / crazy_life
    participant WF as workflows/*.json
    participant SCHEMA as workflow.schema.json
    participant VS as tools/validate_specs.py
    participant COMP as tools/compliance/validate.py
    participant RUNTIME as tools/mcp_runtime_status.py
    participant CAD as tools/cad_runtime.py / tools/hw/*
    participant RUNS as .crazy-life/runs
    participant EVID as docs/evidence / compliance/evidence

    OP->>WF: creer ou modifier un workflow canonique
    OP->>SCHEMA: valider la structure JSON du workflow
    SCHEMA-->>OP: workflow structurellement valide / invalide

    OP->>VS: lancer la validation spec-first
    VS->>VS: verifier 03_plan / 04_tasks / constraints / RFC2119
    VS-->>OP: synthese OK / FAIL + ecarts

    OP->>COMP: lancer la validation compliance
    COMP->>COMP: charger active_profile + standards + evidence attendues
    COMP-->>OP: statut compliance et blockers

    OP->>RUNTIME: verifier les prerequis MCP/runtime locaux
    RUNTIME-->>OP: statut global, blockers, optional degraded

    alt workflow implique du CAD ou du hardware
        OP->>CAD: lancer doctor / export / smoke / schops
        CAD-->>OP: artefacts locaux et statut outillage
    end

    OP->>RUNS: ecrire le run local et son etat
    RUNS-->>OP: historique local / restore possible

    OP->>EVID: deposer les preuves locales utiles
    EVID-->>OP: evidence pack exploitable pour revue ou bascule GitHub
```

## Anchors

| Surface | Role dans la sequence locale |
| --- | --- |
| `workflows/*.json` | definition executable et versionnee de la lane |
| `workflows/workflow.schema.json` | validation structurelle avant execution |
| `tools/validate_specs.py` | garde spec-first locale |
| `tools/compliance/validate.py` | validation du profil actif et des preuves attendues |
| `tools/mcp_runtime_status.py` | lecture de sante des runtimes MCP/CAD locaux |
| `tools/cad_runtime.py` et `tools/hw/*` | actions locales hardware/CAD quand le workflow en depend |
| `.crazy-life/runs/` | etat local des runs depuis l'editeur `crazy_life` |
| `.crazy-life/backups/workflows/` | revisions et restores locaux non versionnes |
| `docs/evidence/` et `compliance/evidence/` | sortie documentaire exploitable pour revue et transition release |

## Reading

- La validation locale ne remplace pas le dispatch GitHub; elle sert de sas avant CI distante.
- `Kill_LIFE` conserve la source de verite des workflows et des regles de validation.
- `crazy_life` joue le role d'editeur et d'operateur local, mais les artefacts canoniques restent dans `Kill_LIFE`.

## Next lots

- `K-DA-002` est ferme par ce diagramme versionne.
- `K-DA-003`: sequence `workflow github` avec allowlist dispatch et evidence pack CI.
- `K-DA-004`: synchroniser README et doc operateur autour des deux diagrammes `local` et `github`.
