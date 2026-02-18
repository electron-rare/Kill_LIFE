#!/usr/bin/env python3
"""Switch active compliance profile."""
from pathlib import Path
import argparse
from tools.compliance.common import repo_path, save_yaml

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("profile", help="Profile name (e.g., prototype, iot_wifi_eu)")
    args = ap.parse_args()

    p = repo_path(f"compliance/profiles/{args.profile}.yaml")
    if not p.exists():
        raise SystemExit(f"ERROR: unknown profile: {args.profile} (missing {p})")

    save_yaml(repo_path("compliance/active_profile.yaml"), {"profile": args.profile})
    print(f"Active compliance profile = {args.profile}")

if __name__ == "__main__":
    main()
