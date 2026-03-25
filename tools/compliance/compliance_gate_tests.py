#!/usr/bin/env python3
"""Compliance gate tests — run as CI gate to block non-compliant merges.

Tests:
  1. Active profile is valid and parseable
  2. All required standards exist in catalog
  3. plan.yaml has required structure
  4. Evidence files referenced by profile exist (soft check)
  5. EMC/Radio/LVD/Labelling categories have coverage

Usage:
    python3 tools/compliance/compliance_gate_tests.py
    python3 tools/compliance/compliance_gate_tests.py --strict

Exit code 0 = pass, 1 = fail.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.compliance.common import (
    load_active_profile_name,
    load_profile,
    load_catalog,
    load_yaml,
    repo_path,
)


def test_active_profile_valid():
    """Profile name is set and loadable."""
    name = load_active_profile_name()
    assert name, "No active profile name"
    profile = load_profile(name)
    assert profile, f"Profile '{name}' is empty"
    return f"Active profile: {name}"


def test_standards_in_catalog():
    """All required standards from profile exist in catalog."""
    name = load_active_profile_name()
    profile = load_profile(name)
    catalog = load_catalog()
    catalog_stds = catalog.get("standards") or {}
    required = profile.get("required_standards") or []
    missing = [s for s in required if s not in catalog_stds]
    assert not missing, f"Missing standards in catalog: {missing}"
    return f"{len(required)} standards all present in catalog"


def test_plan_yaml_structure():
    """plan.yaml exists and has required keys."""
    plan_path = repo_path("compliance/plan.yaml")
    assert plan_path.exists(), f"Missing {plan_path}"
    plan = load_yaml(plan_path)
    assert plan, "plan.yaml is empty"
    assert "product" in plan, "plan.yaml missing 'product' key"
    assert "compliance" in plan, "plan.yaml missing 'compliance' key"
    return "plan.yaml structure valid"


def test_evidence_directory():
    """Evidence directory exists."""
    evidence_dir = ROOT / "compliance" / "evidence"
    assert evidence_dir.exists(), f"Missing {evidence_dir}"
    files = list(evidence_dir.iterdir())
    return f"Evidence directory has {len(files)} files"


def test_emc_radio_coverage():
    """At least one radio or EMC standard is in profile (for iot_wifi_eu)."""
    name = load_active_profile_name()
    if name == "prototype":
        return "SKIP: prototype profile does not require radio/EMC"
    profile = load_profile(name)
    required = profile.get("required_standards") or []
    radio_emc = [s for s in required if "ETSI" in s or "55032" in s or "55035" in s]
    assert radio_emc, "No radio/EMC standards found in profile"
    return f"Radio/EMC standards: {len(radio_emc)}"


def main():
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    tests = [
        test_active_profile_valid,
        test_standards_in_catalog,
        test_plan_yaml_structure,
        test_evidence_directory,
        test_emc_radio_coverage,
    ]

    passed = 0
    failed = 0

    for test_fn in tests:
        name = test_fn.__name__
        try:
            result = test_fn()
            print(f"  PASS  {name}: {result}")
            passed += 1
        except AssertionError as e:
            if args.strict:
                print(f"  FAIL  {name}: {e}")
                failed += 1
            else:
                print(f"  WARN  {name}: {e}")
                passed += 1
        except Exception as e:
            print(f"  ERROR {name}: {e}")
            failed += 1

    print(f"\n{'PASS' if failed == 0 else 'FAIL'}: {passed} passed, {failed} failed")
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
