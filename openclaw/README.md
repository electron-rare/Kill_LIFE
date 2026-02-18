# OpenClaw Integration

This repository includes optional integration points for **OpenClaw**, a local
agent runtime that allows an operator to trigger automations via chat or other
human‑in‑the‑loop interfaces. In this template, OpenClaw is used solely as
a *viewer* and *label manager*:

* OpenClaw **does not commit or push code**. Any actions that modify the
  repository must be performed via GitHub Agentic Workflows (gh‑aw) with
  safe‑outputs. This keeps the write surface minimal and auditable.
* The only allowed actions are adding/removing `ai:*` labels on issues and
  pull requests, and posting sanitized status comments. All comments are
  processed through `tools/ai/sanitize_issue.py` before being sent.
* OpenClaw must run in a sandbox or disposable environment with no access to
  secrets, following the principle of least privilege. Running OpenClaw on
  the same machine as your source code or CI system is *strongly
  discouraged*【57263998884462†L355-L419】.

Refer to `docs/security/anti_prompt_injection_policy.md` for more details on
the defensive measures and threat model.