#!/usr/bin/env python3
"""Local MCP server for OPC-UA industrial automation — browse, read, write, subscribe, discover."""

from __future__ import annotations

import asyncio
import json
import os
import sys
import time
from collections import defaultdict
from typing import Any

from mcp_stdio import (  # type: ignore
    PROTOCOL_VERSION,
    error_tool_result,
    make_error,
    make_response,
    ok_tool_result,
    read_message,
    write_message,
)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

OPCUA_ENDPOINT = os.getenv("OPCUA_ENDPOINT", "opc.tcp://localhost:4840")

# ---------------------------------------------------------------------------
# OPC-UA client (asyncua with fallback to stub)
# ---------------------------------------------------------------------------

_subscription_buffers: dict[str, list[dict]] = defaultdict(list)
_MAX_BUFFER = 200

try:
    from asyncua import Client as OPCUAClient, ua

    HAS_ASYNCUA = True

    async def _opcua_browse(endpoint: str, node_id: str | None, max_depth: int) -> list[dict]:
        """Browse the OPC-UA node tree starting from a given node."""
        async with OPCUAClient(url=endpoint) as client:
            if node_id:
                root = client.get_node(node_id)
            else:
                root = client.nodes.objects
            return await _browse_recursive(root, max_depth, 0)

    async def _browse_recursive(node: Any, max_depth: int, depth: int) -> list[dict]:
        result = []
        browse_name = await node.read_browse_name()
        node_class = await node.read_node_class()
        entry: dict[str, Any] = {
            "node_id": node.nodeid.to_string(),
            "browse_name": browse_name.to_string(),
            "node_class": node_class.name if hasattr(node_class, "name") else str(node_class),
        }
        if depth < max_depth:
            children = await node.get_children()
            if children:
                entry["children"] = []
                for child in children[:50]:  # limit breadth
                    entry["children"].extend(await _browse_recursive(child, max_depth, depth + 1))
        result.append(entry)
        return result

    async def _opcua_read(endpoint: str, node_id: str) -> dict:
        """Read a single OPC-UA node value."""
        async with OPCUAClient(url=endpoint) as client:
            node = client.get_node(node_id)
            value = await node.read_value()
            data_type = await node.read_data_type_as_variant_type()
            return {
                "node_id": node_id,
                "value": _serialize_value(value),
                "data_type": str(data_type),
                "timestamp": time.time(),
            }

    async def _opcua_write(endpoint: str, node_id: str, value: Any, data_type: str | None) -> dict:
        """Write a value to an OPC-UA node."""
        async with OPCUAClient(url=endpoint) as client:
            node = client.get_node(node_id)
            if data_type:
                vt = getattr(ua.VariantType, data_type, None)
                if vt:
                    await node.write_value(ua.DataValue(ua.Variant(value, vt)))
                else:
                    await node.write_value(value)
            else:
                await node.write_value(value)
            return {"node_id": node_id, "status": "written", "value": _serialize_value(value)}

    async def _opcua_subscribe(endpoint: str, node_id: str, duration_s: float, last_n: int) -> dict:
        """Subscribe to a node, collect values for duration_s, return last N."""
        values: list[dict] = []

        class Handler:
            def datachange_notification(self, node: Any, val: Any, data: Any) -> None:
                values.append({"value": _serialize_value(val), "timestamp": time.time()})
                if len(values) > _MAX_BUFFER:
                    values.pop(0)

        async with OPCUAClient(url=endpoint) as client:
            handler = Handler()
            sub = await client.create_subscription(100, handler)
            target = client.get_node(node_id)
            await sub.subscribe_data_change(target)
            await asyncio.sleep(min(duration_s, 30))
            await sub.delete()
        return {"node_id": node_id, "values": values[-last_n:], "count": len(values)}

    async def _opcua_discover(endpoint: str) -> list[dict]:
        """Discover OPC-UA servers on the network."""
        from asyncua import discovery
        servers = await discovery.find_servers(endpoint)
        return [
            {
                "application_name": str(s.ApplicationName.Text),
                "application_uri": s.ApplicationUri,
                "product_uri": s.ProductUri,
                "discovery_urls": list(s.DiscoveryUrls or []),
            }
            for s in servers
        ]

except ImportError:
    HAS_ASYNCUA = False

    async def _opcua_browse(endpoint: str, node_id: str | None, max_depth: int) -> list[dict]:
        return [{"stub": True, "message": f"asyncua not installed. Would browse {endpoint} from {node_id or 'Objects'} depth={max_depth}"}]

    async def _opcua_read(endpoint: str, node_id: str) -> dict:
        return {"stub": True, "message": f"asyncua not installed. Would read {node_id} from {endpoint}"}

    async def _opcua_write(endpoint: str, node_id: str, value: Any, data_type: str | None) -> dict:
        return {"stub": True, "message": f"asyncua not installed. Would write {value} to {node_id} at {endpoint}"}

    async def _opcua_subscribe(endpoint: str, node_id: str, duration_s: float, last_n: int) -> dict:
        return {"stub": True, "message": f"asyncua not installed. Would subscribe to {node_id} at {endpoint} for {duration_s}s"}

    async def _opcua_discover(endpoint: str) -> list[dict]:
        return [{"stub": True, "message": f"asyncua not installed. Would discover servers via {endpoint}"}]


def _serialize_value(val: Any) -> Any:
    """Make OPC-UA values JSON-serializable."""
    if isinstance(val, (int, float, str, bool, type(None))):
        return val
    if isinstance(val, (list, tuple)):
        return [_serialize_value(v) for v in val]
    if isinstance(val, bytes):
        return val.hex()
    return str(val)


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "opcua_browse",
        "description": "Browse the OPC-UA server node tree. Returns hierarchical list of nodes with their IDs, names, and classes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "endpoint": {"type": "string", "description": "OPC-UA endpoint URL (e.g., opc.tcp://192.168.1.10:4840). Defaults to OPCUA_ENDPOINT env var."},
                "node_id": {"type": "string", "description": "Starting NodeId (e.g., 'ns=2;s=MyDevice'). Defaults to Objects root node."},
                "max_depth": {"type": "integer", "description": "Max browsing depth (default: 2, max: 5)"},
            },
            "required": [],
        },
    },
    {
        "name": "opcua_read",
        "description": "Read the current value of a specific OPC-UA node by its NodeId. Returns value, data type, and timestamp.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "endpoint": {"type": "string", "description": "OPC-UA endpoint URL. Defaults to OPCUA_ENDPOINT env var."},
                "node_id": {"type": "string", "description": "NodeId to read (e.g., 'ns=2;s=Temperature', 'ns=2;i=1001')"},
            },
            "required": ["node_id"],
        },
    },
    {
        "name": "opcua_write",
        "description": "Write a value to an OPC-UA node. Use with caution on production systems.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "endpoint": {"type": "string", "description": "OPC-UA endpoint URL. Defaults to OPCUA_ENDPOINT env var."},
                "node_id": {"type": "string", "description": "NodeId to write to (e.g., 'ns=2;s=Setpoint')"},
                "value": {"description": "Value to write (type is auto-detected or specified via data_type)"},
                "data_type": {"type": "string", "description": "OPC-UA data type name (e.g., 'Float', 'Int32', 'Boolean', 'String'). Optional."},
            },
            "required": ["node_id", "value"],
        },
    },
    {
        "name": "opcua_subscribe",
        "description": "Subscribe to an OPC-UA node for a short duration and return the collected value changes. Useful for monitoring live data.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "endpoint": {"type": "string", "description": "OPC-UA endpoint URL. Defaults to OPCUA_ENDPOINT env var."},
                "node_id": {"type": "string", "description": "NodeId to subscribe to (e.g., 'ns=2;s=Temperature')"},
                "duration_s": {"type": "number", "description": "Subscription duration in seconds (default: 5, max: 30)"},
                "last_n": {"type": "integer", "description": "Return last N collected values (default: 20)"},
            },
            "required": ["node_id"],
        },
    },
    {
        "name": "opcua_discover",
        "description": "Discover OPC-UA servers on the network. Queries the discovery endpoint for registered servers.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "endpoint": {"type": "string", "description": "Discovery endpoint URL (e.g., opc.tcp://192.168.1.0:4840). Defaults to OPCUA_ENDPOINT env var."},
            },
            "required": [],
        },
    },
]


async def handle_opcua_browse(args: dict) -> str:
    endpoint = args.get("endpoint", OPCUA_ENDPOINT)
    node_id = args.get("node_id")
    max_depth = min(args.get("max_depth", 2), 5)
    result = await _opcua_browse(endpoint, node_id, max_depth)
    return json.dumps({"endpoint": endpoint, "asyncua": HAS_ASYNCUA, "nodes": result}, default=str)


async def handle_opcua_read(args: dict) -> str:
    endpoint = args.get("endpoint", OPCUA_ENDPOINT)
    node_id = args["node_id"]
    result = await _opcua_read(endpoint, node_id)
    return json.dumps({"endpoint": endpoint, "asyncua": HAS_ASYNCUA, **result}, default=str)


async def handle_opcua_write(args: dict) -> str:
    endpoint = args.get("endpoint", OPCUA_ENDPOINT)
    node_id = args["node_id"]
    value = args["value"]
    data_type = args.get("data_type")
    result = await _opcua_write(endpoint, node_id, value, data_type)
    return json.dumps({"endpoint": endpoint, "asyncua": HAS_ASYNCUA, **result}, default=str)


async def handle_opcua_subscribe(args: dict) -> str:
    endpoint = args.get("endpoint", OPCUA_ENDPOINT)
    node_id = args["node_id"]
    duration_s = min(args.get("duration_s", 5), 30)
    last_n = args.get("last_n", 20)
    result = await _opcua_subscribe(endpoint, node_id, duration_s, last_n)
    return json.dumps({"endpoint": endpoint, "asyncua": HAS_ASYNCUA, **result}, default=str)


async def handle_opcua_discover(args: dict) -> str:
    endpoint = args.get("endpoint", OPCUA_ENDPOINT)
    result = await _opcua_discover(endpoint)
    return json.dumps({"endpoint": endpoint, "asyncua": HAS_ASYNCUA, "servers": result}, default=str)


HANDLERS = {
    "opcua_browse": handle_opcua_browse,
    "opcua_read": handle_opcua_read,
    "opcua_write": handle_opcua_write,
    "opcua_subscribe": handle_opcua_subscribe,
    "opcua_discover": handle_opcua_discover,
}

# ---------------------------------------------------------------------------
# MCP stdio protocol loop
# ---------------------------------------------------------------------------

SERVER_INFO = {"name": "opcua", "version": "1.0.0"}


async def handle_message(msg: dict) -> dict | None:
    method = msg.get("method", "")
    mid = msg.get("id")

    if method == "initialize":
        return make_response(mid, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": SERVER_INFO,
        })

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return make_response(mid, {"tools": TOOLS})

    if method == "tools/call":
        params = msg.get("params", {})
        name = params.get("name", "")
        args = params.get("arguments", {})
        handler = HANDLERS.get(name)
        if not handler:
            return make_response(mid, error_tool_result(f"Unknown tool: {name}"))
        try:
            result = await handler(args)
            return make_response(mid, ok_tool_result(result))
        except Exception as exc:
            return make_response(mid, error_tool_result(f"{type(exc).__name__}: {exc}"))

    return make_error(mid, -32601, f"Method not found: {method}")


async def main() -> None:
    while True:
        msg = await read_message()
        if msg is None:
            break
        resp = await handle_message(msg)
        if resp is not None:
            await write_message(resp)


if __name__ == "__main__":
    asyncio.run(main())
