#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/tools/cockpit/json_contract.sh"

COMPONENT="intelligence_tui"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/cockpit/intelligence_program"
mkdir -p "${ARTIFACT_DIR}"

STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="${ARTIFACT_DIR}/intelligence_tui-${STAMP}.log"
ACTION="status"
JSON=0
APPLY=0
RETENTION_DAYS=14
LIMIT=8
LINES=120

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/intelligence_tui.sh [options]

Options:
  --action <status|summary-short|scorecard|comparison|recommendations|audit|feature-map|spec|plan|owners|todo|research|memory|next-actions|logs-summary|logs-list|logs-latest|purge-logs>
  --json
  --apply
  --days <N>
  --limit <N>
  --lines <N>
  -h, --help
EOF
}

log_line() {
  local level="$1"
  shift
  local message="$*"
  printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "${level}" "${message}" | tee -a "${RUN_LOG}" >&2
}

ensure_run_log() {
  : >> "${RUN_LOG}"
}

build_snapshot_json() {
  python3 - "${ROOT_DIR}" "${RUN_LOG}" "${ACTION}" "${LIMIT}" "${ARTIFACT_DIR}" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
run_log = Path(sys.argv[2])
action = sys.argv[3]
limit = int(sys.argv[4])
artifact_dir = Path(sys.argv[5])

def resolve_latest(glob_pattern: str, fallback_relative: str) -> Path:
    matches = sorted(root.glob(glob_pattern))
    if matches:
        return matches[-1]
    return root / fallback_relative


audit_file = resolve_latest(
    "docs/KILL_LIFE_CONSOLIDATION_AUDIT_*.md",
    "docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md",
)
spec_file = root / "specs" / "agentic_intelligence_integration_spec.md"
feature_map_file = resolve_latest(
    "docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_*.md",
    "docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md",
)
plan_file = root / "docs" / "plans" / "22_plan_integration_intelligence_agentique.md"
todo_file = root / "docs" / "plans" / "22_todo_integration_intelligence_agentique.md"
web_spec_file = root / "specs" / "yiacad_git_eda_platform_spec.md"
web_doc_file = resolve_latest(
    "docs/YIACAD_GIT_EDA_PLATFORM_*.md",
    "docs/YIACAD_GIT_EDA_PLATFORM_2026-03-22.md",
)
web_plan_file = root / "docs" / "plans" / "23_plan_yiacad_git_eda_platform.md"
web_todo_file = root / "docs" / "plans" / "23_todo_yiacad_git_eda_platform.md"
web_readme_file = root / "web" / "README.md"
owners_file = root / "docs" / "plans" / "12_plan_gestion_des_agents.md"
tasks_file = root / "specs" / "04_tasks.md"
workflows_file = root / "docs" / "AI_WORKFLOWS.md"
research_file = resolve_latest(
    "docs/WEB_RESEARCH_OPEN_SOURCE_*.md",
    "docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md",
)
kill_life_memory_json = root / "artifacts" / "cockpit" / "kill_life_memory" / "latest.json"
kill_life_memory_md = root / "artifacts" / "cockpit" / "kill_life_memory" / "latest.md"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def parse_markdown_table(text: str, heading: str) -> list[dict[str, str]]:
    section = text.split(heading, 1)
    if len(section) != 2:
        return []
    lines = section[1].splitlines()
    table_lines: list[str] = []
    started = False
    for line in lines:
        if line.startswith("|"):
            table_lines.append(line)
            started = True
            continue
        if started:
            break
    if len(table_lines) < 3:
        return []
    headers = [cell.strip() for cell in table_lines[0].strip("|").split("|")]
    rows = []
    for line in table_lines[2:]:
        values = [cell.strip() for cell in line.strip("|").split("|")]
        if len(values) != len(headers):
            continue
        rows.append(dict(zip(headers, values)))
    return rows


def parse_first_available_table(text: str, headings: list[str]) -> list[dict[str, str]]:
    for heading in headings:
        rows = parse_markdown_table(text, heading)
        if rows:
            return rows
    return []


def parse_bullets_after_heading(text: str, heading: str) -> list[str]:
    section = text.split(heading, 1)
    if len(section) != 2:
        return []
    bullets: list[str] = []
    for line in section[1].splitlines():
        stripped = line.strip()
        if stripped.startswith("## ") and stripped != heading.strip():
            break
        if stripped.startswith("### "):
            break
        if stripped.startswith("- "):
            bullets.append(stripped[2:].strip())
    return bullets


def parse_open_tasks(text: str, max_items: int) -> list[str]:
    tasks = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- [ ]") or stripped.startswith("* [ ]"):
            tasks.append(stripped[5:].strip())
    return tasks[:max_items]


def parse_all_open_tasks(text: str) -> list[str]:
    return parse_open_tasks(text, 10_000)


def web_platform_health() -> dict[str, object]:
    """Probe Next.js, Yjs realtime server, and Redis/BullMQ queue."""
    import urllib.request

    probes: dict[str, object] = {}

    # Next.js web app
    try:
        req = urllib.request.urlopen("http://localhost:3000/", timeout=3)
        probes["nextjs"] = {"status": "up", "http_status": req.status}
    except Exception as exc:
        probes["nextjs"] = {"status": "down", "error": str(exc)[:120]}

    # Yjs realtime server (default port 1234, see web/realtime/server.mjs)
    try:
        req = urllib.request.urlopen("http://localhost:1234/", timeout=3)
        probes["realtime"] = {"status": "up", "http_status": req.status}
    except Exception as exc:
        probes["realtime"] = {"status": "down", "error": str(exc)[:120]}

    # Redis / BullMQ queue depth
    try:
        import socket
        sock = socket.create_connection(("127.0.0.1", 6379), timeout=2)
        sock.sendall(b"LLEN bull:yiacad-eda:wait\r\n")
        data = sock.recv(256).decode("utf-8", errors="replace").strip()
        sock.close()
        if data.startswith(":"):
            depth = int(data[1:])
            probes["queue"] = {"status": "up", "queue_name": "yiacad-eda", "depth": depth}
        else:
            probes["queue"] = {"status": "up", "queue_name": "yiacad-eda", "depth": None, "raw": data[:80]}
    except Exception as exc:
        probes["queue"] = {"status": "down", "error": str(exc)[:120]}

    up_count = sum(1 for p in probes.values() if p.get("status") == "up")
    total = len(probes)
    if up_count == total:
        overall = "up"
    elif up_count == 0:
        overall = "down"
    else:
        overall = "degraded"

    return {
        "status": overall,
        "probes": probes,
        "up_count": up_count,
        "total": total,
    }


def repo_snapshot(repo_path: Path) -> dict[str, object]:
    exists = repo_path.exists()
    payload: dict[str, object] = {
        "name": repo_path.name,
        "path": str(repo_path),
        "exists": exists,
        "dirty_count": None,
        "branch": None,
        "version": None,
        "has_terminal_app": (repo_path / "src" / "cli.ts").exists(),
    }
    if not exists:
        return payload

    package_file = repo_path / "package.json"
    if package_file.exists():
        try:
            payload["version"] = json.loads(package_file.read_text(encoding="utf-8")).get("version")
        except json.JSONDecodeError:
            payload["version"] = "invalid-package-json"

    dirty = subprocess.run(
        ["git", "-C", str(repo_path), "status", "--short"],
        check=False,
        capture_output=True,
        text=True,
    )
    payload["dirty_count"] = len([line for line in dirty.stdout.splitlines() if line.strip()])

    branch = subprocess.run(
        ["git", "-C", str(repo_path), "branch", "--show-current"],
        check=False,
        capture_output=True,
        text=True,
    )
    payload["branch"] = branch.stdout.strip() or None
    return payload


scorecard_view = {
    "json": str(artifact_dir / "scorecard_latest.json"),
    "markdown": str(artifact_dir / "scorecard_latest.md"),
}
comparison_view = {
    "json": str(artifact_dir / "repo_comparison_latest.json"),
    "markdown": str(artifact_dir / "repo_comparison_latest.md"),
}
recommendations_view = {
    "json": str(artifact_dir / "recommendation_queue_latest.json"),
    "markdown": str(artifact_dir / "recommendation_queue_latest.md"),
}


owners = parse_markdown_table(read_text(owners_file), "## Consolidation 2026-03-21 - extensions d'abord")
research = parse_first_available_table(
    read_text(research_file),
    [
        "## Delta verification officielle 2026-03-22",
        "## Delta verification officielle 2026-03-21",
        "### Benchmark 2026 — patterns retenus pour `summary-short` et la gateway santé `runtime/MCP/IA` (mise à jour 2026-03-21)",
        "### Etat de l'art agents / MCP / IA 2026 (mise à jour 2026-03-21)",
    ],
)
priorities = {
    "p0": parse_bullets_after_heading(read_text(audit_file), "### P0"),
    "p1": parse_bullets_after_heading(read_text(audit_file), "### P1"),
    "p2": parse_bullets_after_heading(read_text(audit_file), "### P2"),
}
open_todos_all = parse_all_open_tasks(read_text(todo_file))
web_open_todos_all = parse_all_open_tasks(read_text(web_todo_file))
global_open_tasks_all = parse_all_open_tasks(read_text(tasks_file))
open_tasks = open_todos_all[:limit]
web_open_tasks = web_open_todos_all[:limit]
global_open_tasks = global_open_tasks_all[:limit]
extension_repos = [
    repo_snapshot(root.parent / "kill-life-studio"),
    repo_snapshot(root.parent / "kill-life-mesh"),
    repo_snapshot(root.parent / "kill-life-operator"),
]
web_health = web_platform_health()

status = "degraded" if open_todos_all or web_open_todos_all or global_open_tasks_all else "done"
degraded_reasons = []
if open_todos_all:
    degraded_reasons.append("open-intelligence-todos")
if web_open_todos_all:
    degraded_reasons.append("open-web-eda-todos")
if global_open_tasks_all:
    degraded_reasons.append("open-global-tasks")
next_steps = (open_tasks + web_open_tasks + global_open_tasks)[:3] or [
    "No open tasks detected in docs/plans/22_todo_integration_intelligence_agentique.md and docs/plans/23_todo_yiacad_git_eda_platform.md."
]

canonical_sources = [
    {"label": "README", "path": str(root / "README.md")},
    {"label": "Operator index", "path": str(root / "docs" / "index.md")},
    {"label": "Consolidation audit", "path": str(audit_file)},
    {"label": "Intelligence spec", "path": str(spec_file)},
    {"label": "Intelligence feature map", "path": str(feature_map_file)},
    {"label": "Plan 22", "path": str(plan_file)},
    {"label": "TODO 22", "path": str(todo_file)},
    {"label": "Web spec", "path": str(web_spec_file)},
    {"label": "Web platform doc", "path": str(web_doc_file)},
    {"label": "Plan 23", "path": str(web_plan_file)},
    {"label": "TODO 23", "path": str(web_todo_file)},
    {"label": "Web README", "path": str(web_readme_file)},
    {"label": "AI workflows", "path": str(workflows_file)},
    {"label": "Agent plan", "path": str(owners_file)},
    {"label": "OSS research", "path": str(research_file)},
    {"label": "Backlog", "path": str(tasks_file)},
]

payload = {
    "contract_version": "cockpit-v1",
    "component": "intelligence_tui",
    "action": action,
    "status": status,
    "contract_status": "degraded" if status == "degraded" else "ok",
    "generated_at": datetime.now().astimezone().isoformat(),
    "log_file": str(run_log),
    "artifacts": [str(run_log)],
    "degraded_reasons": degraded_reasons,
    "next_steps": next_steps,
    "canonical_sources": canonical_sources,
    "audit_doc": str(audit_file),
    "spec_doc": str(spec_file),
    "feature_map_doc": str(feature_map_file),
    "plan_doc": str(plan_file),
    "todo_doc": str(todo_file),
    "web_spec_doc": str(web_spec_file),
    "web_doc": str(web_doc_file),
    "web_plan_doc": str(web_plan_file),
    "web_todo_doc": str(web_todo_file),
    "web_readme": str(web_readme_file),
    "owners_doc": str(owners_file),
    "research_doc": str(research_file),
    "priority_lanes": priorities,
    "open_task_count": len(open_todos_all) + len(web_open_todos_all) + len(global_open_tasks_all),
    "open_tasks": open_tasks,
    "intelligence_open_todo_count": len(open_todos_all),
    "intelligence_open_todos": open_tasks,
    "web_open_task_count": len(web_open_todos_all),
    "web_open_tasks": web_open_tasks,
    "global_open_task_count": len(global_open_tasks_all),
    "global_open_tasks": global_open_tasks,
    "owners": owners,
    "research": research,
    "extension_repos": extension_repos,
    "web_platform_health": web_health,
    "kill_life_memory": {
        "json": str(kill_life_memory_json) if kill_life_memory_json.exists() else "",
        "markdown": str(kill_life_memory_md) if kill_life_memory_md.exists() else "",
    },
    "intelligence_views": {
        "scorecard": scorecard_view,
        "comparison": comparison_view,
        "recommendations": recommendations_view,
    },
}

if action == "memory":
    latest_json = artifact_dir / "latest.json"
    latest_md = artifact_dir / "latest.md"
    md_lines = [
        "# Intelligence program snapshot",
        "",
        f"- generated_at: {payload['generated_at']}",
        f"- status: {payload['status']}",
        f"- open_task_count: {payload['open_task_count']}",
        "",
        "## Priority lanes",
    ]
    for lane, items in priorities.items():
        md_lines.append(f"- {lane.upper()}: {', '.join(items) if items else 'none'}")
    md_lines.extend(["", "## Open tasks"])
    if open_tasks:
        md_lines.extend([f"- {item}" for item in open_tasks])
    else:
        md_lines.append("- none")
    md_lines.extend(["", "## Web Git EDA carry-over"])
    if web_open_tasks:
        md_lines.extend([f"- {item}" for item in web_open_tasks])
    else:
        md_lines.append("- none")
    md_lines.extend(["", "## Global carry-over"])
    if global_open_tasks:
        md_lines.extend([f"- {item}" for item in global_open_tasks])
    else:
        md_lines.append("- none")
    md_lines.extend(["", "## Extension repos"])
    for repo in extension_repos:
        md_lines.append(
            f"- {repo['name']}: branch={repo['branch'] or 'n/a'} dirty={repo['dirty_count']} version={repo['version'] or 'n/a'} terminal_app={repo['has_terminal_app']}"
        )
    md_lines.extend(["", "## Web platform health"])
    md_lines.append(f"- status: {web_health['status']} ({web_health['up_count']}/{web_health['total']} probes up)")
    for probe_name, probe_data in web_health.get("probes", {}).items():
        extra = f" depth={probe_data['depth']}" if "depth" in probe_data else ""
        md_lines.append(f"- {probe_name}: {probe_data['status']}{extra}")
    md_lines.extend(["", "## Derived views"])
    md_lines.append(f"- scorecard: {scorecard_view['json']} | {scorecard_view['markdown']}")
    md_lines.append(f"- comparison: {comparison_view['json']} | {comparison_view['markdown']}")
    md_lines.append(f"- recommendations: {recommendations_view['json']} | {recommendations_view['markdown']}")
    payload["artifacts"].extend([str(latest_json), str(latest_md)])
    payload["memory_artifacts"] = {
        "json": str(latest_json),
        "markdown": str(latest_md),
        "kill_life_json": str(kill_life_memory_json) if kill_life_memory_json.exists() else "",
        "kill_life_markdown": str(kill_life_memory_md) if kill_life_memory_md.exists() else "",
    }
    latest_md.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    latest_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print(json.dumps(payload, ensure_ascii=False))
PY
}

render_snapshot_text() {
  python3 - "${ACTION}" "${1}" <<'PY'
from __future__ import annotations

import json
import sys

action = sys.argv[1]
payload = json.loads(sys.argv[2])

if action == "owners":
    print("# Intelligence owners")
    print()
    for row in payload.get("owners", []):
        print(f"- {row.get('Lead')}: {row.get('Sous-agents')} | {row.get('Compétences')} | backlog: {row.get('Backlog initial')}")
    raise SystemExit(0)

if action == "todo":
    print("# Intelligence open tasks")
    print()
    for item in payload.get("open_tasks", []):
        print(f"- {item}")
    if payload.get("web_open_tasks"):
        print()
        print("## Web Git EDA carry-over")
        print()
        for item in payload.get("web_open_tasks", []):
            print(f"- {item}")
    if payload.get("global_open_tasks"):
        print()
        print("## Global carry-over")
        print()
        for item in payload.get("global_open_tasks", []):
            print(f"- {item}")
    raise SystemExit(0)

if action == "research":
    def pick(row: dict[str, str], *keys: str) -> str:
        for key in keys:
            value = row.get(key)
            if value:
                return value
        return "n/a"

    print("# Intelligence research")
    print()
    for row in payload.get("research", []):
        print(
            f"- {pick(row, 'Source officielle', 'Pattern / source primaire', 'Projet / source')}: "
            f"{pick(row, 'Signal verifie', 'Signal utile', 'Signal utile pour Kill_LIFE')} | "
            f"decision: {pick(row, 'Decision Kill_LIFE', 'Adoption concrète', 'Decision', 'Decision ', 'Decision pour Kill_LIFE')}"
        )
    raise SystemExit(0)

if action == "memory":
    print("# Intelligence memory")
    print()
    print(f"- status: {payload.get('status')}")
    print(f"- open_task_count: {payload.get('open_task_count')}")
    for key, value in (payload.get("memory_artifacts") or {}).items():
        print(f"- {key}: {value}")
    kill_life = payload.get("kill_life_memory") or {}
    print(f"- kill_life_json: {kill_life.get('json', '')}")
    print(f"- kill_life_markdown: {kill_life.get('markdown', '')}")
    for name, view in (payload.get("intelligence_views") or {}).items():
        print(f"- {name}: {view.get('json')} | {view.get('markdown')}")
    raise SystemExit(0)

if action == "next-actions":
    print("# Intelligence next actions")
    print()
    for step in payload.get("next_steps", []):
        print(f"- {step}")
    raise SystemExit(0)

print("# Intelligence status")
print()
print(f"- status: {payload.get('status')}")
print(f"- open_task_count: {payload.get('open_task_count')}")
print("- next_steps:")
for step in payload.get("next_steps", []):
    print(f"  - {step}")
print("- canonical_sources:")
for source in payload.get("canonical_sources", []):
    print(f"  - {source.get('label')}: {source.get('path')}")
print("- extension_repos:")
for repo in payload.get("extension_repos", []):
    print(
        f"  - {repo.get('name')}: branch={repo.get('branch') or 'n/a'} dirty={repo.get('dirty_count')} version={repo.get('version') or 'n/a'} terminal_app={repo.get('has_terminal_app')}"
    )
print("- priorities:")
for lane, items in (payload.get("priority_lanes") or {}).items():
    print(f"  - {lane.upper()}: {', '.join(items) if items else 'none'}")
wph = payload.get("web_platform_health") or {}
print(f"- web_platform: {wph.get('status', 'unknown')} ({wph.get('up_count', 0)}/{wph.get('total', 0)} probes up)")
for probe_name, probe_data in (wph.get("probes") or {}).items():
    extra = f" depth={probe_data.get('depth')}" if "depth" in probe_data else ""
    print(f"  - {probe_name}: {probe_data.get('status', 'unknown')}{extra}")
PY
}

emit_scorecard_json() {
  python3 - "${ROOT_DIR}" "${1}" <<'PY'
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
payload = json.loads(sys.argv[2])
views = payload.get("intelligence_views") or {}
scorecard_view = views.get("scorecard") or {}
scorecard_json_path = Path(scorecard_view.get("json") or root / "artifacts" / "cockpit" / "intelligence_program" / "scorecard_latest.json")
scorecard_md_path = Path(scorecard_view.get("markdown") or root / "artifacts" / "cockpit" / "intelligence_program" / "scorecard_latest.md")


def unique_paths(paths: list[Path]) -> list[Path]:
    seen: set[Path] = set()
    items: list[Path] = []
    for path in paths:
        if path in seen:
            continue
        seen.add(path)
        items.append(path)
    return items


def count_markdown(paths: list[Path]) -> int:
    count = 0
    for base in paths:
        if base.is_file() and base.suffix == ".md":
            count += 1
        elif base.is_dir():
            count += len(list(base.rglob("*.md")))
    return count


def status_from_score(score: int, *, inverse: bool = False) -> str:
    if inverse:
        if score <= 30:
            return "ready"
        if score <= 60:
            return "degraded"
        return "blocked"
    if score >= 85:
        return "ready"
    if score >= 50:
        return "degraded"
    return "blocked"


def relative_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(root))
    except Exception:
        return str(path)


def compact(value: object, max_len: int = 140) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= max_len:
        return text
    return text[: max_len - 3].rstrip() + "..."


entrypoint_paths = [
    root / "README.md",
    root / "docs" / "index.md",
    root / "specs" / "README.md",
    root / "tools" / "cockpit" / "README.md",
    root / "web" / "README.md",
]
reference_bundle_paths = [
    Path(payload.get("audit_doc") or root / "docs" / "KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md"),
    Path(payload.get("spec_doc") or root / "specs" / "agentic_intelligence_integration_spec.md"),
    Path(payload.get("feature_map_doc") or root / "docs" / "AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md"),
    Path(payload.get("plan_doc") or root / "docs" / "plans" / "22_plan_integration_intelligence_agentique.md"),
    Path(payload.get("todo_doc") or root / "docs" / "plans" / "22_todo_integration_intelligence_agentique.md"),
    Path(payload.get("web_spec_doc") or root / "specs" / "yiacad_git_eda_platform_spec.md"),
    Path(payload.get("web_doc") or root / "docs" / "YIACAD_GIT_EDA_PLATFORM_2026-03-22.md"),
    Path(payload.get("web_plan_doc") or root / "docs" / "plans" / "23_plan_yiacad_git_eda_platform.md"),
    Path(payload.get("web_todo_doc") or root / "docs" / "plans" / "23_todo_yiacad_git_eda_platform.md"),
    Path(payload.get("web_readme") or root / "web" / "README.md"),
    Path(payload.get("research_doc") or root / "docs" / "WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md"),
    root / "docs" / "AI_WORKFLOWS.md",
]
documentation_surface_paths = unique_paths(
    [
        root / "README.md",
        root / "docs",
        root / "specs",
        root / "tools" / "cockpit" / "README.md",
        root / "web",
    ]
)

entrypoint_count = sum(1 for path in entrypoint_paths if path.exists())
missing_entrypoints = len(entrypoint_paths) - entrypoint_count
reference_bundle_count = sum(1 for path in reference_bundle_paths if path.exists())
documentation_surface_count = count_markdown(documentation_surface_paths)
fragmentation_score = min(
    100,
    10 + max(0, reference_bundle_count - entrypoint_count) * 6 + int(payload.get("intelligence_open_todo_count") or 0) * 8 + missing_entrypoints * 18,
)
fragmentation_status = status_from_score(fragmentation_score, inverse=True)

lane_maturity = []


def add_lane(lane: str, owner_agent: str, owner_subagent: str, signals: list[tuple[str, bool]]) -> None:
    satisfied = [label for label, ok in signals if ok]
    missing = [label for label, ok in signals if not ok]
    score = round((len(satisfied) / len(signals)) * 100) if signals else 0
    lane_maturity.append(
        {
            "lane": lane,
            "owner_agent": owner_agent,
            "owner_subagent": owner_subagent,
            "score": score,
            "status": status_from_score(score),
            "satisfied": satisfied,
            "missing": missing,
        }
    )


memory_json = root / "artifacts" / "cockpit" / "intelligence_program" / "latest.json"
memory_md = root / "artifacts" / "cockpit" / "intelligence_program" / "latest.md"
runtime_gateway_json = root / "artifacts" / "cockpit" / "runtime_ai_gateway" / "latest.json"
runtime_gateway_md = root / "artifacts" / "cockpit" / "runtime_ai_gateway" / "latest.md"
studio_root = root.parent / "kill-life-studio"
mesh_root = root.parent / "kill-life-mesh"
operator_root = root.parent / "kill-life-operator"
web_root = root / "web"

add_lane(
    "Program-Governance",
    "PM-Mesh",
    "Plan-Orchestrator",
    [
        ("spec", Path(payload.get("spec_doc") or "").exists()),
        ("plan", Path(payload.get("plan_doc") or "").exists()),
        ("todo", Path(payload.get("todo_doc") or "").exists()),
        ("memory-json", memory_json.exists()),
        ("next-actions", bool(payload.get("next_steps"))),
    ],
)
add_lane(
    "Contracts",
    "Mesh-Contracts",
    "Contract-View",
    [
        ("summary-short-schema", (root / "specs" / "contracts" / "summary_short.schema.json").exists()),
        ("runtime-gateway-schema", (root / "specs" / "contracts" / "runtime_mcp_ia_gateway.schema.json").exists()),
        ("intelligence-tui", (root / "tools" / "cockpit" / "intelligence_tui.sh").exists()),
        ("runtime-gateway", (root / "tools" / "cockpit" / "runtime_ai_gateway.sh").exists()),
    ],
)
add_lane(
    "Runtime-Gateway",
    "Runtime-Companion",
    "MCP-Health",
    [
        ("gateway-script", (root / "tools" / "cockpit" / "runtime_ai_gateway.sh").exists()),
        ("gateway-json", runtime_gateway_json.exists()),
        ("gateway-markdown", runtime_gateway_md.exists()),
        ("mascarade-health", (root / "tools" / "cockpit" / "mascarade_runtime_health.sh").exists()),
    ],
)
add_lane(
    "Docs-Continuity",
    "Docs-Research",
    "Runbook-Editor",
    [
        ("readme", (root / "README.md").exists()),
        ("docs-index", (root / "docs" / "index.md").exists()),
        ("cockpit-readme", (root / "tools" / "cockpit" / "README.md").exists()),
        ("ai-workflows", (root / "docs" / "AI_WORKFLOWS.md").exists()),
        ("web-readme", (root / "web" / "README.md").exists()),
        ("fragmentation<=30", fragmentation_score <= 30),
    ],
)
add_lane(
    "QA-Compliance",
    "QA-Compliance",
    "Shell-Harness",
    [
        ("intelligence-contract-test", (root / "test" / "test_intelligence_tui_contract.py").exists()),
        ("runtime-gateway-test", (root / "test" / "test_runtime_ai_gateway_contract.py").exists()),
        ("stable-suite-runner", (root / "tools" / "test_python.sh").exists()),
        ("legacy-wrapper", (root / "tools" / "cockpit" / "intelligence_program_tui.sh").exists()),
    ],
)
add_lane(
    "Extensions-Consumption",
    "Studio-Product",
    "Context-Builder",
    [
        ("studio-governance", (studio_root / "src" / "governance.ts").exists()),
        ("mesh-governance", (mesh_root / "src" / "governance.ts").exists()),
        ("operator-governance", (operator_root / "src" / "governance.ts").exists()),
        ("studio-cli", (studio_root / "src" / "cli.ts").exists()),
        ("mesh-cli", (mesh_root / "src" / "cli.ts").exists()),
        ("operator-cli", (operator_root / "src" / "cli.ts").exists()),
    ],
)
add_lane(
    "Web-Git-EDA",
    "Web-CAD-Platform",
    "Realtime-Collab",
    [
        ("web-spec", Path(payload.get("web_spec_doc") or "").exists()),
        ("web-plan", Path(payload.get("web_plan_doc") or "").exists()),
        ("web-todo", Path(payload.get("web_todo_doc") or "").exists()),
        ("web-readme", Path(payload.get("web_readme") or "").exists()),
        ("web-app", (web_root / "app" / "page.tsx").exists()),
        ("graphql-route", (web_root / "app" / "api" / "graphql" / "route.ts").exists()),
        ("realtime-server", (web_root / "realtime" / "server.mjs").exists()),
        ("eda-worker", (web_root / "workers" / "eda-worker.mjs").exists()),
    ],
)

overall_maturity_score = round(sum(item["score"] for item in lane_maturity) / len(lane_maturity)) if lane_maturity else 0
overall_maturity_status = status_from_score(overall_maturity_score)
status = "done" if fragmentation_status == "ready" and overall_maturity_status == "ready" else "degraded"
degraded_reasons = []
if fragmentation_status != "ready":
    degraded_reasons.append(f"documentation-fragmentation={fragmentation_score}")
for lane in lane_maturity:
    if lane["status"] != "ready":
        degraded_reasons.append(f"{lane['lane'].lower()}={lane['status']}")

summary_short = compact(
    f"fragmentation={fragmentation_score}/100 ({fragmentation_status}) overall_maturity={overall_maturity_score}/100 "
    f"lanes_ready={sum(1 for item in lane_maturity if item['status'] == 'ready')}/{len(lane_maturity)}"
)
scorecard_payload = {
    "contract_version": "cockpit-v1",
    "component": "intelligence_tui",
    "action": "scorecard",
    "status": status,
    "contract_status": "ok" if status == "done" else "degraded",
    "generated_at": payload.get("generated_at") or datetime.now().astimezone().isoformat(),
    "log_file": payload.get("log_file"),
    "artifacts": [payload.get("log_file"), str(scorecard_json_path), str(scorecard_md_path)],
    "degraded_reasons": degraded_reasons,
    "next_steps": list(payload.get("next_steps") or [])[:3],
    "fragmentation_score": fragmentation_score,
    "fragmentation_scale": "0=coherent 100=fragmented",
    "fragmentation_status": fragmentation_status,
    "entrypoint_count": entrypoint_count,
    "reference_bundle_count": reference_bundle_count,
    "documentation_surface_count": documentation_surface_count,
    "overall_maturity_score": overall_maturity_score,
    "overall_maturity_status": overall_maturity_status,
    "lane_maturity": lane_maturity,
    "summary_short": summary_short,
}

scorecard_json_path.parent.mkdir(parents=True, exist_ok=True)
scorecard_json_path.write_text(json.dumps(scorecard_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lines = [
    "# Intelligence scorecard",
    "",
    f"- generated_at: {scorecard_payload['generated_at']}",
    f"- fragmentation_score: {fragmentation_score}/100 ({fragmentation_status})",
    f"- overall_maturity_score: {overall_maturity_score}/100 ({overall_maturity_status})",
    f"- documentation_surface_count: {documentation_surface_count}",
    f"- entrypoint_count: {entrypoint_count}",
    f"- reference_bundle_count: {reference_bundle_count}",
    "",
    "## Lane maturity",
    "",
    "| Lane | Owner | Score | Status | Missing |",
    "| --- | --- | --- | --- | --- |",
]
for lane in lane_maturity:
    missing = ", ".join(lane["missing"]) if lane["missing"] else "none"
    lines.append(
        f"| {lane['lane']} | {lane['owner_agent']}/{lane['owner_subagent']} | {lane['score']} | {lane['status']} | {missing} |"
    )
scorecard_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(json.dumps(scorecard_payload, ensure_ascii=False))
PY
}

render_scorecard_text() {
  python3 - "${1}" <<'PY'
from __future__ import annotations

import json
import sys

payload = json.loads(sys.argv[1])
print("# Intelligence scorecard")
print()
print(f"- fragmentation_score: {payload.get('fragmentation_score')}/100 ({payload.get('fragmentation_status')})")
print(f"- overall_maturity_score: {payload.get('overall_maturity_score')}/100 ({payload.get('overall_maturity_status')})")
print(f"- documentation_surface_count: {payload.get('documentation_surface_count')}")
print("- lane_maturity:")
for lane in payload.get("lane_maturity", []):
    missing = ", ".join(lane.get("missing") or []) or "none"
    print(f"  - {lane.get('lane')}: score={lane.get('score')} status={lane.get('status')} owner={lane.get('owner_agent')}/{lane.get('owner_subagent')} missing={missing}")
PY
}

emit_comparison_json() {
  python3 - "${ROOT_DIR}" "${1}" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
payload = json.loads(sys.argv[2])
views = payload.get("intelligence_views") or {}
comparison_view = views.get("comparison") or {}
comparison_json_path = Path(comparison_view.get("json") or root / "artifacts" / "cockpit" / "intelligence_program" / "repo_comparison_latest.json")
comparison_md_path = Path(comparison_view.get("markdown") or root / "artifacts" / "cockpit" / "intelligence_program" / "repo_comparison_latest.md")


def compact(value: object, max_len: int = 160) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= max_len:
        return text
    return text[: max_len - 3].rstrip() + "..."


def status_from_score(score: int) -> str:
    if score >= 85:
        return "ready"
    if score >= 50:
        return "degraded"
    return "blocked"


def relative_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(root))
    except Exception:
        return str(path)


def git_capture(repo_path: Path, args: list[str]) -> str | None:
    proc = subprocess.run(
        ["git", "-C", str(repo_path), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def repo_record(name: str, path: Path, role: str, kind: str, expected: list[str], governance_signal: str) -> dict[str, object]:
    package_file = path / "package.json"
    package_data = {}
    if package_file.exists():
        try:
            package_data = json.loads(package_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            package_data = {}
    capabilities = {
        "readme": (path / "README.md").exists(),
        "docs_index": (path / "docs" / "index.md").exists(),
        "specs_readme": (path / "specs" / "README.md").exists(),
        "web_stack": (path / "web" / "package.json").exists(),
        "cockpit": (path / "tools" / "cockpit" / "intelligence_tui.sh").exists(),
        "runtime_gateway": (path / "tools" / "cockpit" / "runtime_ai_gateway.sh").exists(),
        "package": package_file.exists(),
        "cli": (path / "src" / "cli.ts").exists(),
        "terminal_app": (path / "src" / "terminalApp.ts").exists(),
        "governance": (path / "src" / "governance.ts").exists(),
        "tests": (path / "test").exists() or bool(list((path / "src" / "test" / "suite").glob("*.ts"))) if (path / "src" / "test" / "suite").exists() else False,
        "workspace_fixture": bool(list(path.rglob("*.code-workspace"))),
        "memory": (path / "artifacts" / "cockpit" / "intelligence_program" / "latest.json").exists(),
    }
    branch = git_capture(path, ["branch", "--show-current"])
    dirty_output = git_capture(path, ["status", "--short"]) or ""
    dirty_count = len([line for line in dirty_output.splitlines() if line.strip()])
    version = package_data.get("version")
    fit_hits = sum(1 for key in expected if capabilities.get(key))
    fit_for_role_score = round((fit_hits / len(expected)) * 100) if expected else 100
    fit_status = status_from_score(fit_for_role_score)
    enabled_capabilities = [key for key, value in capabilities.items() if value]
    summary_short = compact(
        f"{role}; fit={fit_for_role_score}/100 ({fit_status}); branch={branch or 'n/a'}; dirty={dirty_count}; "
        f"capabilities={','.join(enabled_capabilities[:5]) or 'none'}"
    )
    return {
        "name": name,
        "path": str(path),
        "relative_path": relative_path(path),
        "exists": path.exists(),
        "role": role,
        "kind": kind,
        "governance_signal": governance_signal,
        "branch": branch,
        "dirty_count": dirty_count,
        "version": version,
        "fit_for_role_score": fit_for_role_score,
        "fit_status": fit_status,
        "capabilities": capabilities,
        "enabled_capabilities": enabled_capabilities,
        "summary_short": summary_short,
    }


repos = [
    repo_record(
        "Kill_LIFE",
        root,
        "control plane public, docs, cockpit, contracts",
        "control-plane",
        ["readme", "docs_index", "specs_readme", "cockpit", "runtime_gateway", "tests", "memory"],
        "producer",
    ),
    repo_record(
        "ai-agentic-embedded-base",
        root / "ai-agentic-embedded-base",
        "baseline spec-first embedded companion",
        "knowledge-base",
        ["readme", "specs_readme"],
        "documented-companion",
    ),
    repo_record(
        "kill-life-studio",
        root.parent / "kill-life-studio",
        "product pilot extension",
        "vscode-extension",
        ["readme", "package", "cli", "terminal_app", "governance", "tests", "workspace_fixture"],
        "consumer",
    ),
    repo_record(
        "kill-life-mesh",
        root.parent / "kill-life-mesh",
        "orchestration extension",
        "vscode-extension",
        ["readme", "package", "cli", "terminal_app", "governance", "tests"],
        "consumer",
    ),
    repo_record(
        "kill-life-operator",
        root.parent / "kill-life-operator",
        "operator evidence extension",
        "vscode-extension",
        ["readme", "package", "cli", "terminal_app", "governance", "tests"],
        "consumer",
    ),
]

highlights = [
    "Kill_LIFE reste l'unique producteur du cockpit canonique, de la memoire intelligence et de la gateway runtime/MCP/IA.",
    "ai-agentic-embedded-base sert de compagnon spec-first et non d'extension VS Code; il reste compare comme reference de contenu, pas comme surface produit.",
    "Studio, Mesh et Operator partagent maintenant le meme socle governance + terminal app, puis se differencient par leur promesse produit.",
]
missing_repos = [repo["name"] for repo in repos if not repo["exists"]]
status = "done" if not missing_repos else "degraded"
comparison_payload = {
    "contract_version": "cockpit-v1",
    "component": "intelligence_tui",
    "action": "comparison",
    "status": status,
    "contract_status": "ok" if status == "done" else "degraded",
    "generated_at": payload.get("generated_at") or datetime.now().astimezone().isoformat(),
    "log_file": payload.get("log_file"),
    "artifacts": [payload.get("log_file"), str(comparison_json_path), str(comparison_md_path)],
    "degraded_reasons": [f"missing-repo:{name}" for name in missing_repos],
    "next_steps": list(payload.get("next_steps") or [])[:3],
    "comparison_axes": [
        "role",
        "governance_signal",
        "fit_for_role_score",
        "dirty_count",
        "version",
        "enabled_capabilities",
    ],
    "repos": repos,
    "highlights": highlights,
    "summary_short": compact(
        f"{len(repos)} repos compares; producer=Kill_LIFE; companions=ai-agentic-embedded-base; consumers=studio/mesh/operator."
    ),
}

comparison_json_path.parent.mkdir(parents=True, exist_ok=True)
comparison_json_path.write_text(json.dumps(comparison_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lines = [
    "# Intelligence repo comparison",
    "",
    f"- generated_at: {comparison_payload['generated_at']}",
    "",
    "| Repo | Kind | Governance | Fit | Dirty | Version | Key capabilities |",
    "| --- | --- | --- | --- | --- | --- | --- |",
]
for repo in repos:
    capabilities = ", ".join(repo["enabled_capabilities"][:5]) or "none"
    lines.append(
        f"| {repo['name']} | {repo['kind']} | {repo['governance_signal']} | {repo['fit_for_role_score']} ({repo['fit_status']}) | "
        f"{repo['dirty_count']} | {repo['version'] or 'n/a'} | {capabilities} |"
    )
lines.extend(["", "## Highlights", ""])
lines.extend([f"- {item}" for item in highlights])
comparison_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(json.dumps(comparison_payload, ensure_ascii=False))
PY
}

render_comparison_text() {
  python3 - "${1}" <<'PY'
from __future__ import annotations

import json
import sys

payload = json.loads(sys.argv[1])
print("# Intelligence repo comparison")
print()
for repo in payload.get("repos", []):
    caps = ", ".join(repo.get("enabled_capabilities", [])[:5]) or "none"
    print(
        f"- {repo.get('name')}: role={repo.get('role')} governance={repo.get('governance_signal')} "
        f"fit={repo.get('fit_for_role_score')}/100 ({repo.get('fit_status')}) dirty={repo.get('dirty_count')} "
        f"version={repo.get('version') or 'n/a'} caps={caps}"
    )
print()
print("## Highlights")
print()
for item in payload.get("highlights", []):
    print(f"- {item}")
PY
}

emit_recommendations_json() {
  python3 - "${ROOT_DIR}" "${1}" <<'PY'
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

root = Path(sys.argv[1])
payload = json.loads(sys.argv[2])
views = payload.get("intelligence_views") or {}
recommendation_view = views.get("recommendations") or {}
recommendation_json_path = Path(recommendation_view.get("json") or root / "artifacts" / "cockpit" / "intelligence_program" / "recommendation_queue_latest.json")
recommendation_md_path = Path(recommendation_view.get("markdown") or root / "artifacts" / "cockpit" / "intelligence_program" / "recommendation_queue_latest.md")


def compact(value: object, max_len: int = 220) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= max_len:
        return text
    return text[: max_len - 3].rstrip() + "..."


priority_rank = {"P0": 0, "P1": 1, "P2": 2}
global_open_tasks = list(payload.get("global_open_tasks") or [])
audit_source = str(Path(payload.get("audit_doc") or root / "docs" / "KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md"))
research_source = str(Path(payload.get("research_doc") or root / "docs" / "WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md"))
web_plan_source = str(Path(payload.get("web_plan_doc") or root / "docs" / "plans" / "23_plan_yiacad_git_eda_platform.md"))
web_spec_source = str(Path(payload.get("web_spec_doc") or root / "specs" / "yiacad_git_eda_platform_spec.md"))

queue = [
    {
        "id": "AI-RQ-101",
        "priority": "P0",
        "status": "active",
        "mode": "piloté",
        "title": "Remplacer le faux save local par un read model Git reel pour le produit web",
        "owner_agent": "Web-CAD-Platform",
        "owner_subagent": "Project-Service",
        "why_now": "Le shell web reste une demo locale tant que le save, la review et la PR ne derivent pas d'un vrai etat Git.",
        "write_set": [
            "web/lib/project-store.ts",
            "web/lib/graphql/schema.ts",
            "web/app/api/graphql/route.ts",
            "docs/plans/23_todo_yiacad_git_eda_platform.md",
        ],
        "sources": [
            audit_source,
            web_plan_source,
            web_spec_source,
            "https://www.gitea.com/",
        ],
        "next_step": "Ajouter un read model Git minimal pour branche courante, fichiers modifies, PR review et save snapshot sans ecriture filesystem opaque.",
    },
    {
        "id": "AI-RQ-102",
        "priority": "P0",
        "status": "active",
        "mode": "piloté",
        "title": "Fermer la boucle CI/artifacts entre worker, GraphQL et UI",
        "owner_agent": "Web-CAD-Platform",
        "owner_subagent": "EDA-CI-Orchestrator",
        "why_now": "Le worker ecrit des statuts et artifacts, mais l'UI ne consomme pas encore de surfaces web-servables ni de statuts live.",
        "write_set": [
            "web/workers/eda-worker.mjs",
            "web/lib/graphql/schema.ts",
            "web/components/pcb-workbench.tsx",
            "web/components/pr-review-shell.tsx",
        ],
        "sources": [
            audit_source,
            web_plan_source,
            web_spec_source,
            "https://docs.bullmq.io/",
        ],
        "next_step": "Servir les artifacts via une route web dediee, exposer des URLs relatives et ajouter au minimum un polling simple cote UI.",
    },
    {
        "id": "AI-RQ-103",
        "priority": "P1",
        "status": "proposed",
        "mode": "piloté",
        "title": "Binder Excalidraw a Yjs sans casser la source de verite Git",
        "owner_agent": "Web-CAD-Platform",
        "owner_subagent": "Realtime-Collab",
        "why_now": "La presence et le transport Yjs existent deja, mais la scene Excalidraw reste locale et coupee du systeme de collab.",
        "write_set": [
            "web/components/excalidraw-canvas.tsx",
            "web/components/project-shell.tsx",
            "web/realtime/*",
            "docs/plans/23_todo_yiacad_git_eda_platform.md",
        ],
        "sources": [
            research_source,
            web_plan_source,
            "https://docs.yjs.dev/",
            "https://github.com/excalidraw/excalidraw",
        ],
        "next_step": "Ajouter un adaptateur Yjs pour la scene et conserver le save manuel comme checkpoint Git explicite.",
    },
    {
        "id": "AI-RQ-104",
        "priority": "P1",
        "status": "proposed",
        "mode": "piloté",
        "title": "Ouvrir un bridge lecture seule entre le produit web et la lane intelligence",
        "owner_agent": "Runtime-Companion",
        "owner_subagent": "Review-Assist",
        "why_now": "Le produit web ne consomme encore ni health MCP, ni ops summary, ni hints de review issus des fichiers modifies et des sorties ERC/DRC.",
        "write_set": [
            "web/lib/graphql/schema.ts",
            "web/components/pr-review-shell.tsx",
            "web/components/dashboard-shell.tsx",
            "docs/AI_WORKFLOWS.md",
        ],
        "sources": [
            audit_source,
            research_source,
            "https://developers.openai.com/api/docs/guides/tools",
            "https://modelcontextprotocol.io/docs/getting-started/intro",
        ],
        "next_step": "Exposer un `opsSummary` ou un `reviewHints` minimal en lecture seule avant toute tentative d'action outillee.",
    },
    {
        "id": "AI-RQ-105",
        "priority": "P2",
        "status": "deferred",
        "mode": "assisté",
        "title": "Formaliser le boundary MCP/service-first pour parts, CI, artifacts et review assist",
        "owner_agent": "Runtime-Companion",
        "owner_subagent": "MCP-Health",
        "why_now": "Le produit a besoin d'outils clairs, mais pas d'un orchestrateur stateful avant la fermeture des gaps Git, CI et realtime.",
        "write_set": [
            "docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-22.md",
            "docs/plans/22_plan_integration_intelligence_agentique.md",
            "docs/plans/23_plan_yiacad_git_eda_platform.md",
        ],
        "sources": [
            research_source,
            "https://modelcontextprotocol.io/docs/getting-started/intro",
            "https://openai.github.io/openai-agents-python/",
            "https://docs.langchain.com/oss/python/langgraph/overview",
        ],
        "next_step": "Garder LangGraph/Agents SDK comme overlays optionnels tant que le boundary outille n'est pas formellement ecrit.",
    },
]
queue.sort(key=lambda item: (priority_rank[item["priority"]], item["id"]))
active_priorities = [item["priority"] for item in queue if item["status"] in {"active", "proposed"}]
status = "degraded" if active_priorities else "done"
summary_short = compact(
    f"Top recommendation={queue[0]['id']} {queue[0]['priority']} {queue[0]['title']} | total={len(queue)}"
)
recommendation_payload = {
    "contract_version": "cockpit-v1",
    "component": "intelligence_tui",
    "action": "recommendations",
    "status": status,
    "contract_status": "degraded" if status != "done" else "ok",
    "generated_at": payload.get("generated_at") or datetime.now().astimezone().isoformat(),
    "log_file": payload.get("log_file"),
    "artifacts": [payload.get("log_file"), str(recommendation_json_path), str(recommendation_md_path)],
    "degraded_reasons": [f"open-recommendation:{item['id']}" for item in queue if item["status"] in {"active", "proposed"}][:3],
    "next_steps": [item["next_step"] for item in queue[:3]],
    "queue": queue,
    "summary_short": summary_short,
}

recommendation_json_path.parent.mkdir(parents=True, exist_ok=True)
recommendation_json_path.write_text(json.dumps(recommendation_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lines = [
    "# AI recommendation queue",
    "",
    f"- generated_at: {recommendation_payload['generated_at']}",
    f"- status: {recommendation_payload['status']}",
    "",
    "| Priority | Id | Status | Owner | Recommendation |",
    "| --- | --- | --- | --- | --- |",
]
for item in queue:
    lines.append(
        f"| {item['priority']} | {item['id']} | {item['status']} | {item['owner_agent']}/{item['owner_subagent']} | {item['title']} |"
    )
lines.extend(["", "## Next steps", ""])
lines.extend([f"- {item['next_step']}" for item in queue[:5]])
recommendation_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(json.dumps(recommendation_payload, ensure_ascii=False))
PY
}

render_recommendations_text() {
  python3 - "${1}" <<'PY'
from __future__ import annotations

import json
import sys

payload = json.loads(sys.argv[1])
print("# AI recommendation queue")
print()
for item in payload.get("queue", []):
    print(
        f"- {item.get('priority')} {item.get('id')}: {item.get('title')} "
        f"[{item.get('status')}] owner={item.get('owner_agent')}/{item.get('owner_subagent')}"
    )
    print(f"  next: {item.get('next_step')}")
PY
}

emit_summary_short_json() {
  python3 - "${ROOT_DIR}" "${1}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
payload = json.loads(sys.argv[2])


def compact(value: object, max_len: int = 120) -> str:
    text = " ".join(str(value or "").split())
    if not text:
        return "none"
    if len(text) <= max_len:
        return text
    return text[: max_len - 3].rstrip() + "..."


def normalize_status(value: object) -> str:
    text = str(value or "").strip().lower()
    if text in {"ready", "done", "ok", "success"}:
        return "ready"
    if text in {"blocked", "error", "failed", "fail"}:
        return "blocked"
    return "degraded"


def relative_path(value: object) -> str:
    path = Path(str(value or ""))
    if not path:
        return "missing"
    try:
        return str(path.resolve().relative_to(root))
    except Exception:
        return str(path)


priority_lane = "none"
priority_item = "none"
for lane in ("p0", "p1", "p2"):
    items = (payload.get("priority_lanes") or {}).get(lane) or []
    if items:
        priority_lane = lane.upper()
        priority_item = compact(items[0], 96)
        break

next_steps = list(payload.get("next_steps") or [])[:3]
degraded_reasons = [compact(item, 96) for item in list(payload.get("degraded_reasons") or [])[:3]]
if not degraded_reasons:
    degraded_reasons = ["none"]
first_next_step = compact(next_steps[0] if next_steps else "none", 120)
open_task_count = int(payload.get("open_task_count") or 0)
intelligence_open_todo_count = int(payload.get("intelligence_open_todo_count") or 0)
global_open_task_count = int(payload.get("global_open_task_count") or 0)
status = normalize_status(payload.get("status"))
owner_repo = "Kill_LIFE"
owner_agent = "PM-Mesh"
owner_subagent = "Plan-Orchestrator"
write_set = [
    "specs/agentic_intelligence_integration_spec.md",
    "docs/plans/22_plan_integration_intelligence_agentique.md",
    "docs/plans/22_todo_integration_intelligence_agentique.md",
    "docs/AI_WORKFLOWS.md",
    "tools/cockpit/intelligence_tui.sh",
]
memory_artifacts = payload.get("memory_artifacts") or {}
evidence = []
for item in [
    memory_artifacts.get("json") or str(root / "artifacts" / "cockpit" / "intelligence_program" / "latest.json"),
    memory_artifacts.get("markdown") or str(root / "artifacts" / "cockpit" / "intelligence_program" / "latest.md"),
    payload.get("log_file"),
    payload.get("spec_doc"),
    payload.get("plan_doc"),
]:
    if item:
        value = relative_path(item)
        if value not in evidence:
            evidence.append(value)

goal = "Stabiliser la gouvernance intelligence canonique et la memoire courte exploitable."
state = (
    f"status={status} open_tasks={open_task_count} intelligence_open={intelligence_open_todo_count} "
    f"global_open={global_open_task_count} priority={priority_lane}:{priority_item}"
)
blockers = ", ".join(degraded_reasons[:2])
next_label = ", ".join(compact(step, 96) for step in next_steps[:2]) if next_steps else "none"
summary_short = compact(
    f"goal={goal} | state={state} | blockers={blockers} | next={next_label} "
    f"| owner={owner_agent}/{owner_subagent} | evidence={evidence[0] if evidence else 'missing'}",
    320,
)

summary_payload = {
    "contract_version": "summary-short/v1",
    "component": payload.get("component", "intelligence_tui"),
    "action": "summary-short",
    "status": status,
    "generated_at": payload.get("generated_at"),
    "lot_id": "intelligence-governance",
    "owner_repo": owner_repo,
    "owner_agent": owner_agent,
    "owner_subagent": owner_subagent,
    "write_set": write_set,
    "summary_short": summary_short,
    "evidence": evidence,
    "degraded_reasons": list(payload.get("degraded_reasons") or []),
    "next_steps": next_steps,
    "goal": goal,
    "state": state,
    "blockers": degraded_reasons,
    "next": next_steps,
    "owner": f"{owner_agent}/{owner_subagent}",
    "open_task_count": open_task_count,
    "intelligence_open_todo_count": intelligence_open_todo_count,
    "global_open_task_count": global_open_task_count,
    "first_next_step": first_next_step,
    "first_priority_lane": priority_lane,
    "first_priority": priority_item,
    "log_file": payload.get("log_file"),
    "artifacts": payload.get("artifacts") or [],
}

print(json.dumps(summary_payload, ensure_ascii=False))
PY
}

render_summary_short_text() {
  python3 - "${1}" <<'PY'
from __future__ import annotations

import json
import sys

payload = json.loads(sys.argv[1])

for key in (
    "contract_version",
    "component",
    "action",
    "owner_repo",
    "owner_agent",
    "owner_subagent",
    "status",
    "summary_short",
    "open_task_count",
    "intelligence_open_todo_count",
    "global_open_task_count",
    "first_priority_lane",
    "first_priority",
    "first_next_step",
):
    print(f"{key}={payload.get(key, 'none')}")
print(f"evidence={','.join(payload.get('evidence') or [])}")
PY
}

show_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    printf 'Missing file: %s\n' "${file}" >&2
    return 1
  fi
  sed -n "1,${LINES}p" "${file}"
}

resolve_latest_doc() {
  local pattern="$1"
  local fallback="$2"
  python3 - "${ROOT_DIR}" "${pattern}" "${fallback}" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
pattern = sys.argv[2]
fallback = root / sys.argv[3]
matches = sorted(root.glob(pattern))
print(matches[-1] if matches else fallback)
PY
}

emit_logs_summary_json() {
  local latest_file=""
  local count=0
  local stale=0
  if find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' -print -quit | grep -q .; then
    latest_file="$(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | sort | tail -n 1)"
    count="$(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | wc -l | tr -d ' ')"
    stale="$(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' -mtime +"${RETENTION_DAYS}" | wc -l | tr -d ' ')"
  fi

  printf '{\n'
  printf '  "contract_version": "cockpit-v1",\n'
  printf '  "component": "%s",\n' "${COMPONENT}"
  printf '  "action": "logs-summary",\n'
  printf '  "status": "%s",\n' "$([ "${stale}" -gt 0 ] && printf 'degraded' || printf 'done')"
  printf '  "contract_status": "%s",\n' "$([ "${stale}" -gt 0 ] && printf 'degraded' || printf 'ok')"
  printf '  "log_file": "%s",\n' "${RUN_LOG}"
  printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${RUN_LOG}" "${latest_file}")"
  printf '  "degraded_reasons": %s,\n' "$(json_contract_array_from_args $([ "${stale}" -gt 0 ] && printf '%s' "stale-logs-detected"))"
  printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "bash tools/cockpit/intelligence_tui.sh --action purge-logs --days ${RETENTION_DAYS} --apply --json")"
  printf '  "count": %s,\n' "${count}"
  printf '  "stale": %s,\n' "${stale}"
  if [ -n "${latest_file}" ]; then
    printf '  "latest_log": "%s"\n' "${latest_file}"
  else
    printf '  "latest_log": null\n'
  fi
  printf '}\n'
}

render_logs_latest() {
  local latest_file=""
  latest_file="$(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | sort | tail -n 1 || true)"
  if [ -z "${latest_file}" ]; then
    printf 'No intelligence_tui logs found in %s\n' "${ARTIFACT_DIR}"
    return 0
  fi

  printf '# Latest intelligence log\n\n'
  printf -- '- file: %s\n\n' "${latest_file}"
  tail -n 80 "${latest_file}"
}

emit_logs_list_json() {
  local files=()
  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    files+=("${file}")
  done < <(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | sort)

  printf '{\n'
  printf '  "contract_version": "cockpit-v1",\n'
  printf '  "component": "%s",\n' "${COMPONENT}"
  printf '  "action": "logs-list",\n'
  printf '  "status": "done",\n'
  printf '  "contract_status": "ok",\n'
  printf '  "log_file": "%s",\n' "${RUN_LOG}"
  printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${RUN_LOG}" "${files[@]}")"
  printf '  "degraded_reasons": [],\n'
  printf '  "next_steps": [],\n'
  printf '  "logs": %s\n' "$(json_contract_array_from_args "${files[@]}")"
  printf '}\n'
}

emit_purge_logs_json() {
  local stale_files=()
  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    stale_files+=("${file}")
  done < <(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' -mtime +"${RETENTION_DAYS}" -print | sort)

  local deleted_count="${#stale_files[@]}"
  if [ "${deleted_count}" -gt 0 ] && [ "${APPLY}" -eq 1 ]; then
    find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' -mtime +"${RETENTION_DAYS}" -delete
  fi

  printf '{\n'
  printf '  "contract_version": "cockpit-v1",\n'
  printf '  "component": "%s",\n' "${COMPONENT}"
  printf '  "action": "purge-logs",\n'
  printf '  "status": "%s",\n' "$([ "${deleted_count}" -gt 0 ] && [ "${APPLY}" -eq 0 ] && printf 'degraded' || printf 'done')"
  printf '  "contract_status": "%s",\n' "$([ "${deleted_count}" -gt 0 ] && [ "${APPLY}" -eq 0 ] && printf 'degraded' || printf 'ok')"
  printf '  "log_file": "%s",\n' "${RUN_LOG}"
  printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${RUN_LOG}" "${ARTIFACT_DIR}")"
  printf '  "degraded_reasons": %s,\n' "$(json_contract_array_from_args $([ "${deleted_count}" -gt 0 ] && [ "${APPLY}" -eq 0 ] && printf '%s' "dry-run-purge-pending"))"
  printf '  "next_steps": %s,\n' "$(json_contract_array_from_args "bash tools/cockpit/intelligence_tui.sh --action purge-logs --days ${RETENTION_DAYS} --apply --json")"
  printf '  "retention_days": %s,\n' "${RETENTION_DAYS}"
  printf '  "deleted_count": %s,\n' "${deleted_count}"
  printf '  "apply": %s\n' "${APPLY}"
  printf '}\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --days)
      RETENTION_DAYS="${2:-14}"
      shift 2
      ;;
    --limit)
      LIMIT="${2:-8}"
      shift 2
      ;;
    --lines)
      LINES="${2:-120}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "${ACTION}" in
  status|summary-short|scorecard|comparison|recommendations|owners|todo|research|memory|next-actions)
    if [ "${ACTION}" = "summary-short" ]; then
      ensure_run_log
    else
      log_line "INFO" "action=${ACTION}"
    fi
    SNAPSHOT_JSON="$(build_snapshot_json)"
    if [ "${ACTION}" = "summary-short" ]; then
      SUMMARY_SHORT_JSON="$(emit_summary_short_json "${SNAPSHOT_JSON}")"
      if [ "${JSON}" -eq 1 ]; then
        printf '%s\n' "${SUMMARY_SHORT_JSON}"
      else
        render_summary_short_text "${SUMMARY_SHORT_JSON}"
      fi
    elif [ "${ACTION}" = "scorecard" ]; then
      SCORECARD_JSON="$(emit_scorecard_json "${SNAPSHOT_JSON}")"
      if [ "${JSON}" -eq 1 ]; then
        printf '%s\n' "${SCORECARD_JSON}"
      else
        render_scorecard_text "${SCORECARD_JSON}"
      fi
    elif [ "${ACTION}" = "comparison" ]; then
      COMPARISON_JSON="$(emit_comparison_json "${SNAPSHOT_JSON}")"
      if [ "${JSON}" -eq 1 ]; then
        printf '%s\n' "${COMPARISON_JSON}"
      else
        render_comparison_text "${COMPARISON_JSON}"
      fi
    elif [ "${ACTION}" = "recommendations" ]; then
      RECOMMENDATIONS_JSON="$(emit_recommendations_json "${SNAPSHOT_JSON}")"
      if [ "${JSON}" -eq 1 ]; then
        printf '%s\n' "${RECOMMENDATIONS_JSON}"
      else
        render_recommendations_text "${RECOMMENDATIONS_JSON}"
      fi
    elif [ "${JSON}" -eq 1 ]; then
      printf '%s\n' "${SNAPSHOT_JSON}"
    else
      render_snapshot_text "${SNAPSHOT_JSON}"
    fi
    ;;
  audit)
    log_line "INFO" "action=audit"
    show_file "$(resolve_latest_doc "docs/KILL_LIFE_CONSOLIDATION_AUDIT_*.md" "docs/KILL_LIFE_CONSOLIDATION_AUDIT_2026-03-21.md")"
    ;;
  feature-map)
    log_line "INFO" "action=feature-map"
    show_file "$(resolve_latest_doc "docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_*.md" "docs/AGENTIC_INTELLIGENCE_FEATURE_MAP_2026-03-21.md")"
    ;;
  spec)
    log_line "INFO" "action=spec"
    show_file "${ROOT_DIR}/specs/agentic_intelligence_integration_spec.md"
    ;;
  plan)
    log_line "INFO" "action=plan"
    show_file "${ROOT_DIR}/docs/plans/22_plan_integration_intelligence_agentique.md"
    ;;
  logs-summary)
    log_line "INFO" "action=logs-summary"
    if [ "${JSON}" -eq 1 ]; then
      emit_logs_summary_json
    else
      LOGS_JSON="$(emit_logs_summary_json)"
      python3 - "${LOGS_JSON}" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
print("# Intelligence logs summary")
print()
print(f"- count: {payload.get('count')}")
print(f"- stale: {payload.get('stale')}")
print(f"- latest_log: {payload.get('latest_log') or 'none'}")
PY
    fi
    ;;
  logs-list)
    log_line "INFO" "action=logs-list"
    if [ "${JSON}" -eq 1 ]; then
      emit_logs_list_json
    else
      printf '# Intelligence logs list\n\n'
      find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | sort
    fi
    ;;
  logs-latest)
    log_line "INFO" "action=logs-latest"
    if [ "${JSON}" -eq 1 ]; then
      latest_file="$(find "${ARTIFACT_DIR}" -type f -name 'intelligence_tui-*.log' | sort | tail -n 1 || true)"
      printf '{\n'
      printf '  "contract_version": "cockpit-v1",\n'
      printf '  "component": "%s",\n' "${COMPONENT}"
      printf '  "action": "logs-latest",\n'
      printf '  "status": "done",\n'
      printf '  "contract_status": "ok",\n'
      printf '  "log_file": "%s",\n' "${RUN_LOG}"
      printf '  "artifacts": %s,\n' "$(json_contract_array_from_args "${RUN_LOG}" "${latest_file}")"
      printf '  "degraded_reasons": [],\n'
      printf '  "next_steps": [],\n'
      if [ -n "${latest_file}" ]; then
        printf '  "latest_log": "%s"\n' "${latest_file}"
      else
        printf '  "latest_log": null\n'
      fi
      printf '}\n'
    else
      render_logs_latest
    fi
    ;;
  purge-logs)
    log_line "INFO" "action=purge-logs days=${RETENTION_DAYS} apply=${APPLY}"
    if [ "${JSON}" -eq 1 ]; then
      emit_purge_logs_json
    else
      PURGE_JSON="$(emit_purge_logs_json)"
      python3 - "${PURGE_JSON}" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
print("# Intelligence log purge")
print()
print(f"- deleted_count: {payload.get('deleted_count')}")
print(f"- retention_days: {payload.get('retention_days')}")
print(f"- apply: {payload.get('apply')}")
PY
    fi
    ;;
  *)
    printf 'Unsupported action: %s\n' "${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
