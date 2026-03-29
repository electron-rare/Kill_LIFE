"""Shared helpers for the canonical YiACAD action registry."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
ACTION_REGISTRY_PATH = REPO_ROOT / "specs" / "contracts" / "yiacad_action_registry.json"
INPUT_ARGUMENTS: dict[str, dict[str, str]] = {
    "source_path": {
        "flag": "--source-path",
        "help": "Any project path to infer paired CAD files from",
    },
    "board": {
        "flag": "--board",
        "help": "Path to .kicad_pcb",
    },
    "schematic": {
        "flag": "--schematic",
        "help": "Path to .kicad_sch",
    },
    "freecad_document": {
        "flag": "--freecad-document",
        "help": "Path to .FCStd",
    },
    "kibot_config": {
        "flag": "--kibot-config",
        "help": "Optional path to a KiBot config for direct exports",
    },
}


@lru_cache(maxsize=1)
def load_yiacad_action_registry() -> dict[str, Any]:
    return json.loads(ACTION_REGISTRY_PATH.read_text(encoding="utf-8"))


def yiacad_actions() -> list[dict[str, Any]]:
    return list(load_yiacad_action_registry().get("actions", []))


def yiacad_actions_by_command() -> dict[str, dict[str, Any]]:
    return {entry["transport_command"]: entry for entry in yiacad_actions()}


def get_yiacad_action(command: str) -> dict[str, Any]:
    try:
        return yiacad_actions_by_command()[command]
    except KeyError as exc:  # pragma: no cover - defensive callsite guard
        raise KeyError(f"Unknown YiACAD action registry command: {command}") from exc


def yiacad_action_id(command: str) -> str:
    return str(get_yiacad_action(command)["action_id"])


def yiacad_action_inputs(command: str) -> list[str]:
    return [str(item) for item in get_yiacad_action(command).get("accepted_inputs", [])]


def yiacad_actions_for_surface(surface: str) -> list[dict[str, Any]]:
    return [
        entry
        for entry in yiacad_actions()
        if surface in entry.get("supported_surfaces", [])
    ]


def yiacad_command_for_alias(surface: str, alias: str) -> str | None:
    lowered = alias.strip().lower()
    for entry in yiacad_actions_for_surface(surface):
        aliases = [str(item).strip().lower() for item in entry.get("intent_aliases", [])]
        if lowered == str(entry["transport_command"]).strip().lower() or lowered in aliases:
            return str(entry["transport_command"])
    return None
