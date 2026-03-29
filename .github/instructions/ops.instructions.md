---
description: "Use when operating cockpit scripts, runtime gateways, evidence packs, incident briefs, weekly summaries, or operational runbooks in Kill_LIFE."
name: "Ops Domain"
applyTo: ["tools/cockpit/**", "artifacts/**", "docs/evidence/**", ".github/workflows/**"]
---
# Ops Domain Instructions

## Focus

- Prefer operational observability over assumptions.
- Keep outputs machine-readable (`--json`) and operator-readable (short markdown digest).

## Priority Commands

- `bash tools/cockpit/runtime_ai_gateway.sh --action status --refresh --json`
- `bash tools/cockpit/render_weekly_refonte_summary.sh`
- `bash tools/cockpit/render_mascarade_incident_brief.sh`

## Guardrails

- Never drop evidence artifacts silently.
- Keep CI/workflow naming and artifact naming stable when possible.
- On degraded states, always provide next executable remediation steps.
