# Kill_LIFE Workflow Local Sequence - 2026-03-20

## Scope

Canonical sequence de validation locale quand un workflow `Kill_LIFE` est édité, validé puis exécuté en local.

## Sequence

```mermaid
sequenceDiagram
    autonumber
    participant OP as Opérateur / crazy_life
    participant TUI as tools/cockpit/refonte_tui.sh
    participant WF as workflows/*.json
    participant SCHEMA as workflow.schema.json
    participant VS as tools/validate_specs.py
    participant COMP as tools/compliance/validate.py
    participant MCP as tools/mcp_runtime_status.py
    participant RUNTIME as tools/cad_runtime.py / tools/hw/*
    participant LOG as artifacts/refonte_tui/*.log
    participant EVID as docs/evidence / compliance/evidence

    OP->>WF: edit / créer workflow canonique
    OP->>SCHEMA: valider schéma
    SCHEMA-->>OP: valide / invalide
    OP->>VS: lancer validation spec-first
    VS-->>OP: synthèse OK / FAIL
    OP->>COMP: lancer validation conformité
    COMP-->>OP: profile actif + blockers
    OP->>MCP: vérifier prérequis MCP/CAD locaux
    MCP-->>OP: statut runtime local

    alt workflow implique hardware/CAD
        OP->>RUNTIME: lancer doctor / export / smoke / schops
        RUNTIME-->>OP: artefacts locaux
    end

    alt opérateur lance via TUI
        OP->>TUI: lancer readme_audit / lot-chain / status
        TUI->>LOG: écrire log
        TUI-->>OP: sortie + état
    end

    OP->>EVID: déposer preuves locales
    EVID-->>OP: dossiers exploitables pour revue
```

## Anchors

| Surface | Role |
| --- | --- |
| `workflows/*.json` | définition executable et versionnée |
| `workflow.schema.json` | vérification structurelle |
| `tools/validate_specs.py` | garde-fou spec-first |
| `tools/compliance/validate.py` | validation profile + compliance |
| `tools/mcp_runtime_status.py` | état des runtimes MCP/CAD |
| `tools/hw/*` | actions hardware/CAD si workflow dépendant |
| `tools/cockpit/refonte_tui.sh` | exécute lot-chain et garde les logs |
| `artifacts/refonte_tui/*.log` | lecture/analyse/suppression contrôlée |
| `docs/evidence/*` | preuves pour revue |

## Reading

- La validation locale est un prérequis, pas un remplacement de la validation GitHub.
- `KILL_LIFE` garde la source de vérité des workflows et règles de validation.
- Le TUI agit comme couche opératoire uniforme pour status, logs et lots.

## Next lots

- `K-DA-002` est fermé par ce diagramme versionné.
- `K-RE-002` fermera la dette cartes/séquences restantes.
- Enchaîner ensuite avec `K-DA-003` côté GitHub.
