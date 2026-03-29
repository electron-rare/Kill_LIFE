#!/usr/bin/env python3
"""Validate the canonical Kill_LIFE 2026 agent catalog and its references."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "specs" / "contracts" / "kill_life_agent_catalog.json"
REQUIRED_DOCS = (
    Path("README.md"),
    Path("README_FR.md"),
    Path("docs/plans/12_plan_gestion_des_agents.md"),
    Path("docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md"),
)
OWNER_AGENT_JSON_ROOT = Path("specs/contracts")
OWNER_AGENT_TEXT_FILES = (
    Path("tools/autonomous_next_lots.py"),
    Path("tools/cad/yiacad_fusion_lot.sh"),
    Path("tools/cockpit/intelligence_tui.sh"),
    Path("tools/cockpit/runtime_ai_gateway.sh"),
)


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _expected_slug(agent_id: str) -> str:
    normalized = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", agent_id)
    return re.sub(r"[^a-z0-9]+", "_", normalized.lower()).strip("_")


def _legacy_doc_patterns(legacy_id: str) -> tuple[re.Pattern[str], ...]:
    escaped = re.escape(legacy_id)
    escaped_agent = re.escape(f"{legacy_id}_agent")
    escaped_start = re.escape(f"start_{legacy_id}_agent")
    escaped_plan = re.escape(f"plan_wizard_{legacy_id}_agent")
    return (
        re.compile(rf"`{escaped}`"),
        re.compile(rf'"{escaped}"'),
        re.compile(rf"'{escaped}'"),
        re.compile(rf"\b{escaped_agent}\b"),
        re.compile(rf"\b{escaped_start}\b"),
        re.compile(rf"\b{escaped_plan}\b"),
    )


def _collect_owner_agent_json(path: Path) -> list[dict[str, str]]:
    payload = _load_json(path)
    found: list[dict[str, str]] = []
    stack: list[Any] = [payload]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            owner_agent = current.get("owner_agent")
            if isinstance(owner_agent, str):
                found.append({"path": path.as_posix(), "owner_agent": owner_agent})
            stack.extend(current.values())
        elif isinstance(current, list):
            stack.extend(current)
    return found


def _collect_owner_agent_text(path: Path) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    text = path.read_text(encoding="utf-8")
    patterns = (
        re.compile(r'owner_agent"\s*:\s*"([^"]+)"'),
        re.compile(r'owner_agent\s*=\s*"([^"]+)"'),
    )
    for pattern in patterns:
        for match in pattern.finditer(text):
            found.append({"path": path.as_posix(), "owner_agent": match.group(1)})
    return found


def validate_agent_catalog(repo_root: Path = ROOT, catalog_path: Path = CATALOG_PATH) -> dict[str, Any]:
    catalog = _load_json(catalog_path)
    agents = catalog.get("agents", [])
    canonical_ids = [agent.get("id", "") for agent in agents]
    legacy_aliases = {str(key): str(value) for key, value in catalog.get("legacy_runtime_aliases", {}).items()}
    errors: list[str] = []

    if catalog.get("contract_version") != "kill-life-agent-catalog/v1":
        errors.append("catalog-contract-version-invalid")
    if catalog.get("repo") != "Kill_LIFE":
        errors.append("catalog-owner-repo-invalid")
    if not agents:
        errors.append("catalog-empty")

    ids_are_unique = len(canonical_ids) == len(set(canonical_ids))
    if not ids_are_unique:
        errors.append("catalog-duplicate-agent-id")

    slugs_are_unique = len([agent.get("slug") for agent in agents]) == len(
        {agent.get("slug") for agent in agents}
    )
    if not slugs_are_unique:
        errors.append("catalog-duplicate-agent-slug")

    invalid_slug_rows: list[dict[str, str]] = []
    missing_files: list[str] = []
    parity_rows: list[dict[str, str]] = []

    for agent in agents:
        agent_id = str(agent.get("id", ""))
        slug = str(agent.get("slug", ""))
        expected_slug = _expected_slug(agent_id)
        if slug != expected_slug:
            invalid_slug_rows.append({"agent_id": agent_id, "slug": slug, "expected_slug": expected_slug})

        required_paths = (
            ("agent_doc", agent.get("agent_doc")),
            ("github_agent_doc", agent.get("github_agent_doc")),
            ("start_prompt", agent.get("start_prompt")),
            ("plan_wizard_prompt", agent.get("plan_wizard_prompt")),
        )
        row: dict[str, str] = {"agent_id": agent_id}
        for field, raw_path in required_paths:
            if not isinstance(raw_path, str) or not raw_path:
                errors.append(f"{agent_id}:{field}-missing")
                continue
            rel_path = Path(raw_path)
            row[field] = rel_path.as_posix()
            if not (repo_root / rel_path).exists():
                missing_files.append(rel_path.as_posix())
        parity_rows.append(row)

    docs_missing_agents: list[dict[str, Any]] = []
    docs_legacy_refs: list[dict[str, Any]] = []
    for rel_path in REQUIRED_DOCS:
        path = repo_root / rel_path
        if not path.exists():
            missing_files.append(rel_path.as_posix())
            continue
        text = path.read_text(encoding="utf-8")
        missing_ids = [agent_id for agent_id in canonical_ids if agent_id not in text]
        if missing_ids:
            docs_missing_agents.append({"path": rel_path.as_posix(), "missing_agents": missing_ids})
        legacy_hits = [
            legacy
            for legacy in legacy_aliases
            if any(pattern.search(text) for pattern in _legacy_doc_patterns(legacy))
        ]
        if legacy_hits:
            docs_legacy_refs.append({"path": rel_path.as_posix(), "legacy_ids": legacy_hits})

    owner_refs: list[dict[str, str]] = []
    for json_path in sorted((repo_root / OWNER_AGENT_JSON_ROOT).rglob("*.json")):
        owner_refs.extend(_collect_owner_agent_json(json_path))
    for rel_path in OWNER_AGENT_TEXT_FILES:
        path = repo_root / rel_path
        if path.exists():
            owner_refs.extend(_collect_owner_agent_text(path))

    invalid_owner_refs = [
        item for item in owner_refs if item["owner_agent"] not in canonical_ids
    ]

    if invalid_slug_rows:
        errors.append("catalog-slug-drift")
    if missing_files:
        errors.append("catalog-missing-files")
    if docs_missing_agents:
        errors.append("catalog-doc-drift")
    if docs_legacy_refs:
        errors.append("catalog-legacy-doc-refs")
    if invalid_owner_refs:
        errors.append("catalog-invalid-owner-agent")

    return {
        "ok": not errors,
        "catalog_path": catalog_path.relative_to(repo_root).as_posix(),
        "contract_version": catalog.get("contract_version"),
        "repo": catalog.get("repo"),
        "agent_count": len(agents),
        "canonical_agent_ids": canonical_ids,
        "legacy_runtime_aliases": legacy_aliases,
        "errors": errors,
        "invalid_slug_rows": invalid_slug_rows,
        "missing_files": sorted(set(missing_files)),
        "docs_missing_agents": docs_missing_agents,
        "docs_legacy_refs": docs_legacy_refs,
        "invalid_owner_refs": invalid_owner_refs,
        "parity_rows": parity_rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the Kill_LIFE canonical agent catalog.")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    args = parser.parse_args()

    result = validate_agent_catalog()
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        status = "OK" if result["ok"] else "FAIL"
        print(f"{status}: agent catalog")
        print(f"- agent_count: {result['agent_count']}")
        print(f"- invalid_slug_rows: {len(result['invalid_slug_rows'])}")
        print(f"- missing_files: {len(result['missing_files'])}")
        print(f"- docs_missing_agents: {len(result['docs_missing_agents'])}")
        print(f"- docs_legacy_refs: {len(result['docs_legacy_refs'])}")
        print(f"- invalid_owner_refs: {len(result['invalid_owner_refs'])}")
        if result["errors"]:
            print("- errors: " + ", ".join(result["errors"]))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
