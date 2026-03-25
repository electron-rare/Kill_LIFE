#!/usr/bin/env python3
"""
validate_dataset.py — Validate JSONL datasets for Mistral fine-tuning format.

Checks:
- Valid JSON per line
- Messages array present with correct structure
- Role alternation (user/assistant, optional system first)
- Token count estimation
- Duplicate detection
- Content length distribution

Usage:
    python3 validate_dataset.py datasets/kicad/train.jsonl
    python3 validate_dataset.py datasets/kicad/train.jsonl --verbose
    python3 validate_dataset.py datasets/kicad/train.jsonl --strict
    python3 validate_dataset.py --batch datasets/*/train.jsonl
"""

import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path


# ---------------------------------------------------------------------------
# Token estimation
# ---------------------------------------------------------------------------

def estimate_tokens(text: str) -> int:
    """Rough token count: ~4 chars per token for English technical text."""
    return max(1, len(text) // 4)


def estimate_message_tokens(messages: list[dict]) -> int:
    """Estimate total tokens in a messages array (including role overhead)."""
    total = 0
    for msg in messages:
        total += 4  # role/structure overhead
        total += estimate_tokens(msg.get("content", ""))
    return total


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

class ValidationResult:
    def __init__(self, filepath: str):
        self.filepath = filepath
        self.total_lines = 0
        self.empty_lines = 0
        self.valid_lines = 0
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.token_counts: list[int] = []
        self.user_token_counts: list[int] = []
        self.assistant_token_counts: list[int] = []
        self.content_hashes: list[str] = []
        self.role_distribution: Counter = Counter()
        self.message_lengths: list[int] = []  # number of messages per example

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    @property
    def duplicate_count(self) -> int:
        return len(self.content_hashes) - len(set(self.content_hashes))

    def summary(self, verbose: bool = False) -> str:
        lines = []
        lines.append(f"{'='*60}")
        lines.append(f"File: {self.filepath}")
        lines.append(f"{'='*60}")
        lines.append(f"Total lines:        {self.total_lines}")
        lines.append(f"Empty lines:        {self.empty_lines}")
        lines.append(f"Valid examples:     {self.valid_lines}")
        lines.append(f"Errors:             {len(self.errors)}")
        lines.append(f"Warnings:           {len(self.warnings)}")
        lines.append(f"Duplicates:         {self.duplicate_count}")

        if self.token_counts:
            lines.append(f"")
            lines.append(f"Token statistics (estimated):")
            lines.append(f"  Total tokens:     {sum(self.token_counts):,}")
            lines.append(f"  Min per example:  {min(self.token_counts):,}")
            lines.append(f"  Max per example:  {max(self.token_counts):,}")
            lines.append(f"  Mean per example: {sum(self.token_counts)//max(1,len(self.token_counts)):,}")

            if self.user_token_counts:
                lines.append(f"  User avg tokens:  {sum(self.user_token_counts)//max(1,len(self.user_token_counts)):,}")
            if self.assistant_token_counts:
                lines.append(f"  Asst avg tokens:  {sum(self.assistant_token_counts)//max(1,len(self.assistant_token_counts)):,}")

        if self.message_lengths:
            lines.append(f"")
            lines.append(f"Messages per example:")
            for length, count in sorted(Counter(self.message_lengths).items()):
                lines.append(f"  {length} messages: {count} examples")

        if self.role_distribution:
            lines.append(f"")
            lines.append(f"Role distribution:")
            for role, count in self.role_distribution.most_common():
                lines.append(f"  {role}: {count}")

        if self.errors and verbose:
            lines.append(f"")
            lines.append(f"Errors (first 30):")
            for e in self.errors[:30]:
                lines.append(f"  {e}")

        if self.warnings and verbose:
            lines.append(f"")
            lines.append(f"Warnings (first 30):")
            for w in self.warnings[:30]:
                lines.append(f"  {w}")

        lines.append(f"")
        status = "PASS" if self.is_valid else "FAIL"
        lines.append(f"Result: {status}")
        lines.append(f"{'='*60}")
        return "\n".join(lines)


def validate_file(filepath: str, strict: bool = False) -> ValidationResult:
    """Validate a single JSONL file."""
    result = ValidationResult(filepath)

    if not os.path.exists(filepath):
        result.errors.append(f"File not found: {filepath}")
        return result

    file_size = os.path.getsize(filepath)
    if file_size == 0:
        result.errors.append("File is empty")
        return result

    with open(filepath, "r", encoding="utf-8") as f:
        for line_num, raw_line in enumerate(f, 1):
            result.total_lines += 1
            line = raw_line.strip()

            if not line:
                result.empty_lines += 1
                continue

            # --- Valid JSON ---
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                result.errors.append(f"L{line_num}: Invalid JSON — {e}")
                continue

            # --- Top-level structure ---
            if not isinstance(obj, dict):
                result.errors.append(f"L{line_num}: Expected JSON object, got {type(obj).__name__}")
                continue

            if "messages" not in obj:
                result.errors.append(f"L{line_num}: Missing 'messages' key")
                continue

            msgs = obj["messages"]
            if not isinstance(msgs, list):
                result.errors.append(f"L{line_num}: 'messages' must be an array")
                continue

            if len(msgs) < 2:
                result.errors.append(f"L{line_num}: Need at least 2 messages (user + assistant)")
                continue

            result.message_lengths.append(len(msgs))

            # --- Message validation ---
            line_has_error = False
            line_user_tokens = 0
            line_asst_tokens = 0
            line_total_tokens = 0

            # Determine if first message is system
            has_system = msgs[0].get("role") == "system" if msgs else False
            data_msgs = msgs[1:] if has_system else msgs

            for j, msg in enumerate(msgs):
                if not isinstance(msg, dict):
                    result.errors.append(f"L{line_num}, msg {j}: Not a JSON object")
                    line_has_error = True
                    continue

                if "role" not in msg:
                    result.errors.append(f"L{line_num}, msg {j}: Missing 'role'")
                    line_has_error = True
                    continue

                if "content" not in msg:
                    result.errors.append(f"L{line_num}, msg {j}: Missing 'content'")
                    line_has_error = True
                    continue

                role = msg["role"]
                content = msg["content"]
                result.role_distribution[role] += 1

                # Allowed roles
                if role not in ("system", "user", "assistant"):
                    result.errors.append(f"L{line_num}, msg {j}: Invalid role '{role}'")
                    line_has_error = True
                    continue

                # System only as first message
                if role == "system" and j != 0:
                    result.errors.append(f"L{line_num}, msg {j}: 'system' role only allowed as first message")
                    line_has_error = True

                # Content validation
                if not isinstance(content, str):
                    result.errors.append(f"L{line_num}, msg {j}: 'content' must be a string")
                    line_has_error = True
                    continue

                if len(content.strip()) == 0:
                    if strict:
                        result.errors.append(f"L{line_num}, msg {j}: Empty content (strict mode)")
                        line_has_error = True
                    else:
                        result.warnings.append(f"L{line_num}, msg {j}: Empty content")

                tokens = estimate_tokens(content)
                line_total_tokens += tokens + 4  # overhead
                if role == "user":
                    line_user_tokens += tokens
                elif role == "assistant":
                    line_asst_tokens += tokens

            # --- Role alternation check ---
            for j, msg in enumerate(data_msgs):
                expected_role = "user" if j % 2 == 0 else "assistant"
                actual_role = msg.get("role", "")
                if actual_role != expected_role:
                    result.warnings.append(f"L{line_num}, data msg {j}: Expected '{expected_role}', got '{actual_role}'")

            # --- Last message should be assistant ---
            if msgs and msgs[-1].get("role") != "assistant":
                if strict:
                    result.errors.append(f"L{line_num}: Last message should be 'assistant', got '{msgs[-1].get('role')}'")
                    line_has_error = True
                else:
                    result.warnings.append(f"L{line_num}: Last message is not 'assistant'")

            # --- Token limits ---
            if line_total_tokens > 32768:
                result.warnings.append(f"L{line_num}: Estimated {line_total_tokens} tokens — may exceed model context window")

            if not line_has_error:
                result.valid_lines += 1
                result.token_counts.append(line_total_tokens)
                result.user_token_counts.append(line_user_tokens)
                result.assistant_token_counts.append(line_asst_tokens)

                # Duplicate hash
                content_str = json.dumps(msgs, sort_keys=True, ensure_ascii=False)
                h = hashlib.md5(content_str.encode("utf-8")).hexdigest()
                result.content_hashes.append(h)

    # --- Post-validation checks ---
    if result.duplicate_count > 0:
        if strict:
            result.errors.append(f"Found {result.duplicate_count} duplicate examples")
        else:
            result.warnings.append(f"Found {result.duplicate_count} duplicate examples")

    if result.valid_lines < 10:
        result.warnings.append(f"Very few examples ({result.valid_lines}) — Mistral recommends 200-5000 for fine-tuning")

    return result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Validate JSONL datasets for Mistral fine-tuning",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 validate_dataset.py datasets/kicad/train.jsonl
  python3 validate_dataset.py datasets/kicad/train.jsonl --verbose --strict
  python3 validate_dataset.py --batch datasets/*/train.jsonl
  python3 validate_dataset.py --json datasets/kicad/train.jsonl
        """,
    )
    parser.add_argument("files", nargs="*", help="JSONL file(s) to validate")
    parser.add_argument("--batch", nargs="+", metavar="FILE", help="Validate multiple files")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show detailed errors and warnings")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")

    args = parser.parse_args()

    files = list(args.files or []) + list(args.batch or [])

    if not files:
        parser.print_help()
        sys.exit(1)

    all_results = []
    all_pass = True

    for filepath in files:
        # Expand globs
        expanded = list(Path(".").glob(filepath)) if "*" in filepath else [Path(filepath)]
        for p in expanded:
            result = validate_file(str(p), strict=args.strict)
            all_results.append(result)
            if not result.is_valid:
                all_pass = False

    if args.json:
        output = []
        for r in all_results:
            output.append({
                "file": r.filepath,
                "valid": r.is_valid,
                "total_lines": r.total_lines,
                "valid_lines": r.valid_lines,
                "errors": len(r.errors),
                "warnings": len(r.warnings),
                "duplicates": r.duplicate_count,
                "estimated_tokens": sum(r.token_counts) if r.token_counts else 0,
            })
        print(json.dumps(output, indent=2))
    else:
        for r in all_results:
            print(r.summary(verbose=args.verbose))
            print()

    # Summary for batch
    if len(all_results) > 1:
        passed = sum(1 for r in all_results if r.is_valid)
        total_examples = sum(r.valid_lines for r in all_results)
        total_tokens = sum(sum(r.token_counts) for r in all_results if r.token_counts)
        print(f"Batch summary: {passed}/{len(all_results)} files passed, {total_examples} total examples, ~{total_tokens:,} tokens")

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
