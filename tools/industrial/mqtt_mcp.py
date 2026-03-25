#!/usr/bin/env python3
"""Local MCP server for MQTT industrial messaging — subscribe, publish, topic list, history."""

from __future__ import annotations

import asyncio
import json
import os
import sys
import threading
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

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost:1883")
MQTT_USERNAME = os.getenv("MQTT_USERNAME", "")
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD", "")

_MAX_BUFFER = 500

# In-memory message buffers (topic -> list of messages)
_topic_buffers: dict[str, list[dict]] = defaultdict(list)
_known_topics: set[str] = set()

# ---------------------------------------------------------------------------
# MQTT client (paho-mqtt with fallback to stub)
# ---------------------------------------------------------------------------

try:
    import paho.mqtt.client as mqtt_client

    HAS_PAHO = True

    def _parse_broker(broker: str) -> tuple[str, int]:
        """Parse host:port from broker string."""
        if ":" in broker:
            host, port_str = broker.rsplit(":", 1)
            try:
                return host, int(port_str)
            except ValueError:
                return broker, 1883
        return broker, 1883

    def _make_client(broker: str | None = None) -> mqtt_client.Client:
        """Create a configured MQTT client."""
        b = broker or MQTT_BROKER
        client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION2)
        if MQTT_USERNAME:
            client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
        return client

    async def _mqtt_subscribe(broker: str, topic: str, duration_s: float, last_n: int, qos: int) -> dict:
        """Subscribe to a topic, collect messages for duration_s, return last N."""
        b = broker or MQTT_BROKER
        host, port = _parse_broker(b)
        messages: list[dict] = []
        connected = threading.Event()

        def on_connect(client: Any, userdata: Any, flags: Any, rc: Any, properties: Any = None) -> None:
            client.subscribe(topic, qos=qos)
            connected.set()

        def on_message(client: Any, userdata: Any, msg: Any) -> None:
            try:
                payload = msg.payload.decode("utf-8", errors="replace")
            except Exception:
                payload = msg.payload.hex()
            entry = {
                "topic": msg.topic,
                "payload": payload,
                "qos": msg.qos,
                "retain": msg.retain,
                "timestamp": time.time(),
            }
            messages.append(entry)
            _topic_buffers[msg.topic].append(entry)
            if len(_topic_buffers[msg.topic]) > _MAX_BUFFER:
                _topic_buffers[msg.topic] = _topic_buffers[msg.topic][-_MAX_BUFFER:]
            _known_topics.add(msg.topic)

        client = _make_client(b)
        client.on_connect = on_connect
        client.on_message = on_message
        client.connect(host, port, keepalive=60)
        client.loop_start()
        connected.wait(timeout=10)
        await asyncio.sleep(min(duration_s, 30))
        client.loop_stop()
        client.disconnect()
        return {
            "broker": b,
            "topic": topic,
            "messages": messages[-last_n:],
            "total_received": len(messages),
        }

    async def _mqtt_publish(broker: str, topic: str, payload: str, qos: int, retain: bool) -> dict:
        """Publish a message to an MQTT topic."""
        b = broker or MQTT_BROKER
        host, port = _parse_broker(b)
        client = _make_client(b)
        client.connect(host, port, keepalive=60)
        client.loop_start()
        info = client.publish(topic, payload.encode("utf-8"), qos=qos, retain=retain)
        info.wait_for_publish(timeout=10)
        client.loop_stop()
        client.disconnect()
        return {
            "broker": b,
            "topic": topic,
            "payload": payload,
            "qos": qos,
            "retain": retain,
            "status": "published",
            "mid": info.mid,
        }

    async def _mqtt_topics(broker: str, duration_s: float) -> dict:
        """List active topics by subscribing to # for a short duration."""
        b = broker or MQTT_BROKER
        host, port = _parse_broker(b)
        topics: dict[str, int] = {}
        connected = threading.Event()

        def on_connect(client: Any, userdata: Any, flags: Any, rc: Any, properties: Any = None) -> None:
            client.subscribe("#", qos=0)
            connected.set()

        def on_message(client: Any, userdata: Any, msg: Any) -> None:
            topics[msg.topic] = topics.get(msg.topic, 0) + 1
            _known_topics.add(msg.topic)

        client = _make_client(b)
        client.on_connect = on_connect
        client.on_message = on_message
        client.connect(host, port, keepalive=60)
        client.loop_start()
        connected.wait(timeout=10)
        await asyncio.sleep(min(duration_s, 15))
        client.loop_stop()
        client.disconnect()
        topic_list = [{"topic": t, "message_count": c} for t, c in sorted(topics.items())]
        return {"broker": b, "topics": topic_list, "total_topics": len(topic_list)}

    async def _mqtt_history(broker: str, topic: str, last_n: int) -> dict:
        """Return message history for a topic from the in-memory buffer. Also checks retained messages."""
        b = broker or MQTT_BROKER
        # Check in-memory buffer first
        buffered = _topic_buffers.get(topic, [])
        if not buffered:
            # Try to get retained message
            host, port = _parse_broker(b)
            retained: list[dict] = []
            got_msg = threading.Event()

            def on_connect(client: Any, userdata: Any, flags: Any, rc: Any, properties: Any = None) -> None:
                client.subscribe(topic, qos=1)

            def on_message(client: Any, userdata: Any, msg: Any) -> None:
                try:
                    payload = msg.payload.decode("utf-8", errors="replace")
                except Exception:
                    payload = msg.payload.hex()
                retained.append({
                    "topic": msg.topic,
                    "payload": payload,
                    "qos": msg.qos,
                    "retain": msg.retain,
                    "timestamp": time.time(),
                })
                got_msg.set()

            client = _make_client(b)
            client.on_connect = on_connect
            client.on_message = on_message
            client.connect(host, port, keepalive=60)
            client.loop_start()
            got_msg.wait(timeout=5)
            await asyncio.sleep(2)
            client.loop_stop()
            client.disconnect()
            return {
                "broker": b,
                "topic": topic,
                "messages": retained[-last_n:],
                "source": "retained",
                "count": len(retained),
            }

        return {
            "broker": b,
            "topic": topic,
            "messages": buffered[-last_n:],
            "source": "buffer",
            "count": len(buffered),
        }

except ImportError:
    HAS_PAHO = False

    async def _mqtt_subscribe(broker: str, topic: str, duration_s: float, last_n: int, qos: int) -> dict:
        return {"stub": True, "message": f"paho-mqtt not installed. Would subscribe to {topic} on {broker or MQTT_BROKER}"}

    async def _mqtt_publish(broker: str, topic: str, payload: str, qos: int, retain: bool) -> dict:
        return {"stub": True, "message": f"paho-mqtt not installed. Would publish to {topic} on {broker or MQTT_BROKER}"}

    async def _mqtt_topics(broker: str, duration_s: float) -> dict:
        return {"stub": True, "message": f"paho-mqtt not installed. Would list topics on {broker or MQTT_BROKER}"}

    async def _mqtt_history(broker: str, topic: str, last_n: int) -> dict:
        return {"stub": True, "message": f"paho-mqtt not installed. Would get history for {topic} on {broker or MQTT_BROKER}"}


# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "mqtt_subscribe",
        "description": "Subscribe to an MQTT topic and return the last N messages received during a short listening window.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "broker": {"type": "string", "description": "MQTT broker address (host:port). Defaults to MQTT_BROKER env var."},
                "topic": {"type": "string", "description": "MQTT topic to subscribe to (e.g., 'factory/line1/temperature', 'sensors/#')"},
                "duration_s": {"type": "number", "description": "Listening duration in seconds (default: 5, max: 30)"},
                "last_n": {"type": "integer", "description": "Return last N messages (default: 20)"},
                "qos": {"type": "integer", "description": "MQTT QoS level 0, 1, or 2 (default: 0)"},
            },
            "required": ["topic"],
        },
    },
    {
        "name": "mqtt_publish",
        "description": "Publish a message to an MQTT topic. Use with caution on production brokers.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "broker": {"type": "string", "description": "MQTT broker address (host:port). Defaults to MQTT_BROKER env var."},
                "topic": {"type": "string", "description": "MQTT topic to publish to (e.g., 'factory/line1/setpoint')"},
                "payload": {"type": "string", "description": "Message payload (string or JSON string)"},
                "qos": {"type": "integer", "description": "MQTT QoS level 0, 1, or 2 (default: 0)"},
                "retain": {"type": "boolean", "description": "Retain flag (default: false)"},
            },
            "required": ["topic", "payload"],
        },
    },
    {
        "name": "mqtt_topics",
        "description": "List active topics on the MQTT broker by subscribing to wildcard '#' for a short duration. Shows topics and message counts.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "broker": {"type": "string", "description": "MQTT broker address (host:port). Defaults to MQTT_BROKER env var."},
                "duration_s": {"type": "number", "description": "Listening duration in seconds (default: 5, max: 15)"},
            },
            "required": [],
        },
    },
    {
        "name": "mqtt_history",
        "description": "Get message history for a topic. Returns messages from the in-memory buffer (from previous subscriptions) or retained messages from the broker.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "broker": {"type": "string", "description": "MQTT broker address (host:port). Defaults to MQTT_BROKER env var."},
                "topic": {"type": "string", "description": "MQTT topic to get history for"},
                "last_n": {"type": "integer", "description": "Return last N messages (default: 50)"},
            },
            "required": ["topic"],
        },
    },
]


# ---------------------------------------------------------------------------
# Tool handlers
# ---------------------------------------------------------------------------

async def handle_mqtt_subscribe(args: dict) -> str:
    broker = args.get("broker", "")
    topic = args["topic"]
    duration_s = min(args.get("duration_s", 5), 30)
    last_n = args.get("last_n", 20)
    qos = args.get("qos", 0)
    result = await _mqtt_subscribe(broker, topic, duration_s, last_n, qos)
    return json.dumps({"paho": HAS_PAHO, **result}, default=str)


async def handle_mqtt_publish(args: dict) -> str:
    broker = args.get("broker", "")
    topic = args["topic"]
    payload = args["payload"]
    qos = args.get("qos", 0)
    retain = args.get("retain", False)
    result = await _mqtt_publish(broker, topic, payload, qos, retain)
    return json.dumps({"paho": HAS_PAHO, **result}, default=str)


async def handle_mqtt_topics(args: dict) -> str:
    broker = args.get("broker", "")
    duration_s = min(args.get("duration_s", 5), 15)
    result = await _mqtt_topics(broker, duration_s)
    return json.dumps({"paho": HAS_PAHO, **result}, default=str)


async def handle_mqtt_history(args: dict) -> str:
    broker = args.get("broker", "")
    topic = args["topic"]
    last_n = args.get("last_n", 50)
    result = await _mqtt_history(broker, topic, last_n)
    return json.dumps({"paho": HAS_PAHO, **result}, default=str)


HANDLERS = {
    "mqtt_subscribe": handle_mqtt_subscribe,
    "mqtt_publish": handle_mqtt_publish,
    "mqtt_topics": handle_mqtt_topics,
    "mqtt_history": handle_mqtt_history,
}

# ---------------------------------------------------------------------------
# MCP stdio protocol loop
# ---------------------------------------------------------------------------

SERVER_INFO = {"name": "mqtt", "version": "1.0.0"}


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
