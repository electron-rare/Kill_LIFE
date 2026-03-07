#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.ci_runtime import collect_artifacts, ensure_evidence_dir, now_utc, resolve_target, write_json


def collect_evidence(target: str) -> bool:
    spec = resolve_target(target)
    evidence_dir = ensure_evidence_dir(spec.requested)
    prefix = "build" if spec.mode == "build" else "test"
    required = [
        evidence_dir / f"{prefix}.result.json",
        evidence_dir / f"{prefix}.stdout.txt",
        evidence_dir / f"{prefix}.stderr.txt",
    ]
    artifacts = collect_artifacts(spec)
    missing = [path.name for path in required if not path.exists()]
    if not artifacts:
        missing.append("artifacts")

    summary = {
        "target": spec.requested,
        "env": spec.env,
        "mode": spec.mode,
        "generated_at_utc": now_utc(),
        "required_files": [path.name for path in required],
        "artifacts": artifacts,
        "status": "ok" if not missing else "incomplete",
        "missing": missing,
    }
    write_json(evidence_dir / "summary.json", summary)

    if missing:
        print(f"Evidence pack incomplet pour {spec.requested}: {', '.join(missing)}")
        return False

    print(f"Evidence pack généré pour {spec.requested}: {evidence_dir}")
    return True


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit("usage: collect_evidence.py <target>")
    raise SystemExit(0 if collect_evidence(sys.argv[1]) else 1)
