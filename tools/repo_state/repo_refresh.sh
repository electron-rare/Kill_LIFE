#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--header-only] [--json-only] [--no-refresh]

Options:
  --header-only  print only artifacts/repo_state/header.latest.md
  --json-only    print only artifacts/repo_state/global_index.json
  --no-refresh   skip running collect.py in the 3 repos
USAGE
}

HEADER_ONLY=0
JSON_ONLY=0
NO_REFRESH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --header-only)
      HEADER_ONLY=1
      shift
      ;;
    --json-only)
      JSON_ONLY=1
      shift
      ;;
    --no-refresh)
      NO_REFRESH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$HEADER_ONLY" == "1" && "$JSON_ONLY" == "1" ]]; then
  echo "[fail] --header-only and --json-only are mutually exclusive" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KILL_LIFE_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARENT_DIR="$(cd "$KILL_LIFE_REPO/.." && pwd)"

REPO_ROOT_KILL_LIFE="${REPO_ROOT_KILL_LIFE:-$PARENT_DIR/Kill_LIFE}"
REPO_ROOT_RTC_BL_PHONE="${REPO_ROOT_RTC_BL_PHONE:-$PARENT_DIR/RTC_BL_PHONE}"
REPO_ROOT_ZACUS="${REPO_ROOT_ZACUS:-$PARENT_DIR/le-mystere-professeur-zacus}"

ART_DIR="${REPO_STATE_ART_DIR:-$KILL_LIFE_REPO/artifacts/repo_state}"
SUMMARY_FILE="$ART_DIR/global_summary.md"
INDEX_JSON_FILE="$ART_DIR/global_index.json"
HEADER_FILE="$ART_DIR/header.latest.md"

mkdir -p "$ART_DIR"

refresh_one_repo() {
  local repo_name="$1"
  local repo_root="$2"

  if [[ ! -d "$repo_root/.git" ]]; then
    echo "[fail] missing repo for $repo_name at $repo_root" >&2
    return 1
  fi

  local collector="$repo_root/tools/repo_state/collect.py"
  if [[ -f "$collector" ]]; then
    python3 "$collector" --repo-name "$repo_name" --repo-root "$repo_root"
  else
    python3 "$KILL_LIFE_REPO/tools/repo_state/collect.py" --repo-root "$repo_root" --repo-name "$repo_name"
  fi
}

if [[ "$NO_REFRESH" != "1" ]]; then
  refresh_one_repo "Kill_LIFE" "$REPO_ROOT_KILL_LIFE"
  refresh_one_repo "RTC_BL_PHONE" "$REPO_ROOT_RTC_BL_PHONE"
  refresh_one_repo "le-mystere-professeur-zacus" "$REPO_ROOT_ZACUS"
fi

KILL_MD="$REPO_ROOT_KILL_LIFE/docs/REPO_STATE.md"
RTC_MD="$REPO_ROOT_RTC_BL_PHONE/docs/REPO_STATE.md"
ZACUS_MD="$REPO_ROOT_ZACUS/docs/REPO_STATE.md"

python3 - "$SUMMARY_FILE" "$INDEX_JSON_FILE" "$HEADER_FILE" "$KILL_MD" "$RTC_MD" "$ZACUS_MD" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

summary_file = Path(sys.argv[1])
index_json_file = Path(sys.argv[2])
header_file = Path(sys.argv[3])
md_files = [Path(p) for p in sys.argv[4:]]

required_keys = [
    "Repo",
    "Branch",
    "HEAD",
    "HeadDate",
    "ProjectKind",
    "PivotChanges",
    "ImpactGates",
]


def parse_md(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"[fail] missing file: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "<!-- REPO_STATE:v1 -->":
        raise SystemExit(f"[fail] invalid header marker in {path}")

    data = {}
    for line in lines:
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        data[k.strip()] = v.strip()

    missing = [k for k in required_keys if k not in data]
    if missing:
        raise SystemExit(f"[fail] missing keys in {path}: {', '.join(missing)}")

    try:
        pivots = json.loads(data["PivotChanges"])
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[fail] invalid PivotChanges JSON in {path}: {exc}")

    gates = [g.strip() for g in data["ImpactGates"].split(",") if g.strip()]

    return {
        "repo": data["Repo"],
        "branch": data["Branch"],
        "head": data["HEAD"],
        "head_date": data["HeadDate"],
        "project_kind": data["ProjectKind"],
        "pivot_changes": pivots,
        "impact_gates": gates,
        "source": str(path),
    }


entries = [parse_md(p) for p in md_files]
now_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def pivot_text(entry: dict) -> str:
    pivots = entry["pivot_changes"]
    if not pivots:
        return "(none)"
    paths = []
    for item in pivots[:2]:
        p = str(item.get("path", "")).strip() or "(none)"
        paths.append(p)
    if len(pivots) > 2:
        paths.append("...")
    return "; ".join(paths)

header_lines = [f"[REPO-STATE UTC: {now_utc}]"]
for entry in entries:
    head_short = entry["head"][:8]
    pivots = pivot_text(entry)
    gates = ", ".join(entry["impact_gates"]) if entry["impact_gates"] else "general_change"
    header_lines.append(f"{entry['repo']:<28} | HEAD {head_short} | pivots: {pivots} | gates: {gates}")
header_lines.append("[/REPO-STATE]")
header_text = "\n".join(header_lines) + "\n"
header_file.write_text(header_text, encoding="utf-8")

summary_lines = ["# Global Repo State", "", f"GeneratedAtUTC: `{now_utc}`", ""]
for entry in entries:
    summary_lines.append(f"## {entry['repo']}")
    summary_lines.append(f"- Branch: `{entry['branch']}`")
    summary_lines.append(f"- HEAD: `{entry['head']}`")
    summary_lines.append(f"- HeadDate: `{entry['head_date']}`")
    summary_lines.append(f"- ProjectKind: `{entry['project_kind']}`")
    summary_lines.append(f"- ImpactGates: `{', '.join(entry['impact_gates'])}`")
    summary_lines.append(f"- Pivots: `{pivot_text(entry)}`")
    summary_lines.append("")
summary_file.write_text("\n".join(summary_lines), encoding="utf-8")

index_data = {
    "schema_version": "global_repo_index.v1",
    "generated_at_utc": now_utc,
    "repos": entries,
}
index_json_file.write_text(json.dumps(index_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if [[ "$HEADER_ONLY" == "1" ]]; then
  cat "$HEADER_FILE"
  exit 0
fi

if [[ "$JSON_ONLY" == "1" ]]; then
  cat "$INDEX_JSON_FILE"
  exit 0
fi

echo "[ok] wrote $SUMMARY_FILE"
echo "[ok] wrote $INDEX_JSON_FILE"
echo "[ok] wrote $HEADER_FILE"
cat "$HEADER_FILE"
