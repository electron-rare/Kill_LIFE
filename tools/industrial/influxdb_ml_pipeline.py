#!/usr/bin/env python3
"""InfluxDB -> Anomaly Detection pipeline for predictive maintenance.

Reads time-series data from InfluxDB, runs moving-average + std-dev anomaly
detection, and outputs predictions/alerts. No heavy ML dependencies required.

Usage:
    # With real InfluxDB:
    export INFLUXDB_URL=http://localhost:8086
    export INFLUXDB_TOKEN=my-token
    export INFLUXDB_ORG=factory
    export INFLUXDB_BUCKET=sensors
    python tools/industrial/influxdb_ml_pipeline.py

    # Demo mode (no InfluxDB needed):
    python tools/industrial/influxdb_ml_pipeline.py --demo

Dependencies:
    pip install influxdb-client   # optional, has stub fallback
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from dataclasses import dataclass, field, asdict
from datetime import datetime, timedelta, timezone
from typing import Any

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://localhost:8086")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN", "")
INFLUXDB_ORG = os.getenv("INFLUXDB_ORG", "factory")
INFLUXDB_BUCKET = os.getenv("INFLUXDB_BUCKET", "sensors")


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class DataPoint:
    timestamp: float
    value: float
    measurement: str = ""
    tags: dict = field(default_factory=dict)


@dataclass
class Anomaly:
    timestamp: float
    value: float
    expected: float
    deviation_sigma: float
    measurement: str
    severity: str  # info, warning, critical

    @property
    def human_time(self) -> str:
        return datetime.fromtimestamp(self.timestamp, tz=timezone.utc).isoformat()


@dataclass
class Prediction:
    measurement: str
    trend: str  # stable, rising, falling
    mean: float
    std: float
    anomaly_count: int
    anomalies: list[Anomaly]
    health_score: float  # 0-100
    recommendation: str


# ---------------------------------------------------------------------------
# InfluxDB reader (with stub fallback)
# ---------------------------------------------------------------------------

try:
    from influxdb_client import InfluxDBClient

    HAS_INFLUX = True

    def query_influxdb(
        measurement: str,
        field_name: str = "value",
        hours_back: int = 24,
        url: str = "",
        token: str = "",
        org: str = "",
        bucket: str = "",
    ) -> list[DataPoint]:
        """Query InfluxDB for time-series data."""
        _url = url or INFLUXDB_URL
        _token = token or INFLUXDB_TOKEN
        _org = org or INFLUXDB_ORG
        _bucket = bucket or INFLUXDB_BUCKET

        client = InfluxDBClient(url=_url, token=_token, org=_org)
        query_api = client.query_api()

        flux = f'''
        from(bucket: "{_bucket}")
          |> range(start: -{hours_back}h)
          |> filter(fn: (r) => r._measurement == "{measurement}")
          |> filter(fn: (r) => r._field == "{field_name}")
          |> sort(columns: ["_time"])
        '''

        tables = query_api.query(flux, org=_org)
        points = []
        for table in tables:
            for record in table.records:
                points.append(DataPoint(
                    timestamp=record.get_time().timestamp(),
                    value=float(record.get_value()),
                    measurement=measurement,
                    tags=dict(record.values),
                ))
        client.close()
        return points

except ImportError:
    HAS_INFLUX = False

    def query_influxdb(
        measurement: str,
        field_name: str = "value",
        hours_back: int = 24,
        **kwargs: Any,
    ) -> list[DataPoint]:
        print(f"  [STUB] influxdb-client not installed. Returning empty for {measurement}.")
        return []


# ---------------------------------------------------------------------------
# Demo data generator
# ---------------------------------------------------------------------------

def generate_demo_data(measurement: str, hours: int = 24, interval_s: int = 60) -> list[DataPoint]:
    """Generate realistic sensor data with injected anomalies."""
    base_values = {
        "temperature": (22.0, 1.5),    # mean, std
        "pressure": (1.013, 0.02),
        "motor_speed": (1500.0, 25.0),
        "vibration": (0.5, 0.1),
        "current": (12.0, 0.8),
    }
    mean, std = base_values.get(measurement, (50.0, 5.0))

    now = time.time()
    start = now - hours * 3600
    points = []
    t = start

    # Inject a slow drift starting at 75% of the window
    drift_start = start + hours * 3600 * 0.75

    while t <= now:
        # Base value with noise
        v = mean + random.gauss(0, std * 0.3)

        # Add drift
        if t > drift_start:
            drift_pct = (t - drift_start) / (now - drift_start)
            v += std * 2 * drift_pct  # slow upward drift

        # Inject spikes (~2% chance)
        if random.random() < 0.02:
            v += std * random.choice([-3.5, 3.5, 4.0, -4.0])

        points.append(DataPoint(timestamp=t, value=v, measurement=measurement))
        t += interval_s

    return points


# ---------------------------------------------------------------------------
# Anomaly detection: moving average + z-score
# ---------------------------------------------------------------------------

def detect_anomalies(
    data: list[DataPoint],
    window: int = 30,
    sigma_warn: float = 2.0,
    sigma_crit: float = 3.0,
) -> list[Anomaly]:
    """Sliding-window anomaly detection using z-score."""
    if len(data) < window + 1:
        return []

    anomalies = []
    for i in range(window, len(data)):
        window_vals = [data[j].value for j in range(i - window, i)]
        mean = sum(window_vals) / len(window_vals)
        variance = sum((v - mean) ** 2 for v in window_vals) / len(window_vals)
        std = math.sqrt(variance) if variance > 0 else 1e-9

        z = abs(data[i].value - mean) / std
        if z >= sigma_crit:
            severity = "critical"
        elif z >= sigma_warn:
            severity = "warning"
        else:
            continue

        anomalies.append(Anomaly(
            timestamp=data[i].timestamp,
            value=data[i].value,
            expected=mean,
            deviation_sigma=round(z, 2),
            measurement=data[i].measurement,
            severity=severity,
        ))

    return anomalies


# ---------------------------------------------------------------------------
# Trend analysis
# ---------------------------------------------------------------------------

def analyze_trend(data: list[DataPoint], tail_pct: float = 0.25) -> str:
    """Simple trend detection: compare mean of last tail_pct vs first tail_pct."""
    if len(data) < 10:
        return "insufficient_data"
    n = max(1, int(len(data) * tail_pct))
    early_mean = sum(p.value for p in data[:n]) / n
    late_mean = sum(p.value for p in data[-n:]) / n

    all_vals = [p.value for p in data]
    overall_std = math.sqrt(sum((v - sum(all_vals) / len(all_vals)) ** 2 for v in all_vals) / len(all_vals))
    if overall_std < 1e-9:
        return "stable"

    delta = (late_mean - early_mean) / overall_std
    if delta > 0.5:
        return "rising"
    elif delta < -0.5:
        return "falling"
    return "stable"


def compute_health_score(anomalies: list[Anomaly], total_points: int) -> float:
    """Health score 0-100. 100 = no anomalies, penalize criticals more."""
    if total_points == 0:
        return 100.0
    penalty = 0
    for a in anomalies:
        if a.severity == "critical":
            penalty += 5
        else:
            penalty += 1
    score = max(0, 100 - (penalty / total_points) * 1000)
    return round(score, 1)


def make_recommendation(trend: str, health: float, anomalies: list[Anomaly]) -> str:
    crits = sum(1 for a in anomalies if a.severity == "critical")
    if health < 50:
        return f"URGENT: Health score {health}/100. {crits} critical anomalies detected. Schedule immediate inspection."
    if trend == "rising" and health < 80:
        return f"WARNING: Upward drift detected with health {health}/100. Plan maintenance within 48h."
    if trend == "falling" and health < 80:
        return f"WARNING: Downward drift detected with health {health}/100. Verify sensor calibration."
    if health < 80:
        return f"MONITOR: Health score {health}/100. Increase monitoring frequency."
    return f"OK: Health score {health}/100. Normal operating conditions."


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------

def run_pipeline(
    measurements: list[str],
    hours_back: int = 24,
    demo: bool = False,
) -> list[Prediction]:
    """Run the full anomaly-detection pipeline for each measurement."""
    results = []

    for m in measurements:
        if demo:
            data = generate_demo_data(m, hours=hours_back)
        else:
            data = query_influxdb(m, hours_back=hours_back)

        if not data:
            results.append(Prediction(
                measurement=m, trend="no_data", mean=0, std=0,
                anomaly_count=0, anomalies=[], health_score=100,
                recommendation=f"No data for {m}. Check sensor connectivity.",
            ))
            continue

        anomalies = detect_anomalies(data)
        trend = analyze_trend(data)
        values = [p.value for p in data]
        mean = sum(values) / len(values)
        std = math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))
        health = compute_health_score(anomalies, len(data))

        results.append(Prediction(
            measurement=m,
            trend=trend,
            mean=round(mean, 4),
            std=round(std, 4),
            anomaly_count=len(anomalies),
            anomalies=anomalies[-10:],  # keep last 10
            health_score=health,
            recommendation=make_recommendation(trend, health, anomalies),
        ))

    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="InfluxDB -> Anomaly Detection Pipeline")
    parser.add_argument("--demo", action="store_true", help="Use generated demo data (no InfluxDB needed)")
    parser.add_argument("--hours", type=int, default=24, help="Hours of history to analyze")
    parser.add_argument("--measurements", nargs="+",
                        default=["temperature", "pressure", "motor_speed", "vibration"],
                        help="Measurement names to analyze")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    print("=" * 60)
    print("InfluxDB -> Anomaly Detection Pipeline")
    print(f"Mode: {'demo' if args.demo else 'influxdb'} | Hours: {args.hours}")
    print(f"InfluxDB client: {'installed' if HAS_INFLUX else 'NOT installed (stub)'}")
    print("=" * 60)

    predictions = run_pipeline(args.measurements, args.hours, demo=args.demo)

    if args.json:
        output = []
        for p in predictions:
            d = asdict(p)
            # Convert anomaly timestamps to ISO
            for a in d["anomalies"]:
                a["time_iso"] = datetime.fromtimestamp(a["timestamp"], tz=timezone.utc).isoformat()
            output.append(d)
        print(json.dumps(output, indent=2))
    else:
        for p in predictions:
            print(f"\n--- {p.measurement} ---")
            print(f"  Trend:      {p.trend}")
            print(f"  Mean:       {p.mean}")
            print(f"  Std Dev:    {p.std}")
            print(f"  Anomalies:  {p.anomaly_count}")
            print(f"  Health:     {p.health_score}/100")
            print(f"  >> {p.recommendation}")
            if p.anomalies:
                print(f"  Recent anomalies:")
                for a in p.anomalies[-5:]:
                    t = datetime.fromtimestamp(a.timestamp, tz=timezone.utc).strftime("%H:%M:%S")
                    print(f"    [{a.severity.upper():8s}] {t}  value={a.value:.2f}  expected={a.expected:.2f}  ({a.deviation_sigma}σ)")

    print()


if __name__ == "__main__":
    main()
