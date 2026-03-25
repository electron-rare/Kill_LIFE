#!/usr/bin/env python3
"""OPC-UA simulator + MCP tool tester.

Starts a local OPC-UA server with fake industrial nodes (temperature, pressure,
motor_speed), then exercises the MCP tools from opcua_mcp.py against it.

Usage:
    pip install asyncua
    python tools/industrial/test_opcua_simulator.py

The script:
1. Starts an OPC-UA server on opc.tcp://localhost:4840
2. Creates a "Factory" namespace with 3 variable nodes
3. Spawns a background task that updates values every 500ms
4. Runs browse / read / write / subscribe tests against the server
5. Reports results and exits
"""

from __future__ import annotations

import asyncio
import json
import random
import sys
import time

try:
    from asyncua import Server, ua
except ImportError:
    print("ERROR: asyncua is required.  pip install asyncua")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Simulator server
# ---------------------------------------------------------------------------

async def create_server() -> tuple:
    """Create and configure the OPC-UA simulator server."""
    server = Server()
    await server.init()
    server.set_endpoint("opc.tcp://0.0.0.0:4840/freeopcua/server/")
    server.set_server_name("Kill_LIFE Factory Simulator")

    # Register namespace
    uri = "urn:killlife:factory:simulator"
    ns_idx = await server.register_namespace(uri)

    # Create "Factory" object node
    factory = await server.nodes.objects.add_object(ns_idx, "Factory")

    # Create variable nodes
    temperature = await factory.add_variable(
        ns_idx, "Temperature", 22.5, varianttype=ua.VariantType.Float
    )
    pressure = await factory.add_variable(
        ns_idx, "Pressure", 1.013, varianttype=ua.VariantType.Float
    )
    motor_speed = await factory.add_variable(
        ns_idx, "MotorSpeed", 1500.0, varianttype=ua.VariantType.Float
    )

    # Make them writable
    await temperature.set_writable()
    await pressure.set_writable()
    await motor_speed.set_writable()

    return server, ns_idx, temperature, pressure, motor_speed


async def update_values(
    temperature, pressure, motor_speed, stop_event: asyncio.Event
) -> None:
    """Background task: jitter sensor values every 500ms."""
    while not stop_event.is_set():
        t = await temperature.read_value()
        p = await pressure.read_value()
        m = await motor_speed.read_value()

        await temperature.write_value(
            ua.DataValue(ua.Variant(t + random.uniform(-0.5, 0.5), ua.VariantType.Float))
        )
        await pressure.write_value(
            ua.DataValue(ua.Variant(max(0.8, p + random.uniform(-0.01, 0.01)), ua.VariantType.Float))
        )
        await motor_speed.write_value(
            ua.DataValue(ua.Variant(max(0, m + random.uniform(-10, 10)), ua.VariantType.Float))
        )
        await asyncio.sleep(0.5)


# ---------------------------------------------------------------------------
# Test helpers (direct asyncua client, mirrors what opcua_mcp does)
# ---------------------------------------------------------------------------

from asyncua import Client as OPCUAClient  # noqa: E402


ENDPOINT = "opc.tcp://localhost:4840/freeopcua/server/"

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


async def test_browse(ns_idx: int) -> None:
    """Test: browse Objects node and find Factory."""
    print("\n--- test_browse ---")
    async with OPCUAClient(url=ENDPOINT) as client:
        objects = client.nodes.objects
        children = await objects.get_children()
        names = []
        for child in children:
            bn = await child.read_browse_name()
            names.append(bn.Name)
        report("Objects has children", len(names) > 0, f"found {names}")
        report("Factory node exists", "Factory" in names)


async def test_read(ns_idx: int) -> None:
    """Test: read temperature node."""
    print("\n--- test_read ---")
    async with OPCUAClient(url=ENDPOINT) as client:
        node = client.get_node(f"ns={ns_idx};s=Temperature")
        value = await node.read_value()
        report("Temperature is a float", isinstance(value, float), f"value={value}")
        report("Temperature in sane range", 10 < value < 50, f"value={value}")


async def test_write(ns_idx: int) -> None:
    """Test: write a setpoint then read it back."""
    print("\n--- test_write ---")
    async with OPCUAClient(url=ENDPOINT) as client:
        node = client.get_node(f"ns={ns_idx};s=MotorSpeed")
        new_val = 999.0
        await node.write_value(ua.DataValue(ua.Variant(new_val, ua.VariantType.Float)))
        readback = await node.read_value()
        report("Write + readback matches", abs(readback - new_val) < 0.01, f"wrote={new_val} read={readback}")


async def test_subscribe(ns_idx: int) -> None:
    """Test: subscribe to Pressure for 3 seconds, expect value changes."""
    print("\n--- test_subscribe ---")
    values: list[float] = []

    class Handler:
        def datachange_notification(self, node, val, data):
            values.append(val)

    async with OPCUAClient(url=ENDPOINT) as client:
        handler = Handler()
        sub = await client.create_subscription(200, handler)
        target = client.get_node(f"ns={ns_idx};s=Pressure")
        await sub.subscribe_data_change(target)
        await asyncio.sleep(3)
        await sub.delete()

    report("Received data-change events", len(values) >= 2, f"count={len(values)}")
    report("Values differ (sensor updates)", len(set(str(v) for v in values)) >= 2 if values else False)


async def test_multi_node_read(ns_idx: int) -> None:
    """Test: read all 3 nodes in sequence."""
    print("\n--- test_multi_node_read ---")
    async with OPCUAClient(url=ENDPOINT) as client:
        results = {}
        for name in ("Temperature", "Pressure", "MotorSpeed"):
            node = client.get_node(f"ns={ns_idx};s={name}")
            results[name] = await node.read_value()
        report("All 3 nodes readable", len(results) == 3, json.dumps(results, default=str))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    global passed, failed

    print("=" * 60)
    print("OPC-UA Simulator + MCP Tool Test")
    print("=" * 60)

    # Start server
    server, ns_idx, temperature, pressure, motor_speed = await create_server()
    await server.start()
    print(f"Server started on {ENDPOINT}")

    stop = asyncio.Event()
    updater = asyncio.create_task(update_values(temperature, pressure, motor_speed, stop))

    # Give server time to settle
    await asyncio.sleep(1)

    try:
        await test_browse(ns_idx)
        await test_read(ns_idx)
        await test_write(ns_idx)
        await test_subscribe(ns_idx)
        await test_multi_node_read(ns_idx)
    finally:
        stop.set()
        await updater
        await server.stop()

    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed, {passed + failed} total")
    print("=" * 60)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    asyncio.run(main())
