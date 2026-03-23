# YiACAD Apple-native UI/UX Feature Map - 2026-03-20

## Carte fonctionnelle

```mermaid
flowchart TD
    YIACAD[YiACAD Apple-native shell]

    YIACAD --> NAV[Navigation Sidebar]
    YIACAD --> TOOLBAR[Semantic Toolbar]
    YIACAD --> PALETTE[Command Palette]
    YIACAD --> CANVAS[ECAD / MCAD Canvas]
    YIACAD --> INSPECTOR[Context Inspector]
    YIACAD --> REVIEW[Review Center]
    YIACAD --> ARTIFACTS[Artifacts & Logs]
    YIACAD --> AI[AI Assist Layer]

    NAV --> PROJECT[Project Overview]
    NAV --> BOM[BOM Review]
    NAV --> ERCDRC[ERC / DRC Review]
    NAV --> SYNC[ECAD / MCAD Sync]
    NAV --> HISTORY[Lots / History]

    TOOLBAR --> SEARCH[Search / Filter]
    TOOLBAR --> STATUS[Status]
    TOOLBAR --> ACTIONS[Primary actions]

    PALETTE --> CMD_REVIEW[review.erc_drc]
    PALETTE --> CMD_BOM[review.bom]
    PALETTE --> CMD_SYNC[sync.ecad_mcad]
    PALETTE --> CMD_EXPLAIN[ai.explain]
    PALETTE --> CMD_ARTIFACTS[open.artifacts]

    REVIEW --> WARNINGS[Warnings grouped by severity]
    REVIEW --> DIGEST[AI digest]
    REVIEW --> SOURCES[Evidence links]
    REVIEW --> RESULT_CARD[Normalized result card]

    AI --> SUGGEST[Suggested fixes]
    AI --> SUMMARIZE[Summaries]
    AI --> TRACE[Traceability / provenance]

    ARTIFACTS --> LOGS[Logs]
    ARTIFACTS --> REPORTS[Markdown reports]
    ARTIFACTS --> EXPORTS[STEP / BOM / ERC / DRC]
    RESULT_CARD --> SEVERITY[Severity]
    RESULT_CARD --> NEXT[Next steps]
    RESULT_CARD --> CONTRACT[done | degraded | blocked]
```

## Surfaces

| Surface | Rôle | État |
| --- | --- | --- |
| Navigation Sidebar | point d’entrée orienté tâches | à intégrer dans les forks natifs |
| Semantic Toolbar | recherche, statut, action principale | à intégrer dans les forks natifs |
| Command Palette | actions transverses unifiées | première palette légère livrée dans les surfaces YiACAD natives; intégration shell profonde ouverte |
| Review Center | centraliser `ERC`, `DRC`, `BOM`, `sync` | regroupement léger livré dans les surfaces YiACAD; consolidation multi-surface ouverte |
| Context Inspector | détail, explication IA, provenance | partiellement disponible: dock persistant FreeCAD + sortie inspecteur KiCad |
| Artifacts Browser | accès direct aux preuves et exports | partiellement disponible |
| UI/UX TUI | pilotage audit, synthèse, purge logs | disponible via script dédié |
| Output Contract | carte de résultat normalisée pour `status`, `severity`, `artifacts`, `next_steps` | publié dans `docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md` + `specs/contracts/yiacad_uiux_output.schema.json` |

## Canon des lots

- `T-UX-003`: montée native progressive vers les points d’insertion shell/workbench documentés.
- `T-UX-004`: contrat `command palette + inspector persistant` d’abord dans les surfaces déjà contrôlées par YiACAD.
- `UI/UX TUI`: support ops livré, hors numérotation canonique `T-UX-003`.

## Delta 2026-03-20 22:49 - output contract

- `T-UX-004B` publie le contrat de sortie UX commun pour les actions YiACAD.
- Le contrat normalise `status`, `severity`, `summary`, `details`, `artifacts`, `next_steps`, `surface`, `context_ref` et `execution_mode`.
- Les preuves canoniques deviennent:
  - `docs/YIACAD_UIUX_OUTPUT_CONTRACT_2026-03-20.md`
  - `specs/contracts/yiacad_uiux_output.schema.json`
  - `specs/contracts/examples/yiacad_uiux_output.example.json`
