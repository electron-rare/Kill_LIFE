# Agentic Landscape (Kill_LIFE)

## Posture de départ

- Spec-driven backbone: `specs/*` et `specs/constraints.yaml`
- Standards and gates: `compliance/*`, `bmad/*`
- Runtime local: `ZeroClaw` + MCP + `crazy_life` comme éditeur
- Overlays: `LangGraph`, `AutoGen`, `n8n` en option contrôlée
- Exécution locale de préférence, GitHub pour la traçabilité distante

```mermaid
flowchart TD
  Inputs[Issue / PR / demande humaine] --> Labels[Labels ai:* + Scope]
  Labels --> Router{Routeur d’exécution}
  Router --> SpecPath[specs/ (00->04)]
  Router --> GitHubPath[workflow local / GitHub dispatch]

  SpecPath --> Validation{specs + compliance}
  Validation --> Tools[tools/*]
  Tools --> RepoTools[repo_state + compliance + auto_check_ci_cd]
  Tools --> MCP[tools/hw/* + MCP launchers]
  Tools --> TUI[tools/cockpit/refonte_tui.sh]
  Tools --> CADFusion[tools/cad/yiacad_fusion_lot.sh]

  CADFusion --> CadEvidence[Evidence CAD (cad-fusion)]
  MCP --> Evidence[Evidence packs locaux]
  RepoTools --> Evidence
  CadEvidence --> Evidence
  TUI --> Logs[artifacts/refonte_tui/*.log]
  Logs --> Evidence
  Evidence --> Audit[docs/evidence/*]
  GitHubPath --> CI[.github/workflows/*]
  CI --> Audit
  Audit --> PM[PM + Plan]
  PM --> Handoff[Handoffs / Plans / Labels]
  Handoff --> Agents[agents/ + .github/agents/ + prompts]
```

## Modèle de fonctionnement

- `agents/` et `.github/agents/` définissent les compétences minimales.
- `tools/cockpit/refonte_tui.sh` est la surface de pilotage texte (status, logs, lot-chain).
- `ZeroClaw` reste le runtime local d’orchestration, sans remplacer la source de vérité.
- Les surfaces MCP sont locales par défaut, `huggingface` en option distante officielle.
- Les preuves et traces sont obligatoires pour les lots de refonte.

## Décisions de refonte actives

- pas de dépendance forte externe pour les lanes essentielles,
- tout overlay IA passe par une validation de sécurité (labels, scope, denylist),
- priorité à la reproductibilité documentaire (`specs`, `plans`, `diagrams`, `evidence`).

## Delta mesh 2026-03-20

Le paysage agentique du projet opere desormais comme un overlay de gouvernance maillée sur trois repos, avec neuf agents principaux.

| Agent | Repo owner prefere | Responsabilite |
| --- | --- | --- |
| `PM-Mesh` | `Kill_LIFE` | backlog tri-repo, priorisation, ordre de propagation |
| `Arch-Mesh` | `Kill_LIFE` | contrats inter-repos, ADR, compatibilite |
| `Embedded-CAD` | `Kill_LIFE` | firmware, hardware, evidence embarquee |
| `Runtime-Companion` | `mascarade` | runtime IA, providers, adaptateurs MCP |
| `CAD-Fusion` | `Kill_LIFE` | pilote YiACAD, health CAD, preuve et rollback |
| `Web-Cockpit` | `crazy_life` | UI cockpit, workflow editor, supervision |
| `QA-Compliance` | transversal | matrices, smokes, preuves |
| `Docs-Research` | transversal | README, specs, Mermaid, benchmark OSS |
| `SyncOps` | `Kill_LIFE` | SSH, repo-state, TUI, logs, sync continue |

Sous-agents standardises:

- `Lot-Planner`, `Risk-Triager`
- `Schema-Guard`, `Compat-Auditor`
- `Firmware-Lane`, `CAD-Lane`, `CAD-Fusion`
- `Provider-Bridge`, `Runtime-Smoke`
- `UI-Flow`, `Schema-Consumer`
- `Spec-Mirror`, `Evidence-Pack`
- `Mermaid-Map`, `OSS-Benchmark`
- `SSH-Health`, `Log-Ops`

Skills opératoires actives:

- `bash-cli-tui`: `SyncOps`, `CAD-Fusion`, `Doc-Runbook`
- `playwright`: `Web-Cockpit` quand une validation UI réelle devient nécessaire
- `OSS-Benchmark`: `Docs-Research`, `CAD-Fusion`
- `Evidence-Pack`: `QA-Compliance`, `Docs-Research`

Routing prioritaire des lots ouverts:

- `PM-Mesh` garde `T-RE-204` comme lot exécutable bloquant.
- `CAD-Fusion` tient la lane parallèle `T-RE-209` / `T-RE-210`.
- `SyncOps` publie la synthèse hebdomadaire et la checklist de sortie (`T-RE-301` / `T-RE-304`).

Regle de coexistence: nous ne sommes pas seuls dans le codebase; toute intervention doit rester dans un `write_set` declare et observable.

Matrice detaillee publiee: `docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md`

Delta d'execution machine-readable:

- `Schema-Guard` publie des schemas JSON versionnes pour `agent_handoff`, `repo_snapshot`, `workflow_handshake`.
- `Runtime-Smoke` et `Schema-Consumer` consomment ces contrats depuis la lane soeur `Kill_LIFE-main` au moment des preflights compagnons.
- La validation CI visible du handshake passe desormais par `.github/workflows/mesh_contracts.yml`.
