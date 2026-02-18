#!/usr/bin/env python3
"""Validate compliance setup.

- active profile exists
- standards referenced by profile exist in catalog
- plan.yaml exists (minimal structure)
- (optional) strict: check evidence files existence for paths inside repo
"""
from pathlib import Path
import argparse
import glob
import os

from tools.compliance.common import (
    repo_path, load_active_profile_name, load_profile, load_catalog, load_yaml
)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true", help="Fail if evidence files are missing (repo paths only).")
    args = ap.parse_args()

    active = load_active_profile_name()
    profile = load_profile(active)
    catalog = load_catalog()
    catalog_std = (catalog.get("standards") or {})

    missing = []
    for sid in (profile.get("required_standards") or []):
        if sid not in catalog_std:
            missing.append(sid)
    if missing:
        raise SystemExit("ERROR: missing standard IDs in catalog: " + ", ".join(missing))

    plan_path = repo_path("compliance/plan.yaml")
    if not plan_path.exists():
        raise SystemExit(f"ERROR: missing {plan_path}")
    plan = load_yaml(plan_path) or {}
    if "product" not in plan or "compliance" not in plan:
        raise SystemExit("ERROR: compliance/plan.yaml missing required keys: product, compliance")

    # Evidence validation (strict mode: only check paths that are in-repo, not artifacts globs)
    if args.strict:
        missing_evidence = []
        for item in (profile.get("evidence_required") or []):
            if item.startswith("artifacts/"):
                # artifacts are generated; don't enforce here
                continue
            # glob patterns
            matches = glob.glob(str(repo_path(item)))
            if not matches:
                missing_evidence.append(item)
        if missing_evidence:
            raise SystemExit("ERROR: missing evidence files: " + ", ".join(missing_evidence))

    print(f"OK: compliance profile '{active}' validated.")
    print(f"  required standards: {len(profile.get('required_standards') or [])}")
    print(f"  evidence items: {len(profile.get('evidence_required') or [])}")

if __name__ == "__main__":
    main()
