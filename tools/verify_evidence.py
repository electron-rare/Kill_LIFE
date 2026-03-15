#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

BOOTSTRAP_ROOT = Path(__file__).resolve().parents[1]
if str(BOOTSTRAP_ROOT) not in sys.path:
    sys.path.insert(0, str(BOOTSTRAP_ROOT))

from tools.ci_runtime import ROOT, ensure_evidence_dir


def verify_evidence(target: str) -> bool:
    evidence_dir = ensure_evidence_dir(target)
    summary_path = evidence_dir / "summary.json"
    if not summary_path.exists():
        print(f"Evidence pack absent pour {target}: {summary_path}")
        return False

    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    if summary.get("status") != "ok":
        print(f"Evidence pack invalide pour {target}: {summary.get('missing', [])}")
        return False

    missing = []
    for rel in summary.get("artifacts", []):
        path = ROOT / rel
        if not path.exists():
            missing.append(rel)

    if missing:
        print(f"Artifacts manquants pour {target}: {missing}")
        return False

    print(f"Evidence pack trouvé pour {target}: {summary.get('artifacts', [])}")
    return True


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_evidence.py <target>")
    raise SystemExit(0 if verify_evidence(sys.argv[1]) else 1)
