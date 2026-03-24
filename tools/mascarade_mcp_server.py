#!/usr/bin/env python3
"""MCP stdio server for Mascarade LLM Router.

Exposes tools: health, list_models, list_providers, chat.
Works with Claude Code, VSCode, Cline, Copilot — any MCP-compatible client.
"""

import json
import sys
import urllib.request

MASCARADE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8100"


def _req(path: str, method: str = "GET", data: dict | None = None) -> dict:
    url = f"{MASCARADE_URL}{path}"
    body = json.dumps(data).encode() if data else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read())


TOOLS = [
    {
        "name": "mascarade_health",
        "description": "Check Mascarade router health — returns providers, P2P peers, status",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "mascarade_list_models",
        "description": "List all available LLM models across all providers (Mistral, Claude, OpenAI, Ollama, P2P)",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "mascarade_list_providers",
        "description": "List configured LLM providers and their status",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "mascarade_chat",
        "description": "Send a chat completion request through the Mascarade router. Routes to the best available provider.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "The user message to send",
                },
                "model": {
                    "type": "string",
                    "description": "Model to use (e.g. mistral:codestral-latest, claude:claude-sonnet-4-20250514, openai:gpt-4o). Leave empty for auto-routing.",
                    "default": "",
                },
                "system": {
                    "type": "string",
                    "description": "Optional system prompt",
                    "default": "",
                },
            },
            "required": ["message"],
        },
    },
]


def handle_request(req: dict) -> dict:
    method = req.get("method", "")
    req_id = req.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {
                    "name": "mascarade",
                    "version": "1.0.0",
                },
            },
        }

    if method == "notifications/initialized":
        return None  # no response needed

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS},
        }

    if method == "tools/call":
        tool_name = req.get("params", {}).get("name", "")
        args = req.get("params", {}).get("arguments", {})
        try:
            result = _call_tool(tool_name, args)
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": json.dumps(result, indent=2)}]
                },
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "content": [{"type": "text", "text": f"Error: {e}"}],
                    "isError": True,
                },
            }

    # Unknown method
    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Unknown method: {method}"},
    }


def _call_tool(name: str, args: dict) -> dict:
    if name == "mascarade_health":
        return _req("/health")

    if name == "mascarade_list_models":
        data = _req("/ollama/api/tags")
        models = data.get("models", [])
        return {
            "count": len(models),
            "models": [
                {"name": m["name"], "family": m.get("details", {}).get("family", "?")}
                for m in models
            ],
        }

    if name == "mascarade_list_providers":
        health = _req("/health")
        return {
            "providers": health.get("providers", []),
            "p2p_peers": health.get("p2p_peers", 0),
        }

    if name == "mascarade_chat":
        message = args["message"]
        model = args.get("model", "")
        system = args.get("system", "")

        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": message})

        body = {"messages": messages}
        if model:
            body["model"] = model

        data = _req("/ollama/api/chat", method="POST", data=body)
        return {
            "content": data.get("message", {}).get("content", ""),
            "model": data.get("model", ""),
            "provider": data.get("details", {}).get("family", ""),
        }

    raise ValueError(f"Unknown tool: {name}")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        resp = handle_request(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
