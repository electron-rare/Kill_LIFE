#!/usr/bin/env python3
"""Sanitize issue text before feeding to an AI prompt (reduce prompt-injection surface)."""
import re, sys

def strip_html_comments(s: str) -> str:
  return re.sub(r"<!--.*?-->", "", s, flags=re.DOTALL)

def collapse_ws(s: str) -> str:
  """
  Collapse consecutive newlines and trim surrounding whitespace.

  - Convert Windows and old‑style Mac newlines to `\n`.
  - Reduce runs of 4+ blank lines to at most 3.
  - Strip leading and trailing whitespace.
  """
  s = s.replace("\r\n", "\n").replace("\r", "\n")
  s = re.sub(r"\n{4,}", "\n\n\n", s)
  return s.strip()

def remove_code_blocks(s: str) -> str:
  """
  Remove fenced and indented code blocks and inline code from markdown.

  Code blocks are common places to hide prompt‑injection payloads. This function
  strips content between triple backtick fences (```) as well as indented
  blocks and inline backtick code. The goal is to prevent the agent from
  receiving or acting on embedded commands.
  """
  # Strip triple backtick blocks (```...```)
  s = re.sub(r"```.*?```", "", s, flags=re.DOTALL)
  # Strip indented blocks (lines starting with four spaces or a tab)
  s = re.sub(r"(?m)^(    |\t).*$", "", s)
  # Strip inline backtick content (e.g. `cmd`)
  s = re.sub(r"`[^`]*`", "", s)
  return s

def strip_html_tags(s: str) -> str:
  """Remove all HTML tags from the input."""
  return re.sub(r"<[^>]+>", "", s)

def neutralize_mentions_and_refs(s: str) -> str:
  """
  Replace user mentions, issue/PR references and email addresses with safe
  placeholders. This prevents the agent from pinging users or closing issues
  inadvertently when the sanitized text is used in a prompt.
  """
  s = re.sub(r"@\w+", "[at]", s)
  s = re.sub(r"#[0-9]+", "[issue]", s)
  # Remove email addresses
  s = re.sub(r"\b[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}\b", "[email]", s)
  return s

def remove_urls(s: str) -> str:
  """
  Remove HTTP/HTTPS URLs entirely. External links should never be blindly
  forwarded to an agent; only explicit whitelisted domains should be allowed
  by higher‑level sanitizers. At this stage, strip them to neutral tokens.
  """
  return re.sub(r"https?://\S+", "[url]", s)

def remove_suspicious_patterns(s: str) -> str:
  """
  Remove lines containing obvious shell commands or prompt‑injection markers.

  Lines starting with `!`, `$` or `%%` or containing dangerous commands such as
  `sudo`, `rm -rf`, `curl`, `wget`, `bash` or `powershell` are dropped. This
  heuristic is intentionally conservative and errs on the side of removal.
  """
  lines = []
  for line in s.split("\n"):
    stripped = line.strip()
    if (
        stripped.startswith(("!", "$", "%"))
        or re.search(r"\b(sudo|rm\s+-rf|curl\s+|wget\s+|bash\s+|powershell\s+)\b", stripped, re.IGNORECASE)
    ):
      continue
    lines.append(line)
  return "\n".join(lines)

def sanitize_text(s: str) -> str:
  """
  Apply all sanitization stages in order. The pipeline:

  1. Remove HTML comments (already done by `strip_html_comments`).
  2. Remove fenced/indented/inline code blocks.
  3. Strip remaining HTML tags.
  4. Neutralize mentions, issue references and email addresses.
  5. Remove lines with suspicious shell patterns.
  6. Strip URLs.
  7. Collapse whitespace and blank lines.

  Returns the sanitized string.
  """
  s = strip_html_comments(s)
  s = remove_code_blocks(s)
  s = strip_html_tags(s)
  s = neutralize_mentions_and_refs(s)
  s = remove_suspicious_patterns(s)
  s = remove_urls(s)
  return collapse_ws(s)

def main():
  if len(sys.argv) != 3:
    print("usage: sanitize_issue.py <infile> <outfile>", file=sys.stderr)
    return 2
  inp = open(sys.argv[1], "r", encoding="utf-8").read()
  out = sanitize_text(inp)
  open(sys.argv[2], "w", encoding="utf-8").write(out + "\n")
  return 0

if __name__ == "__main__":
  raise SystemExit(main())
