# LangGraph Runbook

`LangGraph` stays in scope as an optional orchestration layer around
`ZeroClaw`.

Use it when you want:

- explicit graph-shaped control flow
- checkpointed or resumable orchestration
- a graph runtime separated from the canonical repo workflows

Current posture in Kill_LIFE:

- `ZeroClaw` remains the local operator stack.
- `LangGraph` is retained as an integration pattern, not as the default
  runtime path.
- No `LangGraph` service is wired into the main `mascarade` stack by default.

Recommended role split:

- `ZeroClaw`: local gateway, operator UX, prompts, pairing, follow UI
- `LangGraph`: optional orchestration graph for complex flows
- repo workflows / evidence: canonical tracked outputs

If this path is reactivated, add the concrete graph app or runner as tracked
artifacts in `tools/ai/` or a dedicated submodule, then link it from here.
