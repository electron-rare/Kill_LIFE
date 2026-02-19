#!/usr/bin/env python3
"""
Generate a structured JSON "SafePatch" using Mistral (JSON mode),
without touching repository files.

Example:
  python tools/mistral/mistral_generate_patch.py \
    --model codestral-latest \
    --scope ai:spec \
    --request "Draft RFC2119 spec for Feature X" \
    --out /tmp/patch.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator

from tools.mistral.mistral_client import chat_json
from tools.mistral.scope_allowlists import explain_scope

SCHEMA_PATH = Path(__file__).parent / "schemas" / "safe_patch.schema.json"


SYSTEM_TEMPLATE = """You are a SAFE PATCH GENERATOR for a software repository.

Rules:
- Output MUST be a single JSON object matching the provided schema.
- NEVER include markdown, code fences, prose outside JSON.
- Only propose file edits within the allowed scope; if a request would require out-of-scope edits,
  provide an in-scope alternative and add a note.
- Do NOT include changes to CI workflows or security boundaries.
- Do NOT include secrets.
- Use minimal diffs: create/update only what is necessary.

Allowed scope:
{scope_expl}

Schema:
{schema}
"""

USER_TEMPLATE = """Request:
{request}

Context notes (optional):
{context}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="codestral-latest")
    ap.add_argument("--scope", required=True, help="ai:spec|ai:plan|ai:tasks|ai:impl|ai:qa|ai:docs")
    ap.add_argument("--request", required=True)
    ap.add_argument("--context", default="")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    system = SYSTEM_TEMPLATE.format(scope_expl=explain_scope(args.scope), schema=json.dumps(schema, indent=2))
    user = USER_TEMPLATE.format(request=args.request, context=args.context)

    patch = chat_json(model=args.model, system=system, user=user, temperature=0.0, max_tokens=4096)

    # Validate schema
    v = Draft202012Validator(schema)
    errors = sorted(v.iter_errors(patch), key=lambda e: e.path)
    if errors:
        msg = "\n".join([f"- {list(e.path)}: {e.message}" for e in errors])
        raise SystemExit(f"Patch JSON does not match schema:\n{msg}\n\nRaw patch:\n{json.dumps(patch, indent=2)}")

    out = Path(args.out)
    out.write_text(json.dumps(patch, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote patch: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
