#!/usr/bin/env python3
"""Switch active compliance profile."""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.compliance.common import repo_path, save_yaml

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("profile", nargs="?", help="Profile name (e.g., prototype, iot_wifi_eu)")
    ap.add_argument("--profile", dest="profile_flag", help="Profile name (alias for the positional argument)")
    args = ap.parse_args()
    profile_name = args.profile_flag or args.profile
    if not profile_name:
        ap.error("a profile name is required")

    p = repo_path(f"compliance/profiles/{profile_name}.yaml")
    if not p.exists():
        raise SystemExit(f"ERROR: unknown profile: {profile_name} (missing {p})")

    save_yaml(repo_path("compliance/active_profile.yaml"), {"profile": profile_name})
    print(f"Active compliance profile = {profile_name}")

if __name__ == "__main__":
    main()
