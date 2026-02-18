#!/usr/bin/env python3
"""Sanitize issue text before feeding to an AI prompt (reduce prompt-injection surface)."""
import re, sys

def strip_html_comments(s: str) -> str:
  return re.sub(r"<!--.*?-->", "", s, flags=re.DOTALL)

def collapse_ws(s: str) -> str:
  s = s.replace("\r\n", "\n").replace("\r", "\n")
  s = re.sub(r"\n{4,}", "\n\n\n", s)
  return s.strip()

def main():
  if len(sys.argv) != 3:
    print("usage: sanitize_issue.py <infile> <outfile>", file=sys.stderr)
    return 2
  inp = open(sys.argv[1], "r", encoding="utf-8").read()
  out = collapse_ws(strip_html_comments(inp))
  open(sys.argv[2], "w", encoding="utf-8").write(out + "\n")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
