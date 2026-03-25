#!/usr/bin/env python3
"""Check compliance requirements: Radio, EMC, LVD, labelling.

Reads the active compliance profile and standards catalog, then verifies
that each required standard category has at least a plan entry or evidence
file referenced.

Usage:
    python3 tools/compliance/check_emc_radio_lvd.py [--strict]
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

# Categories of requirements to check
REQUIREMENT_CATEGORIES = {
    "radio": {
        "description": "Radio spectrum access (RED Art. 3.2)",
        "standard_prefixes": ["ETSI-EN-300", "ETSI-EN-301"],
        "keywords": ["radio", "spectrum", "RED"],
    },
    "emc": {
        "description": "Electromagnetic Compatibility (EMC Directive / RED Art. 3.1b)",
        "standard_prefixes": ["ETSI-EN-301-489", "NF-EN-55032", "EN-55035"],
        "keywords": ["emc", "emission", "immunity"],
    },
    "lvd": {
        "description": "Electrical Safety / LVD (RED Art. 3.1a)",
        "standard_prefixes": ["IEC-62368"],
        "keywords": ["safety", "lvd", "62368"],
    },
    "labelling": {
        "description": "Labelling and marking (CE, WEEE, RoHS, recycling)",
        "standard_prefixes": ["EU-RoHS", "EU-WEEE", "EU-REACH"],
        "keywords": ["label", "marking", "CE", "RoHS", "WEEE"],
    },
}


def check_profile_coverage(profile_name: str, strict: bool = False) -> list[dict]:
    """Return a list of check results per category."""
    profile = load_profile(profile_name)
    catalog = load_catalog()
    catalog_stds = catalog.get("standards") or {}
    required_ids = profile.get("required_standards") or []

    plan_path = repo_path("compliance/plan.yaml")
    plan = load_yaml(plan_path) if plan_path.exists() else {}
    plan_compliance = plan.get("compliance", {}) if plan else {}

    results = []

    for cat_key, cat_info in REQUIREMENT_CATEGORIES.items():
        matched_standards = []
        for sid in required_ids:
            for prefix in cat_info["standard_prefixes"]:
                if sid.startswith(prefix):
                    matched_standards.append(sid)
                    break

        has_plan_entry = False
        if plan_compliance:
            plan_str = str(plan_compliance).lower()
            has_plan_entry = any(kw.lower() in plan_str for kw in cat_info["keywords"])

        evidence_dir = ROOT / "compliance" / "evidence"
        has_evidence = False
        if evidence_dir.exists():
            for f in evidence_dir.iterdir():
                fname = f.name.lower()
                if any(kw.lower() in fname for kw in cat_info["keywords"]):
                    has_evidence = True
                    break

        status = "pass" if (matched_standards or has_plan_entry) else "warn"
        if strict and not matched_standards:
            status = "fail"

        results.append(
            {
                "category": cat_key,
                "description": cat_info["description"],
                "matched_standards": matched_standards,
                "has_plan_entry": has_plan_entry,
                "has_evidence": has_evidence,
                "status": status,
            }
        )

    return results


def main():
    import argparse

    ap = argparse.ArgumentParser(description="Check Radio/EMC/LVD/Labelling compliance coverage")
    ap.add_argument("--strict", action="store_true", help="Fail if any category has no matched standards")
    args = ap.parse_args()

    profile_name = load_active_profile_name()
    print(f"Active profile: {profile_name}")
    print(f"{'Category':<12} {'Status':<6} {'Standards':<40} {'Plan':<5} {'Evidence':<8} Description")
    print("-" * 110)

    results = check_profile_coverage(profile_name, strict=args.strict)
    failures = 0

    for r in results:
        stds = ", ".join(r["matched_standards"][:3]) or "(none)"
        if len(r["matched_standards"]) > 3:
            stds += f" +{len(r['matched_standards'])-3}"
        plan_mark = "Y" if r["has_plan_entry"] else "-"
        ev_mark = "Y" if r["has_evidence"] else "-"
        status = r["status"].upper()

        print(f"{r['category']:<12} {status:<6} {stds:<40} {plan_mark:<5} {ev_mark:<8} {r['description']}")

        if r["status"] == "fail":
            failures += 1

    print()
    if failures:
        print(f"FAIL: {failures} categories missing required standards")
        sys.exit(1)
    else:
        print("OK: all categories have coverage (use --strict to enforce standards)")


if __name__ == "__main__":
    main()
