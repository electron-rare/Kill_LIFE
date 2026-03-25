#!/usr/bin/env python3
"""Node-RED HTTP connector for Mascarade — expose agents as Node-RED flow nodes.

Provides HTTP endpoints that Node-RED HTTP-request nodes can call:
  POST /nodered/send     — translate Node-RED msg → Mascarade send, return result as msg
  GET  /nodered/agents   — list available Mascarade agents
  GET  /nodered/health   — health check

Run with:
    python tools/industrial/nodered_connector.py
    # or via uvicorn:
    uvicorn tools.industrial.nodered_connector:app --host 0.0.0.0 --port 7880
"""

from __future__ import annotations

import asyncio
import json
import os
import time
import uuid
from typing import Any

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MASCARADE_URL = os.getenv("MASCARADE_URL", "http://localhost:8000")
LISTEN_HOST = os.getenv("NODERED_CONNECTOR_HOST", "0.0.0.0")
LISTEN_PORT = int(os.getenv("NODERED_CONNECTOR_PORT", "7880"))

# Default agents exposed to Node-RED
DEFAULT_AGENTS = [
    {
        "id": "factory-copilot",
        "name": "Factory Copilot",
        "description": "Operator assistant — queries machine data via OPC-UA/MQTT",
    },
    {
        "id": "maintenance-predictor",
        "name": "Maintenance Predictor",
        "description": "Time-series analysis, predictive maintenance alerts",
    },
    {
        "id": "log-analyst",
        "name": "Log Analyst",
        "description": "MES/ERP log reader, automatic shift report generation",
    },
    {
        "id": "quality-inspector",
        "name": "Quality Inspector",
        "description": "Vision-based quality control with YOLOv8/SAM2",
    },
]

# ---------------------------------------------------------------------------
# HTTP client for Mascarade API
# ---------------------------------------------------------------------------

try:
    import httpx

    HAS_HTTPX = True
except ImportError:
    HAS_HTTPX = False

# Try lightweight server options
try:
    from aiohttp import web

    HAS_AIOHTTP = True
except ImportError:
    HAS_AIOHTTP = False


async def _mascarade_send(agent: str, message: str, context: dict | None = None) -> dict:
    """Forward a message to a Mascarade agent and return its response."""
    payload = {
        "agent": agent,
        "message": message,
        "stream": False,
    }
    if context:
        payload["context"] = context

    if not HAS_HTTPX:
        # Stub mode — return a simulated response
        return {
            "agent": agent,
            "response": f"[stub] Agent '{agent}' received: {message[:120]}",
            "timestamp": time.time(),
            "stub": True,
        }

    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(f"{MASCARADE_URL}/v1/send", json=payload)
        resp.raise_for_status()
        return resp.json()


async def _mascarade_agents() -> list[dict]:
    """Fetch live agent list from Mascarade, fall back to defaults."""
    if not HAS_HTTPX:
        return DEFAULT_AGENTS

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{MASCARADE_URL}/v1/agents")
            resp.raise_for_status()
            return resp.json().get("agents", DEFAULT_AGENTS)
    except Exception:
        return DEFAULT_AGENTS


# ---------------------------------------------------------------------------
# Node-RED msg format helpers
# ---------------------------------------------------------------------------


def nodered_msg_to_mascarade(msg: dict) -> tuple[str, str, dict | None]:
    """Extract agent, message and optional context from a Node-RED msg object.

    Node-RED msg convention:
        msg.topic   → agent id  (e.g. "maintenance-predictor")
        msg.payload → user message (string or dict with "text" key)
        msg.context → optional dict forwarded as Mascarade context
    """
    agent = msg.get("topic", "factory-copilot")
    raw_payload = msg.get("payload", "")
    if isinstance(raw_payload, dict):
        message = raw_payload.get("text", json.dumps(raw_payload))
    else:
        message = str(raw_payload)
    context = msg.get("context")
    return agent, message, context


def mascarade_to_nodered_msg(result: dict, original_msg: dict | None = None) -> dict:
    """Wrap a Mascarade response into a Node-RED msg object.

    Output msg:
        msg.payload  → agent response text
        msg.topic    → agent id
        msg._msgid   → unique id
        msg.mascarade → full raw response
    """
    out = {
        "_msgid": str(uuid.uuid4()).replace("-", "")[:16],
        "topic": result.get("agent", "unknown"),
        "payload": result.get("response", ""),
        "mascarade": result,
    }
    # Preserve any extra fields from the original msg
    if original_msg:
        for key in ("_msgid", "parts", "rate", "reset"):
            if key in original_msg and key not in out:
                out[key] = original_msg[key]
    return out


# ---------------------------------------------------------------------------
# aiohttp web application
# ---------------------------------------------------------------------------


def _build_app() -> "web.Application":
    """Create the aiohttp web application with Node-RED routes."""
    app = web.Application()

    async def handle_health(request: web.Request) -> web.Response:
        return web.json_response(
            {
                "status": "ok",
                "service": "nodered-mascarade-connector",
                "mascarade_url": MASCARADE_URL,
                "timestamp": time.time(),
            }
        )

    async def handle_agents(request: web.Request) -> web.Response:
        agents = await _mascarade_agents()
        return web.json_response({"agents": agents})

    async def handle_send(request: web.Request) -> web.Response:
        """POST /nodered/send — main bridge endpoint.

        Accepts a Node-RED msg (JSON body) and returns a Node-RED msg.
        """
        try:
            body = await request.json()
        except Exception:
            return web.json_response(
                {"error": "Invalid JSON body"}, status=400
            )

        # Support both single msg and array of msgs (Node-RED batch)
        msgs = body if isinstance(body, list) else [body]
        results = []

        for msg in msgs:
            agent, message, context = nodered_msg_to_mascarade(msg)
            try:
                result = await _mascarade_send(agent, message, context)
                out_msg = mascarade_to_nodered_msg(result, original_msg=msg)
                results.append(out_msg)
            except Exception as exc:
                results.append(
                    {
                        "_msgid": str(uuid.uuid4()).replace("-", "")[:16],
                        "topic": agent,
                        "payload": f"Error: {exc}",
                        "error": str(exc),
                    }
                )

        # Return single msg or array depending on input
        if isinstance(body, list):
            return web.json_response(results)
        return web.json_response(results[0])

    app.router.add_get("/nodered/health", handle_health)
    app.router.add_get("/nodered/agents", handle_agents)
    app.router.add_post("/nodered/send", handle_send)

    return app


# ---------------------------------------------------------------------------
# Fallback: stdlib http server (no dependencies)
# ---------------------------------------------------------------------------


def _run_stdlib_server() -> None:
    """Minimal stdlib HTTP server for environments without aiohttp."""
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def _json(self, data: Any, status: int = 200) -> None:
            body = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:  # noqa: N802
            if self.path == "/nodered/health":
                self._json(
                    {
                        "status": "ok",
                        "service": "nodered-mascarade-connector",
                        "mascarade_url": MASCARADE_URL,
                        "timestamp": time.time(),
                    }
                )
            elif self.path == "/nodered/agents":
                self._json({"agents": DEFAULT_AGENTS})
            else:
                self._json({"error": "Not found"}, 404)

        def do_POST(self) -> None:  # noqa: N802
            if self.path != "/nodered/send":
                self._json({"error": "Not found"}, 404)
                return

            try:
                length = int(self.headers.get("Content-Length", 0))
            except (ValueError, TypeError):
                length = 0
            raw = self.rfile.read(length)
            try:
                body = json.loads(raw)
            except Exception:
                self._json({"error": "Invalid JSON"}, 400)
                return

            msgs = body if isinstance(body, list) else [body]
            results = []
            for msg in msgs:
                agent, message, context = nodered_msg_to_mascarade(msg)
                result = asyncio.run(_mascarade_send(agent, message, context))
                out_msg = mascarade_to_nodered_msg(result, original_msg=msg)
                results.append(out_msg)

            if isinstance(body, list):
                self._json(results)
            else:
                self._json(results[0])

    server = HTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    print(f"[nodered-connector] stdlib server on http://{LISTEN_HOST}:{LISTEN_PORT}")
    server.serve_forever()


# ---------------------------------------------------------------------------
# ASGI app (for uvicorn)
# ---------------------------------------------------------------------------

app = _build_app() if HAS_AIOHTTP else None

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    print(f"[nodered-connector] Mascarade URL: {MASCARADE_URL}")
    print(f"[nodered-connector] Listening on {LISTEN_HOST}:{LISTEN_PORT}")
    print(f"[nodered-connector] httpx={'yes' if HAS_HTTPX else 'STUB'}, aiohttp={'yes' if HAS_AIOHTTP else 'stdlib'}")

    if HAS_AIOHTTP:
        web.run_app(_build_app(), host=LISTEN_HOST, port=LISTEN_PORT)
    else:
        _run_stdlib_server()


if __name__ == "__main__":
    main()
