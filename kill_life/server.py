"""Kill_LIFE FastAPI service — minimal skeleton for mascarade ecosystem integration."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from kill_life import __version__
from kill_life.agent_catalog import canonical_agents_by_id, canonical_agents_for_api, legacy_runtime_mapping

MASCARADE_CORE_URL = os.environ.get("MASCARADE_CORE_URL", "http://localhost:8100")
MASCARADE_API_URL = os.environ.get("MASCARADE_API_URL", "http://localhost:8000")
P2P_BOOTSTRAP = os.environ.get("P2P_BOOTSTRAP", "localhost:4002")

REPO_ROOT = Path(__file__).resolve().parent.parent

app = FastAPI(
    title="Kill_LIFE API",
    version=__version__,
    description="Control plane API for Kill_LIFE embedded systems framework",
)

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
    agents = canonical_agents_for_api()
    return {
        "agents": agents,
        "count": len(agents),
    }


@app.get("/specs")
async def list_specs():
    return {"specs": _list_specs(), "count": len(_list_specs())}


class AgentRunRequest(BaseModel):
    input: str
    context: dict[str, Any] | None = None


@app.post("/agents/{name}/run")
async def run_agent(name: str, req: AgentRunRequest):
    legacy_target = legacy_runtime_mapping(name)
    if legacy_target is not None:
        raise HTTPException(
            status_code=410,
            detail={
                "message": f"Legacy agent '{name}' has been removed from the runtime API.",
                "legacy_agent": name,
                "canonical_agent": legacy_target,
            },
        )

    agents = canonical_agents_by_id()
    if name not in agents:
        raise HTTPException(
            status_code=404,
            detail=f"Agent '{name}' not found. Available: {list(agents.keys())}",
        )

    agent = agents[name]

    # Load agent definition as system prompt
    agent_file = REPO_ROOT / agent["agent_doc"]
    system_prompt = ""
    if agent_file.exists():
        system_prompt = agent_file.read_text(encoding="utf-8")
    else:
        system_prompt = f"You are {agent['display_name']}. Your role: {agent['purpose']}."

    # Build messages
    messages = [{"role": "user", "content": req.input}]
    if req.context:
        context_str = json.dumps(req.context, indent=2)
        messages[0]["content"] = f"Context:\n```json\n{context_str}\n```\n\n{req.input}"

    # POST to mascarade-core /v1/send
    payload = {
        "messages": messages,
        "system": system_prompt,
        "routing_policy": "auto",
        "max_tokens": 4096,
        "temperature": 0.7,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{MASCARADE_CORE_URL}/v1/send", json=payload)
            resp.raise_for_status()
            result = resp.json()
    except httpx.ConnectError:
        raise HTTPException(
            status_code=502,
            detail=f"mascarade-core unreachable at {MASCARADE_CORE_URL}. Set MASCARADE_CORE_URL env var.",
        )
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"mascarade-core returned {exc.response.status_code}: {exc.response.text[:500]}",
        )
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="mascarade-core request timed out (60s)")

    return {
        "agent": name,
        "role": agent["purpose"],
        "status": "ok",
        "response": result,
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
        "mascarade_api": MASCARADE_API_URL,
        "mascarade_core": MASCARADE_CORE_URL,
        "p2p_bootstrap": P2P_BOOTSTRAP,
        "mcp_servers_count": len(_load_mcp_json().get("mcpServers", {})),
        "integration": {
            "specs_as_datasets": "mascarade finetune/ reads Kill_LIFE specs/",
            "mcp_tools": "mascarade mcp/client.py loads Kill_LIFE MCP servers",
            "agent_execution": "POST /agents/{name}/run routes canonical 2026 agent IDs through mascarade-core LLM",
        },
    }
