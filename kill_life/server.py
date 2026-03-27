"""Kill_LIFE FastAPI service — minimal skeleton for mascarade ecosystem integration."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from kill_life import __version__

REPO_ROOT = Path(__file__).resolve().parent.parent

app = FastAPI(
    title="Kill_LIFE API",
    version=__version__,
    description="Control plane API for Kill_LIFE embedded systems framework",
)

# ---------------------------------------------------------------------------
# Agent definitions (from agents/*.md)
# ---------------------------------------------------------------------------

BMAD_AGENTS: dict[str, dict[str, str]] = {
    "pm": {
        "name": "PM Agent",
        "file": "agents/pm_agent.md",
        "role": "Project management, intake, prioritization",
    },
    "architect": {
        "name": "Architect Agent",
        "file": "agents/architect_agent.md",
        "role": "System architecture, component design, tech decisions",
    },
    "firmware": {
        "name": "Firmware Agent",
        "file": "agents/firmware_agent.md",
        "role": "Embedded firmware development, HAL, drivers",
    },
    "hw_schematic": {
        "name": "HW Schematic Agent",
        "file": "agents/hw_schematic_agent.md",
        "role": "Hardware schematics, KiCad, PCB layout, BOM",
    },
    "qa": {
        "name": "QA Agent",
        "file": "agents/qa_agent.md",
        "role": "Testing, compliance, evidence collection",
    },
    "doc": {
        "name": "Doc Agent",
        "file": "agents/doc_agent.md",
        "role": "Documentation, runbooks, operator guides",
    },
}


def _list_specs() -> list[dict[str, str]]:
    """Scan specs/ directory for markdown files."""
    specs_dir = REPO_ROOT / "specs"
    if not specs_dir.is_dir():
        return []
    specs = []
    for p in sorted(specs_dir.glob("*.md")):
        specs.append({"name": p.stem, "file": f"specs/{p.name}"})
    return specs


def _load_mcp_json() -> dict[str, Any]:
    """Load mcp.json from repo root."""
    mcp_path = REPO_ROOT / "mcp.json"
    if not mcp_path.exists():
        return {}
    return json.loads(mcp_path.read_text())


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.get("/health")
async def health():
    return {"status": "ok", "service": "kill-life", "version": __version__}


@app.get("/agents")
async def list_agents():
    return {"agents": BMAD_AGENTS}


@app.get("/specs")
async def list_specs():
    return {"specs": _list_specs(), "count": len(_list_specs())}


class AgentRunRequest(BaseModel):
    input: str
    context: dict[str, Any] | None = None


@app.post("/agents/{name}/run")
async def run_agent(name: str, req: AgentRunRequest):
    if name not in BMAD_AGENTS:
        raise HTTPException(status_code=404, detail=f"Agent '{name}' not found. Available: {list(BMAD_AGENTS.keys())}")

    agent = BMAD_AGENTS[name]

    # Load agent definition
    agent_file = REPO_ROOT / agent["file"]
    definition = ""
    if agent_file.exists():
        definition = agent_file.read_text()

    # Stub response — real execution would route through mascarade LLM
    return {
        "agent": name,
        "role": agent["role"],
        "input": req.input,
        "status": "stub",
        "message": f"Agent '{name}' received input. Connect mascarade-core for LLM execution.",
        "definition_loaded": bool(definition),
        "mascarade_endpoint": "http://mascarade-core:8100/v1/chat/completions",
    }


@app.get("/mcp/servers")
async def list_mcp_servers():
    mcp = _load_mcp_json()
    servers = mcp.get("mcpServers", {})
    return {
        "servers": {k: {"type": v.get("type", "local"), "tools": v.get("tools", [])} for k, v in servers.items()},
        "count": len(servers),
    }


# ---------------------------------------------------------------------------
# Mascarade bridge info
# ---------------------------------------------------------------------------


@app.get("/bridge/mascarade")
async def mascarade_bridge_info():
    return {
        "mascarade_api": "http://192.168.0.119:8000",
        "mascarade_core": "http://192.168.0.119:8100",
        "p2p_bootstrap": "192.168.0.119:4002",
        "mcp_servers_count": len(_load_mcp_json().get("mcpServers", {})),
        "integration": {
            "specs_as_datasets": "mascarade finetune/ reads Kill_LIFE specs/",
            "mcp_tools": "mascarade mcp/client.py loads Kill_LIFE MCP servers",
            "agent_execution": "POST /agents/{name}/run routes through mascarade-core LLM",
        },
    }
