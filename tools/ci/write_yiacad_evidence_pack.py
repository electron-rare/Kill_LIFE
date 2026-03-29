#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


@dataclass(frozen=True)
class EvidenceInputs:
    workflow: str
    lane: str
    status: str
    summary: str
    repository: str | None
    server_url: str | None
    run_id: str | None
    run_attempt: str | None
    ref: str | None
    sha: str | None
    event: str | None
    engines: list[str]
    artifact_paths: list[str]
    generated_at: str


def _normalize_strings(values: Sequence[str]) -> list[str]:
    return [value.strip() for value in values if isinstance(value, str) and value.strip()]


def build_payload(inputs: EvidenceInputs) -> dict[str, object]:
    run_url = None
    if inputs.server_url and inputs.repository and inputs.run_id:
        run_url = (
            f"{inputs.server_url.rstrip('/')}/{inputs.repository}/actions/runs/{inputs.run_id}"
        )

    return {
        "schemaVersion": "yiacad-evidence-pack/v1",
        "generatedAt": inputs.generated_at,
        "workflow": inputs.workflow,
        "lane": inputs.lane,
        "status": inputs.status,
        "summary": inputs.summary,
        "repository": inputs.repository,
        "run": {
            "id": inputs.run_id,
            "attempt": inputs.run_attempt,
            "url": run_url,
        },
        "git": {
            "ref": inputs.ref,
            "sha": inputs.sha,
            "event": inputs.event,
        },
        "engines": _normalize_strings(inputs.engines),
        "artifacts": [
            {
                "path": artifact_path,
            }
            for artifact_path in _normalize_strings(inputs.artifact_paths)
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write a normalized YiACAD evidence pack JSON file.")
    parser.add_argument("--output", required=True, help="Output JSON file path")
    parser.add_argument("--workflow", required=True, help="Workflow display name")
    parser.add_argument("--lane", required=True, help="YiACAD lane identifier")
    parser.add_argument("--status", required=True, help="success | failure | degraded | blocked")
    parser.add_argument("--summary", required=True, help="Human-readable summary")
    parser.add_argument("--repository", default=None, help="GitHub owner/repo")
    parser.add_argument("--server-url", default=None, help="GitHub server URL")
    parser.add_argument("--run-id", default=None, help="GitHub Actions run id")
    parser.add_argument("--run-attempt", default=None, help="GitHub Actions run attempt")
    parser.add_argument("--ref", default=None, help="Git ref")
    parser.add_argument("--sha", default=None, help="Git SHA")
    parser.add_argument("--event", default=None, help="GitHub event name")
    parser.add_argument("--generated-at", default=None, help="Override generation timestamp")
    parser.add_argument(
        "--engine",
        action="append",
        default=[],
        help="Integrated engine name. Repeat for multiple values.",
    )
    parser.add_argument(
        "--artifact-path",
        action="append",
        default=[],
        help="Artifact path or directory captured by the workflow. Repeat for multiple values.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    payload = build_payload(
        EvidenceInputs(
            workflow=args.workflow,
            lane=args.lane,
            status=args.status,
            summary=args.summary,
            repository=args.repository,
            server_url=args.server_url,
            run_id=args.run_id,
            run_attempt=args.run_attempt,
            ref=args.ref,
            sha=args.sha,
            event=args.event,
            engines=list(args.engine),
            artifact_paths=list(args.artifact_path),
            generated_at=args.generated_at or now_utc_iso(),
        )
    )
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
