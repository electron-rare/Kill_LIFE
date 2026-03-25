#!/usr/bin/env python3
"""MQTT local test — publish test messages and verify the MCP tools can read them.

Prerequisites:
    brew install mosquitto && brew services start mosquitto   # macOS
    # OR: docker run -d -p 1883:1883 eclipse-mosquitto:2
    pip install paho-mqtt

Usage:
    python tools/industrial/test_mqtt_local.py [--broker localhost:1883]

The script:
1. Connects to a local Mosquitto broker (localhost:1883)
2. Publishes test messages on factory/line1/{temperature,pressure,motor_speed}
3. Subscribes to wildcard factory/# and collects messages
4. Verifies retained messages work
5. Reports results and exits
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import threading
import time
from typing import Any

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("ERROR: paho-mqtt is required.  pip install paho-mqtt")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

TOPICS = [
    "factory/line1/temperature",
    "factory/line1/pressure",
    "factory/line1/motor_speed",
]

passed = 0
failed = 0


def report(name: str, ok: bool, detail: str = "") -> None:
    global passed, failed
    status = "PASS" if ok else "FAIL"
    if ok:
        passed += 1
    else:
        failed += 1
    print(f"  [{status}] {name}" + (f"  -- {detail}" if detail else ""))


def parse_broker(broker: str) -> tuple[str, int]:
    if ":" in broker:
        host, port_s = broker.rsplit(":", 1)
        try:
            return host, int(port_s)
        except ValueError:
            return broker, 1883
    return broker, 1883


# ---------------------------------------------------------------------------
# Test: basic connect
# ---------------------------------------------------------------------------

def test_connect(host: str, port: int) -> bool:
    print("\n--- test_connect ---")
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        client.connect(host, port, keepalive=10)
        client.disconnect()
        report("Connect to broker", True, f"{host}:{port}")
        return True
    except Exception as exc:
        report("Connect to broker", False, str(exc))
        print(f"\n  HINT: Is Mosquitto running?")
        print(f"    brew install mosquitto && brew services start mosquitto")
        print(f"    # OR: docker run -d -p 1883:1883 eclipse-mosquitto:2\n")
        return False


# ---------------------------------------------------------------------------
# Test: publish + subscribe round-trip
# ---------------------------------------------------------------------------

def test_pub_sub(host: str, port: int) -> None:
    print("\n--- test_pub_sub ---")
    received: list[dict] = []
    connected = threading.Event()
    done = threading.Event()

    def on_connect(client: Any, userdata: Any, flags: Any, rc: Any, properties: Any = None) -> None:
        client.subscribe("factory/#", qos=1)
        connected.set()

    def on_message(client: Any, userdata: Any, msg: Any) -> None:
        try:
            payload = json.loads(msg.payload.decode())
        except Exception:
            payload = msg.payload.decode()
        received.append({"topic": msg.topic, "payload": payload, "qos": msg.qos})

    # Subscriber
    sub_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    sub_client.on_connect = on_connect
    sub_client.on_message = on_message
    sub_client.connect(host, port, keepalive=30)
    sub_client.loop_start()
    connected.wait(timeout=5)

    if not connected.is_set():
        report("Subscriber connected", False, "timeout")
        sub_client.loop_stop()
        return

    report("Subscriber connected", True)

    # Publisher
    pub_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    pub_client.connect(host, port, keepalive=30)
    pub_client.loop_start()

    published_count = 0
    for topic in TOPICS:
        for i in range(3):
            payload = json.dumps({
                "value": round(random.uniform(15, 85), 2),
                "unit": {"temperature": "C", "pressure": "bar", "motor_speed": "rpm"}
                    .get(topic.split("/")[-1], "?"),
                "timestamp": time.time(),
                "seq": i,
            })
            info = pub_client.publish(topic, payload, qos=1)
            info.wait_for_publish(timeout=5)
            published_count += 1

    report("Published messages", True, f"count={published_count}")

    # Wait for messages to arrive
    time.sleep(2)

    pub_client.loop_stop()
    pub_client.disconnect()
    sub_client.loop_stop()
    sub_client.disconnect()

    report("Received messages", len(received) >= published_count,
           f"received={len(received)} expected>={published_count}")

    # Check topics coverage
    received_topics = set(m["topic"] for m in received)
    for topic in TOPICS:
        report(f"Topic {topic} received", topic in received_topics)


# ---------------------------------------------------------------------------
# Test: retained messages
# ---------------------------------------------------------------------------

def test_retained(host: str, port: int) -> None:
    print("\n--- test_retained ---")
    retain_topic = "factory/test/retained_check"
    retain_payload = json.dumps({"test": "retained", "ts": time.time()})

    # Publish a retained message
    pub = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    pub.connect(host, port, keepalive=10)
    pub.loop_start()
    info = pub.publish(retain_topic, retain_payload, qos=1, retain=True)
    info.wait_for_publish(timeout=5)
    pub.loop_stop()
    pub.disconnect()
    report("Published retained message", True)

    time.sleep(1)

    # Subscribe and check if we get the retained message
    got_retained: list[dict] = []
    ready = threading.Event()

    def on_connect(c: Any, ud: Any, fl: Any, rc: Any, props: Any = None) -> None:
        c.subscribe(retain_topic, qos=1)
        ready.set()

    def on_message(c: Any, ud: Any, msg: Any) -> None:
        got_retained.append({"retain": msg.retain, "payload": msg.payload.decode()})

    sub = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    sub.on_connect = on_connect
    sub.on_message = on_message
    sub.connect(host, port, keepalive=10)
    sub.loop_start()
    ready.wait(timeout=5)
    time.sleep(2)
    sub.loop_stop()
    sub.disconnect()

    report("Received retained message", len(got_retained) > 0,
           f"count={len(got_retained)}")
    if got_retained:
        report("Retain flag set", got_retained[0].get("retain", False) is True)

    # Cleanup: clear retained message
    cleanup = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    cleanup.connect(host, port, keepalive=10)
    cleanup.loop_start()
    cleanup.publish(retain_topic, b"", qos=1, retain=True).wait_for_publish(timeout=5)
    cleanup.loop_stop()
    cleanup.disconnect()


# ---------------------------------------------------------------------------
# Test: QoS levels
# ---------------------------------------------------------------------------

def test_qos(host: str, port: int) -> None:
    print("\n--- test_qos ---")
    for qos_level in (0, 1, 2):
        topic = f"factory/test/qos{qos_level}"
        payload = f"qos_test_{qos_level}"
        received: list[str] = []
        ready = threading.Event()

        def on_connect(c, ud, fl, rc, props=None, t=topic, q=qos_level):
            c.subscribe(t, qos=q)
            ready.set()

        def on_message(c, ud, msg, r=received):
            r.append(msg.payload.decode())

        sub = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        sub.on_connect = on_connect
        sub.on_message = on_message
        sub.connect(host, port, keepalive=10)
        sub.loop_start()
        ready.wait(timeout=5)

        pub = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        pub.connect(host, port, keepalive=10)
        pub.loop_start()
        pub.publish(topic, payload, qos=qos_level).wait_for_publish(timeout=5)
        time.sleep(1)

        pub.loop_stop()
        pub.disconnect()
        sub.loop_stop()
        sub.disconnect()

        report(f"QoS {qos_level} round-trip", payload in received,
               f"received={received}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Test MQTT locally with Mosquitto")
    parser.add_argument("--broker", default="localhost:1883", help="MQTT broker host:port")
    args = parser.parse_args()

    host, port = parse_broker(args.broker)

    print("=" * 60)
    print("MQTT Local Test (Mosquitto)")
    print("=" * 60)

    if not test_connect(host, port):
        print(f"\nCannot connect to {host}:{port}. Aborting.")
        sys.exit(1)

    test_pub_sub(host, port)
    test_retained(host, port)
    test_qos(host, port)

    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed, {passed + failed} total")
    print("=" * 60)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
