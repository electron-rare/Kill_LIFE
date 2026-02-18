# Anti‑Prompt‑Injection Policy

This project follows a defence‑in‑depth strategy to mitigate risks from
prompt‑injection attacks in AI‑powered automation. The following measures
help ensure that untrusted content does not steer privileged tools.

## Hierarchy of instructions

1. **Constitution and constraints** – project constitutions (`specs/template_spec.md` and
   `specs/constraints.yaml`) always take precedence over any AI agent output.
2. **Specifications and standards** – normative specs and standards define
   allowed behaviour and interfaces.
3. **Issue/PR text** – content provided by users is treated as untrusted.
4. **Agent output** – agent messages are not trusted until validated.

## Input sanitization

* **Sanitize issue/PR text**. All issue bodies, titles and comments are
  processed through `tools/ai/sanitize_issue.py` before being used in a prompt.
  This removes HTML tags, code blocks, URLs, mentions, issue references,
  email addresses and suspicious shell patterns, collapsing whitespace and
  blank lines. GitHub’s own agentic workflows sanitization pipeline
  neutralizes @mentions, blocks bot triggers and converts HTML to safe
  plaintext【420659683624566†L747-L857】【11582546369719†L160-L168】.
* **Treat agent output as untrusted**. Agent‑generated code or commands are
  run only within a constrained sandbox and are subject to linting, build
  checks, unit tests and scope guards. You should never execute arbitrary
  code emitted by an agent without human review【885973626346785†L218-L231】.

## Least privilege

* **Safe outputs**. GitHub Agentic Workflows (gh‑aw) uses safe‑outputs for
  write operations (e.g. creating a PR) so that the agent runtime itself
  never holds write access to the repository. Only the safe‑output executor
  performs writes.【420659683624566†L747-L857】.
* **Network and tool restrictions**. Agents are configured with a minimal
  toolset and strict network permissions to prevent exfiltration or misuse
  of secrets. Only specific domains are whitelisted for web access, and all
  external calls are logged.
* **OpenClaw isolation**. When using OpenClaw, run it in a sandbox and
  restrict it to benign actions (adding labels, posting comments). It must
  never have direct access to secrets or the source tree【57263998884462†L355-L419】.

## Scope enforcement

* **Label‑based scopes**. Each `ai:*` label corresponds to an allowlist of
  directories. The `tools/scope_guard.py` script validates that only
  permitted files are modified in a pull request. A denylist blocks
  sensitive files (e.g. workflows, sanitation scripts).
* **Required labels**. Pull requests must carry at least one `ai:*` label. A
  GitHub workflow automatically adds `ai:impl` if none is present, and then
  enforces that at least one label exists. This ensures the scope guard has
  a basis for evaluation.

## Incident handling

If a prompt injection is suspected (e.g. the scope guard reports forbidden
changes or the sanitizer removes large sections of an issue), follow these
steps:

1. Add the `ai:hold` label to stop all automated processing on the PR or
   issue.
2. Rotate any exposed tokens or credentials immediately.
3. Conduct a manual review of the issue/PR content and agent outputs.
4. Improve the sanitizer or scope definitions if necessary.