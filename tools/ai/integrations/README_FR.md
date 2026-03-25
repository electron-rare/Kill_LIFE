# ZeroClaw Integrations

ZeroClaw remains in scope as the local operator stack for Kill_LIFE.

This directory is synced by `tools/ai/zeroclaw_stack_up.sh` into
`artifacts/zeroclaw/integrations/`, then served by the follow UI.

Current integration posture:

- `ZeroClaw`: kept as the local operator stack entrypoint.
- `n8n`: kept as an external automation bridge and workflow handoff surface.
- `LangGraph`: kept as an optional orchestration pattern, not the default runtime.
- `AutoGen`: kept as an optional multi-agent experimentation path.

These integrations are intentionally documented as operator runbooks. They are
not required for the canonical repo-local stable path.

Operator posture:

- `ZeroClaw` runtime is started on demand via `tools/ai/zeroclaw_stack_up.sh`.
- `zeroclaw.saillant.cc` is the live runtime surface when the native stack is up.
- `zeroclaw-docs.saillant.cc` serves the ZeroClaw runbooks behind the
  authenticated `edge-proxy`.
- `langgraph.saillant.cc` serves the LangGraph runbook behind the authenticated
  `edge-proxy`.
- When the local `ZeroClaw` runtime is stopped, `zeroclaw.saillant.cc` should
  present an operator-friendly offline page instead of raw proxy errors.

Available runbooks:

- [`zeroclaw/README.md`](zeroclaw/README.md)
- [`n8n/README.md`](n8n/README.md)
- [`langgraph/README.md`](langgraph/README.md)
- [`autogen/README.md`](autogen/README.md)

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
