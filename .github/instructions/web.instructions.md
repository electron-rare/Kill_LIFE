---
description: "Use when changing YiACAD web frontend, GraphQL schema/client, workers, realtime, PR review surfaces, or queue orchestration under web/."
name: "Web Domain"
applyTo: "web/**"
---
# Web Domain Instructions

## Focus

- Preserve compatibility between GraphQL schema, client queries, and UI types.
- Keep worker outputs aligned with backend normalized payloads.

## Verify With

- `cd web && npm ci`
- `cd web && npm run build`
- Run relevant contract tests in `test/test_yiacad_web_*`.

## Guardrails

- Do not hardcode fallback assumptions that hide missing runtime configuration.
- Maintain explicit status and summary surfaces for CI/review cards.
- Keep artifact paths and evidence links consumable by operators.
