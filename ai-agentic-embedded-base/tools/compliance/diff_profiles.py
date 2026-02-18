#!/usr/bin/env python3
"""Show differences between two compliance profiles (standards + pcb rules + evidence)."""
import argparse
from tools.compliance.common import load_profile

def _set(d, key):
    v = d.get(key) or []
    return set(v)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    args = ap.parse_args()

    A = load_profile(args.a)
    B = load_profile(args.b)

    print(f"== Standards (required) diff: {args.a} vs {args.b}")
    only_a = sorted(_set(A, "required_standards") - _set(B, "required_standards"))
    only_b = sorted(_set(B, "required_standards") - _set(A, "required_standards"))
    if only_a: print(f"  only {args.a}: {only_a}")
    if only_b: print(f"  only {args.b}: {only_b}")
    if not only_a and not only_b: print("  (identical)")

    print("\n== Evidence diff")
    ea = sorted(_set(A, "evidence_required") - _set(B, "evidence_required"))
    eb = sorted(_set(B, "evidence_required") - _set(A, "evidence_required"))
    if ea: print(f"  only {args.a}: {ea}")
    if eb: print(f"  only {args.b}: {eb}")
    if not ea and not eb: print("  (identical)")

    print("\n== PCB rules")
    ra = A.get("pcb_rules") or {}
    rb = B.get("pcb_rules") or {}
    keys = sorted(set(ra.keys()) | set(rb.keys()))
    for k in keys:
        if ra.get(k) != rb.get(k):
            print(f"  {k}: {ra.get(k)}  ->  {rb.get(k)}")

if __name__ == "__main__":
    main()
