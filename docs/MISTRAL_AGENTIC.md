# Mistral Agentic Workflow (Safe Outputs)

## Goal
Use Mistral models for agentic tasks **without giving the model unsafe agency**.

## Pattern used
1) Sanitize untrusted inputs (issues/comments/logs)
2) Ask the model for a structured **SafePatch JSON**
3) Validate JSON against a schema
4) Apply changes with scope allowlists + deny globs
5) Verify manually/CI (never auto-execute model output)

## Why JSON mode
Mistral supports JSON mode by setting `response_format={"type":"json_object"}` which enforces valid JSON.

## Commands
Generate:
```bash
python tools/mistral/mistral_generate_patch.py --model codestral-latest --scope ai:spec --request "..." --out /tmp/patch.json
```

Apply:
```bash
python tools/mistral/apply_safe_patch.py --scope ai:spec --patch /tmp/patch.json
```

## Tool calling (optional)
Mistral supports function calling. If you use it:
- keep tools read-only by default
- allow writes only through SafePatch
- never expose arbitrary shell execution as a tool
