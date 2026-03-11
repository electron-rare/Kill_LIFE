# Kill_LIFE Workflow GitHub Sequence - 2026-03-11

## Scope

Ce diagramme fixe la sequence canonique quand un workflow `Kill_LIFE` quitte la machine operateur pour passer par le dispatch GitHub et revenir sous forme de statut et d'evidence pack.

## Sequence

```mermaid
sequenceDiagram
    autonumber
    participant OP as Operateur / crazy_life
    participant WF as workflows/*.json
    participant MCP as tools/github_dispatch_mcp.py
    participant AL as allowlist dispatch
    participant GH as GitHub Actions API
    participant CI as .github/workflows/ci.yml
    participant RS as repo_state.yml
    participant EV as evidence_pack.yml
    participant REL as release_signing.yml
    participant ART as GitHub artifacts + docs/*

    OP->>WF: choisir un workflow canonique versionne
    OP->>MCP: dispatch_workflow(workflow_file, ref, inputs)
    MCP->>AL: verifier workflow allowliste + secrets disponibles
    AL-->>MCP: autorisation / refus structure

    alt workflow non allowliste ou secret manquant
        MCP-->>OP: erreur structuree missing_secret / dispatch_failed
    else workflow autorise
        MCP->>GH: workflow_dispatch sur ref cible
        GH-->>MCP: accepted + dispatch_id
        MCP-->>OP: dispatch accepte, id de suivi

        OP->>MCP: get_dispatch_status(dispatch_id)
        MCP->>GH: resoudre le run cible
        GH-->>MCP: statut queued / in_progress / completed
        MCP-->>OP: statut structure du run

        par gates standards
            GH->>CI: lancer la suite stable Python
            CI-->>ART: logs de suite stable / gate principal
        and etat du depot
            GH->>RS: generer repo_state
            RS-->>ART: docs/REPO_STATE.md + docs/repo_state.json
        and preuves
            GH->>EV: valider ou produire le rapport evidence pack
            EV-->>ART: artifact evidence-pack
        end

        opt workflow de release
            GH->>REL: release_signing sur tag ou workflow_dispatch
            REL-->>ART: artefact signe + release GitHub
        end

        GH-->>OP: checks, artifacts, eventuelle release
    end
```

## Anchors

| Surface | Role dans la sequence GitHub |
| --- | --- |
| `workflows/*.json` | choix de la lane et parametrage amont |
| `tools/github_dispatch_mcp.py` | serveur MCP local qui cadre `list_allowlisted_workflows`, `dispatch_workflow`, `get_dispatch_status` |
| `tools/run_github_dispatch_mcp.sh` | launcher stdio du dispatch GitHub |
| `.github/workflows/ci.yml` | gate principal `python-stable` sur la branche ou la PR |
| `.github/workflows/repo_state.yml` | photographie exploitable du repo et artefacts de statut |
| `.github/workflows/evidence_pack.yml` | validation/production du rapport evidence pack |
| `.github/workflows/release_signing.yml` | chemin de release signee par tag ou `workflow_dispatch` |
| `docs/evidence/evidence_pack.md` | contrat minimal de contenu d'un evidence pack |

## Reading

- La machine operateur ne pousse pas elle-meme une logique arbitraire; elle demande le dispatch d'un workflow allowliste.
- Le retour utile n'est pas seulement `success/fail`, mais un ensemble de checks, artefacts et preuves consultables.
- `Kill_LIFE` garde la definition canonique des workflows et de leurs gates; le dispatch n'est qu'un mode d'execution distant.

## Next lots

- `K-DA-003` est ferme par ce diagramme versionne.
- `K-DA-004`: resynchroniser plus largement README et docs/plans autour des deux sequences `local` et `github`.
- `K-DA-005`: synchroniser la doc operateur avec les preuves et artefacts effectivement exposes.
