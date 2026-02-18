#!/usr/bin/env python3
"""Compose a Codex prompt from repo context + sanitized issue."""
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parents[2]

def read(p: str) -> str:
  return (BASE / p).read_text(encoding="utf-8")

def main():
  if len(sys.argv) != 3:
    print("usage: compose_codex_prompt.py <issue_txt> <out_prompt_md>", file=sys.stderr)
    return 2
  issue = Path(sys.argv[1]).read_text(encoding="utf-8")
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
