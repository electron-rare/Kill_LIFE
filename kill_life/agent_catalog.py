"""Shared helpers for the canonical Kill_LIFE 2026 agent catalog."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
AGENT_CATALOG_PATH = REPO_ROOT / "specs" / "contracts" / "kill_life_agent_catalog.json"


@lru_cache(maxsize=1)
def load_agent_catalog() -> dict[str, Any]:
    return json.loads(AGENT_CATALOG_PATH.read_text(encoding="utf-8"))


def canonical_agents() -> list[dict[str, Any]]:
    return list(load_agent_catalog().get("agents", []))


def canonical_agent_ids() -> list[str]:
    return [agent["id"] for agent in canonical_agents()]


def canonical_agents_by_id() -> dict[str, dict[str, Any]]:
    return {agent["id"]: agent for agent in canonical_agents()}


def canonical_agents_for_api() -> dict[str, dict[str, Any]]:
    agents: dict[str, dict[str, Any]] = {}
    for agent in canonical_agents():
        if not agent.get("public_api_enabled", False):
            continue
        agents[agent["id"]] = {
            "display_name": agent["display_name"],
            "purpose": agent["purpose"],
            "owner_repo": agent["owner_repo"],
            "slug": agent["slug"],
            "agent_doc": agent["agent_doc"],
            "github_agent_doc": agent["github_agent_doc"],
            "start_prompt": agent["start_prompt"],
            "plan_wizard_prompt": agent["plan_wizard_prompt"],
            "write_set_roots": agent["write_set_roots"],
            "rituals": agent["rituals"],
            "gates": agent["gates"],
            "handoff_contracts": agent["handoff_contracts"],
            "evidence_paths": agent["evidence_paths"],
            "subagents": agent["subagents"],
        }
    return agents


def legacy_runtime_aliases() -> dict[str, str]:
    aliases = load_agent_catalog().get("legacy_runtime_aliases", {})
    return {str(key): str(value) for key, value in aliases.items()}


def legacy_runtime_mapping(agent_name: str) -> str | None:
    return legacy_runtime_aliases().get(agent_name)

