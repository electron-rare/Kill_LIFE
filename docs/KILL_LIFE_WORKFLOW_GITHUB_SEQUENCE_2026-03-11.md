# Kill_LIFE Workflow GitHub Sequence - 2026-03-20

## Scope

Diagramme canonique de la sortie locale vers GitHub Actions, puis retour état + evidence pack.

## Sequence

```mermaid
sequenceDiagram
    autonumber
    participant OP as Opérateur / crazy_life
    participant WF as workflows/*.json
    participant MCP as tools/github_dispatch_mcp.py
    participant AL as allowlist dispatch
    participant GH as GitHub Actions API
    participant CI as .github/workflows/ci.yml
    participant RS as repo_state.yml
    participant EV as evidence_pack.yml
    participant REL as release_signing.yml
    participant LOG as artifacts/refonte_tui/*.log
    participant ART as GitHub artifacts + docs/*

    OP->>WF: sélectionner workflow canonique
    OP->>MCP: dispatch_workflow(workflow_file, ref, inputs)
    MCP->>AL: vérifier allowlist + secrets
    AL-->>MCP: autorisation / refus

    alt workflow non allowlist ou secret manquant
        MCP-->>OP: refus + code d’erreur
    else workflow autorisé
        MCP->>GH: workflow_dispatch
        GH-->>MCP: accepted + run id
        MCP-->>OP: suivi d’exécution
        OP->>MCP: get_dispatch_status(run id)
        MCP->>GH: résoudre le run target
        GH-->>MCP: queued / in_progress / completed
        MCP-->>OP: statut + checks

        par gates standards
            GH->>CI: exécuter test/lint/stable
            CI-->>ART: logs + step summary
        and état du dépôt
            GH->>RS: régénérer repo_state
            RS-->>ART: docs/REPO_STATE.md + docs/repo_state.json
        and preuve
            GH->>EV: exécuter chaîne evidence
            EV-->>ART: `artifacts/evidence-pack`
        end

        opt workflow de release
            GH->>REL: release_signing
            REL-->>ART: signature + release
        end

        GH-->>OP: checks + artefacts + eventuels releases
    end
```

## Anchors

| Surface | Rôle |
| --- | --- |
| `tools/run_github_dispatch_mcp.sh` | façade locale pour l’allowlist dispatch |
| `.github/workflows/ci.yml` | gate principal python-stable |
| `.github/workflows/repo_state.yml` | photo d’état de repo |
| `.github/workflows/evidence_pack.yml` | lane evidence pack et preuve synthétique |
| `.github/workflows/release_signing.yml` | signature éventuelle |
| `docs/evidence/evidence_pack.md` | contrat de lecture des preuves |
| `docs/EVIDENCE_ALIGNMENT_2026-03-11.md` | alignement CI ↔ doc ↔ réalité |
| `tools/repo_state/repo_refresh.sh` | génération du header global |

## Reading

- Le dispatch GitHub reste la seule voie de validation distante systématique.
- Le retour attendu n’est pas binaire, il inclut check, artefacts et proof summary.
- Le repo-state header est lu depuis `artifacts/repo_state/header.latest.md` et doit contenir au minimum `Kill_LIFE`.
- Les logs TUI (`artifacts/refonte_tui/*.log`) servent au postmortem d’exécution.

## Next lots

- `K-DA-003` clos par ce diagramme.
- `K-DA-004`: synchroniser les docs opérateur avec les preuves exposées.
- `K-DA-006`, `K-DA-007`: conserver comme preuve continue via `tools/repo_state/*`.
