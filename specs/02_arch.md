# Architecture

## Diagramme bloc
```mermaid
flowchart TD
  Intake[00 Intake] --> Spec[01 Spec]
  Spec --> Arch[02 Arch]
  Arch --> Plan[03 Plan]
  Arch --> Tasks[04 Tasks]
  Plan --> Cockpit[tools/cockpit/refonte_tui.sh]
  Plan --> Docs[docs/plans/*]
  Plan --> Specs[specs/*]
  Cockpit --> Logs[artifacts/refonte_tui/*.log]
  Docs --> DocsReview[docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md]
  MCP[MCP Servers] --> Tools[tools/*]
  Tools --> Evidence[artifacts/*]
  Evidence --> CI[.github/workflows]
  AI[AI overlays] -->|optional| Tools
  AI -->|advisory| Docs
```

## ADR (Décisions)
- ADR-001: Conserver une chaîne spec-first stricte comme source de vérité, avec AI en overlay et gates non optionnels.
- ADR-002: Mutualiser la gouvernance via des plans canoniques (`docs/plans/*`, `specs/04_tasks.md`) et un manifeste de refonte dédié.
- ADR-003: Préférer les intégrations MCP/supportées déjà répertoriées avant d’introduire de nouvelles briques.
- ADR-004: Imposer une boucle logs opérationnelle (write/read/cleanup) pour tout lot auto.

## Énergie
- States du lot:
  - `planning`: mise à jour des priorités
  - `execution`: lot automatique ou manuel en cours
  - `validation`: commandes de validation déclenchées
  - `stabilization`: analyse logs + mise à jour des plans
- Wake sources:
  - changement de specs/plans
  - divergence docs ↔ source
  - gate bloquant dans le lot

## Risques & mitigations
- Risque de dérive AI: mitigation par gates, contraintes réseau, sortie manuelle sur lots critiques.
- Risque de doublons logs: mitigation par politique de rétention et nommage horaire.
- Risque de désynchronisation plan/spec: mitigation par script de revue README + chain plan.
