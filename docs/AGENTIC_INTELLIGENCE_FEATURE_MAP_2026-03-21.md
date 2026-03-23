# Feature map - integration intelligence agentique (2026-03-21)

## Vue d'ensemble

```mermaid
mindmap
  root((Intelligence Program))
    Sources de verite
      Audit consolidation
      Spec integration intelligence
      Plan 22
      TODO 22
      Veille OSS
    Cockpit
      intelligence_tui
      compatibility alias
      refonte_tui bridge
      logs
      memory latest
      next actions
      purge
      contrat cockpit-v1
    Gouvernance agents
      PM-Mesh
      Docs-Research
      Studio-Product
      Mesh-Contracts
      Operator-Lane
      Runtime-Companion
      QA-Compliance
      OSS-Watch
    Integrations IA
      MCP
      LangGraph
      OpenAI Agents SDK
      Roo Code patterns
      OpenHands packaging
    Extensions
      Studio
      Mesh
      Operator
```

## Carte fonctionnelle

```mermaid
flowchart LR
  Docs["README / docs/index / AI_WORKFLOWS"] --> TUI["intelligence_tui.sh"]
  Plans["Plan 22 / TODO 22 / plan agents"] --> TUI
  Research["WEB_RESEARCH_OPEN_SOURCE"] --> TUI
  Tasks["specs/04_tasks.md"] --> TUI
  TUI --> Logs["artifacts/cockpit/intelligence_program/*.log"]
  TUI --> Memory["latest.json + latest.md"]
  TUI --> JSON["status --json (cockpit-v1)"]
  JSON --> Automation["automation / scripts / CI locale"]
  TUI --> Refonte["refonte_tui.sh --action intelligence-*"]
```

## Priorites de livraison

1. surface TUI + logs + contrat JSON
2. memoire + next-actions
3. plan/todo/owners a jour
4. veille 2026 exploitable
5. raccord docs index + README cockpit
6. tests de contrat
