#!/usr/bin/env python3
"""Compose a Codex prompt from repo context + sanitized issue."""
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]

def read(p: str) -> str:
  fp = BASE / p
  if not fp.exists():
    print(f"error: required file not found: {fp}", file=sys.stderr)
    raise SystemExit(2)
  return fp.read_text(encoding="utf-8", errors="replace")

def main():
  if len(sys.argv) != 3:
    print("usage: compose_codex_prompt.py <issue_txt> <out_prompt_md>", file=sys.stderr)
    return 2
  issue_path = Path(sys.argv[1])
  if not issue_path.exists():
    print(f"error: issue file not found: {issue_path}", file=sys.stderr)
    return 2
  issue = issue_path.read_text(encoding="utf-8", errors="replace")
  base = read(".github/codex/prompts/issue_to_pr_base.md")
  out = (
    base
    + "\n\n## Repo context pointers\n"
    + "- constraints: `specs/constraints.yaml`\n"
    + "- specs flow: `specs/README.md`\n"
    + "- standards: `standards/README.md`\n"
    + "- BMAD gates: `bmad/gates/gate_s0.md`, `bmad/gates/gate_s1.md`\n"
    + "\n\n-----BEGIN_ISSUE_TEXT-----\n"
    + issue
    + "\n-----END_ISSUE_TEXT-----\n"
  )
  Path(sys.argv[2]).write_text(out, encoding="utf-8")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
