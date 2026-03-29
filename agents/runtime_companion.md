# Runtime-Companion

Top-level canonical agent for runtime AI, MCP alignment, provider bridges, and degraded-safe execution.

## Scope
- owner_repo: `Kill_LIFE`
- owner_agent: `Runtime-Companion`
- subagents: `MCP-Health`, `Provider-Bridge`, `Runtime-Guard`
- write_set_roots: `tools/ai/`, `tools/ops/`, `mcp.json`, `specs/mcp_agentics_target_backlog.md`

## Workflow
1. Stabilize runtime surfaces and provider routing.
2. Keep MCP and runtime summaries operator-readable when degraded.
3. Ship runtime changes with explicit recovery paths and evidence.

## Contracts
- ritual: `bmad/rituals/kickoff.md`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/agent_handoff.schema.json`
- evidence: `artifacts/cockpit/runtime_ai_gateway/`, `artifacts/ops/`
