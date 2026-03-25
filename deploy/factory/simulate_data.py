#!/usr/bin/env python3
"""
Factory 4.0 — Simulated MQTT sensor data generator.

Publishes fake industrial sensor data (vibrations, temperature, motor current)
to a Mosquitto MQTT broker. Simulates normal operation with periodic anomalies
(gradual degradation, sudden spikes).

Usage:
    python3 simulate_data.py --broker localhost --interval 5 --duration 300
    python3 simulate_data.py --broker localhost --machines 8 --anomaly-rate 0.15
"""

import argparse
import json
import math
import random
import signal
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("ERROR: paho-mqtt required. Install: pip install paho-mqtt")
    sys.exit(1)


# ─── Machine profiles ─────────────────────────────────────────────

MACHINE_PROFILES = {
    "cnc-mill": {
        "vibration_base": 2.5, "vibration_std": 0.4,
        "temperature_base": 45.0, "temperature_std": 3.0,
        "current_base": 12.0, "current_std": 1.5,
    },
    "conveyor": {
        "vibration_base": 1.2, "vibration_std": 0.2,
        "temperature_base": 35.0, "temperature_std": 2.0,
        "current_base": 5.0, "current_std": 0.8,
    },
    "press": {
        "vibration_base": 4.0, "vibration_std": 0.8,
        "temperature_base": 55.0, "temperature_std": 5.0,
        "current_base": 22.0, "current_std": 3.0,
    },
    "robot-arm": {
        "vibration_base": 1.8, "vibration_std": 0.3,
        "temperature_base": 40.0, "temperature_std": 2.5,
        "current_base": 8.0, "current_std": 1.0,
    },
    "compressor": {
        "vibration_base": 3.2, "vibration_std": 0.5,
        "temperature_base": 65.0, "temperature_std": 4.0,
        "current_base": 18.0, "current_std": 2.5,
    },
}

ALERT_THRESHOLDS = {
    "vibration": {"warning": 4.5, "critical": 7.1},
    "temperature": {"warning": 80.0, "critical": 95.0},
    "current": {"warning": 30.0, "critical": 42.0},
}


# ─── Anomaly simulation ───────────────────────────────────────────

@dataclass
class AnomalyState:
    """Tracks per-machine anomaly status."""
    active: bool = False
    anomaly_type: str = ""        # "degradation" or "spike"
    field: str = ""               # which sensor field
    start_tick: int = 0
    duration_ticks: int = 0
    intensity: float = 0.0       # multiplier
    progress: float = 0.0


@dataclass
class MachineState:
    machine_id: str
    profile_name: str
    uptime_start: float = field(default_factory=time.time)
    total_ticks: int = 0
    uptime_ticks: int = 0
    anomaly: AnomalyState = field(default_factory=AnomalyState)


def maybe_start_anomaly(state: MachineState, anomaly_rate: float, tick: int):
    """Randomly trigger an anomaly on this machine."""
    if state.anomaly.active:
        return
    if random.random() > anomaly_rate:
        return

    atype = random.choice(["degradation", "spike"])
    afield = random.choice(["vibration", "temperature", "current"])

    if atype == "degradation":
        duration = random.randint(10, 30)
        intensity = random.uniform(1.5, 3.0)
    else:  # spike
        duration = random.randint(2, 5)
        intensity = random.uniform(2.5, 5.0)

    state.anomaly = AnomalyState(
        active=True, anomaly_type=atype, field=afield,
        start_tick=tick, duration_ticks=duration, intensity=intensity,
    )


def apply_anomaly(state: MachineState, field_name: str, value: float, tick: int) -> float:
    """Apply anomaly distortion to a sensor value if applicable."""
    a = state.anomaly
    if not a.active or a.field != field_name:
        return value

    elapsed = tick - a.start_tick
    if elapsed >= a.duration_ticks:
        state.anomaly = AnomalyState()  # reset
        return value

    if a.anomaly_type == "degradation":
        # Gradual ramp up
        progress = elapsed / a.duration_ticks
        multiplier = 1.0 + (a.intensity - 1.0) * progress
    else:  # spike
        # Sudden jump then plateau
        multiplier = a.intensity

    return value * multiplier


# ─── Data generation ───────────────────────────────────────────────

def generate_reading(state: MachineState, tick: int) -> dict:
    """Generate one sensor reading for a machine."""
    profile = MACHINE_PROFILES[state.profile_name]

    # Base values with Gaussian noise + slight sinusoidal drift (thermal cycle)
    t = tick * 0.1
    vibration = (
        profile["vibration_base"]
        + random.gauss(0, profile["vibration_std"])
        + 0.3 * math.sin(t * 0.7)
    )
    temperature = (
        profile["temperature_base"]
        + random.gauss(0, profile["temperature_std"])
        + 2.0 * math.sin(t * 0.2)
    )
    current = (
        profile["current_base"]
        + random.gauss(0, profile["current_std"])
        + 1.0 * math.sin(t * 0.5)
    )

    # Apply anomaly distortion
    vibration = apply_anomaly(state, "vibration", vibration, tick)
    temperature = apply_anomaly(state, "temperature", temperature, tick)
    current = apply_anomaly(state, "current", current, tick)

    # Clamp to realistic ranges
    vibration = max(0.0, round(vibration, 3))
    temperature = max(-10.0, round(temperature, 2))
    current = max(0.0, round(current, 2))

    state.total_ticks += 1
    state.uptime_ticks += 1

    return {
        "machine_id": state.machine_id,
        "machine_type": state.profile_name,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "vibration": vibration,
        "temperature": temperature,
        "current": current,
        "uptime_ratio": round(state.uptime_ticks / max(state.total_ticks, 1), 4),
    }


def check_alerts(reading: dict) -> list[dict]:
    """Check if any reading crosses alert thresholds."""
    alerts = []
    for field_name, thresholds in ALERT_THRESHOLDS.items():
        val = reading.get(field_name, 0)
        if val >= thresholds["critical"]:
            severity = "critical"
        elif val >= thresholds["warning"]:
            severity = "warning"
        else:
            continue
        alerts.append({
            "machine_id": reading["machine_id"],
            "timestamp": reading["timestamp"],
            "field": field_name,
            "value": val,
            "severity": severity,
            "message": f"{field_name} {severity}: {val} on {reading['machine_id']}",
        })
    return alerts


# ─── MQTT publishing ──────────────────────────────────────────────

def publish_reading(client: mqtt.Client, reading: dict):
    mid = reading["machine_id"]
    payload = json.dumps(reading)
    client.publish(f"factory/sensors/{mid}", payload, qos=1)
    client.publish("factory/sensors/all", payload, qos=0)


def publish_alert(client: mqtt.Client, alert: dict):
    payload = json.dumps(alert)
    client.publish(f"factory/alerts/{alert['machine_id']}", payload, qos=1)
    client.publish("factory/alerts/all", payload, qos=1)


def publish_status(client: mqtt.Client, state: MachineState):
    payload = json.dumps({
        "machine_id": state.machine_id,
        "machine_type": state.profile_name,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_ratio": round(state.uptime_ticks / max(state.total_ticks, 1), 4),
        "anomaly_active": state.anomaly.active,
        "anomaly_type": state.anomaly.anomaly_type if state.anomaly.active else None,
    })
    client.publish(f"factory/status/{state.machine_id}", payload, qos=1, retain=True)


# ─── Main loop ─────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Factory 4.0 simulated MQTT sensor data generator"
    )
    parser.add_argument("--broker", default="localhost", help="MQTT broker host (default: localhost)")
    parser.add_argument("--port", type=int, default=1883, help="MQTT broker port (default: 1883)")
    parser.add_argument("--interval", type=float, default=5.0, help="Seconds between readings (default: 5)")
    parser.add_argument("--duration", type=int, default=300, help="Total duration in seconds, 0=infinite (default: 300)")
    parser.add_argument("--machines", type=int, default=5, help="Number of machines to simulate (default: 5)")
    parser.add_argument("--anomaly-rate", type=float, default=0.05, help="Anomaly probability per tick per machine (default: 0.05)")
    parser.add_argument("--quiet", action="store_true", help="Suppress per-reading output")
    args = parser.parse_args()

    # Build machine fleet
    profile_names = list(MACHINE_PROFILES.keys())
    machines: list[MachineState] = []
    for i in range(args.machines):
        profile = profile_names[i % len(profile_names)]
        machines.append(MachineState(
            machine_id=f"{profile}-{i+1:02d}",
            profile_name=profile,
        ))

    # MQTT connect
    client = mqtt.Client(client_id=f"factory-sim-{random.randint(1000,9999)}")
    print(f"Connecting to MQTT broker {args.broker}:{args.port} ...")
    try:
        client.connect(args.broker, args.port, keepalive=60)
    except Exception as e:
        print(f"ERROR: Cannot connect to broker: {e}")
        sys.exit(1)
    client.loop_start()
    print(f"Connected. Simulating {len(machines)} machines, interval={args.interval}s, duration={'infinite' if args.duration == 0 else f'{args.duration}s'}")
    print(f"  Machines: {', '.join(m.machine_id for m in machines)}")
    print(f"  Topics: factory/sensors/{{id}}, factory/alerts/{{id}}, factory/status/{{id}}")
    print()

    # Graceful shutdown
    running = True
    def handle_signal(sig, frame):
        nonlocal running
        running = False
        print("\nShutting down...")
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    tick = 0
    start = time.time()
    total_readings = 0
    total_alerts = 0

    try:
        while running:
            if args.duration > 0 and (time.time() - start) >= args.duration:
                break

            for state in machines:
                maybe_start_anomaly(state, args.anomaly_rate, tick)
                reading = generate_reading(state, tick)
                publish_reading(client, reading)
                publish_status(client, state)
                total_readings += 1

                alerts = check_alerts(reading)
                for alert in alerts:
                    publish_alert(client, alert)
                    total_alerts += 1
                    if not args.quiet:
                        print(f"  !! ALERT {alert['severity'].upper()}: {alert['message']}")

                if not args.quiet:
                    anom = " [ANOMALY]" if state.anomaly.active else ""
                    print(
                        f"  [{reading['timestamp'][:19]}] {state.machine_id}: "
                        f"vib={reading['vibration']:.2f} temp={reading['temperature']:.1f} "
                        f"cur={reading['current']:.1f}{anom}"
                    )

            if not args.quiet:
                print(f"--- tick {tick} | {total_readings} readings | {total_alerts} alerts ---")
                print()

            tick += 1
            time.sleep(args.interval)

    finally:
        client.loop_stop()
        client.disconnect()
        elapsed = time.time() - start
        print(f"\nDone. {total_readings} readings, {total_alerts} alerts in {elapsed:.0f}s")


if __name__ == "__main__":
    main()
