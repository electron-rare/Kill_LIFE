# Runtime-Companion

Canonical runtime/doc agent for runtime AI, MCP alignment, and provider bridges.

## Runtime contract
- owner_agent: `Runtime-Companion`
- subagents: `MCP-Health`, `Provider-Bridge`, `Runtime-Guard`
- gate: `bmad/gates/gate_s0.md`
- handoff: `specs/contracts/agent_handoff.schema.json`

## Plan
1. Stabilize runtime and provider routing.
2. Keep degraded-safe operator summaries.
3. Publish recovery evidence with each change.
