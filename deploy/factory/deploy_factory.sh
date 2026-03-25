#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Configurable env vars ────────────────────────────────────────
FACTORY_DOMAIN="${FACTORY_DOMAIN:-localhost}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-factory4.0}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
INFLUXDB_PORT="${INFLUXDB_PORT:-8086}"
MASCARADE_PORT="${MASCARADE_PORT:-8100}"
NODERED_PORT="${NODERED_PORT:-1880}"
MOSQUITTO_PORT="${MOSQUITTO_PORT:-1883}"
OLLAMA_DEBUG_PORT="${OLLAMA_DEBUG_PORT:-11435}"
HEALTH_RETRIES="${HEALTH_RETRIES:-12}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"

echo "=== Factory 4.0 — Deploiement on-premise ==="
echo ""
echo "  Domain:         $FACTORY_DOMAIN"
echo "  Admin password: ${ADMIN_PASSWORD:0:3}***"
echo "  Grafana:        :$GRAFANA_PORT"
echo "  InfluxDB:       :$INFLUXDB_PORT"
echo "  Mascarade:      :$MASCARADE_PORT"
echo "  Node-RED:       :$NODERED_PORT"
echo ""

# ─── Prerequisites ────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || { echo "Docker requis. Installez: https://docs.docker.com/engine/install/"; exit 1; }
command -v docker compose >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1 || { echo "Docker Compose requis."; exit 1; }

# ─── Export env for docker-compose interpolation ──────────────────
export GF_SECURITY_ADMIN_PASSWORD="$ADMIN_PASSWORD"
export DOCKER_INFLUXDB_INIT_PASSWORD="$ADMIN_PASSWORD"

# ─── Start services ──────────────────────────────────────────────
echo "1. Demarrage des services..."
cd "$SCRIPT_DIR"
docker compose up -d

# ─── Health check with retry loop ────────────────────────────────
echo ""
echo "2. Attente du demarrage (health check, max ${HEALTH_RETRIES}x${HEALTH_INTERVAL}s)..."

health_check() {
    local name="$1"
    local url="$2"
    local check_type="${3:-http}"  # http or tcp

    for attempt in $(seq 1 "$HEALTH_RETRIES"); do
        if [ "$check_type" = "http" ]; then
            status=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
            if [ "$status" -ge 200 ] && [ "$status" -lt 400 ]; then
                echo "  $name: UP (HTTP $status) [attempt $attempt]"
                return 0
            fi
        else
            if curl -s -m 3 "$url" >/dev/null 2>&1; then
                echo "  $name: UP [attempt $attempt]"
                return 0
            fi
        fi
        if [ "$attempt" -lt "$HEALTH_RETRIES" ]; then
            sleep "$HEALTH_INTERVAL"
        fi
    done
    echo "  $name: DOWN (failed after $HEALTH_RETRIES attempts)"
    return 1
}

HEALTH_FAILURES=0
health_check "Grafana"    "http://${FACTORY_DOMAIN}:${GRAFANA_PORT}/api/health"    || HEALTH_FAILURES=$((HEALTH_FAILURES + 1))
health_check "InfluxDB"   "http://${FACTORY_DOMAIN}:${INFLUXDB_PORT}/health"       || HEALTH_FAILURES=$((HEALTH_FAILURES + 1))
health_check "Mascarade"  "http://${FACTORY_DOMAIN}:${MASCARADE_PORT}/health"      || HEALTH_FAILURES=$((HEALTH_FAILURES + 1))
health_check "Node-RED"   "http://${FACTORY_DOMAIN}:${NODERED_PORT}"               || HEALTH_FAILURES=$((HEALTH_FAILURES + 1))
health_check "Ollama"     "http://${FACTORY_DOMAIN}:${OLLAMA_DEBUG_PORT}/api/tags"  || HEALTH_FAILURES=$((HEALTH_FAILURES + 1))

echo ""
if [ "$HEALTH_FAILURES" -gt 0 ]; then
    echo "  WARNING: $HEALTH_FAILURES service(s) did not pass health check."
else
    echo "  All services healthy."
fi

# ─── Pull Ollama models ──────────────────────────────────────────
echo ""
echo "3. Pull des modeles Ollama..."
OLLAMA_CONTAINER=$(docker compose ps -q ollama 2>/dev/null || echo "")
if [ -n "$OLLAMA_CONTAINER" ]; then
    docker exec "$OLLAMA_CONTAINER" ollama pull devstral 2>/dev/null || echo "  devstral: skip (pull manuellement)"
    docker exec "$OLLAMA_CONTAINER" ollama pull nomic-embed-text 2>/dev/null || echo "  nomic-embed-text: skip"
    docker exec "$OLLAMA_CONTAINER" ollama pull qwen3:4b 2>/dev/null || echo "  qwen3:4b: skip"
else
    echo "  Ollama container not found, skipping model pull."
fi

# ─── Grafana dashboard auto-import ────────────────────────────────
echo ""
echo "4. Import dashboard Grafana..."

GRAFANA_URL="http://${FACTORY_DOMAIN}:${GRAFANA_PORT}"
DASHBOARD_FILE="$SCRIPT_DIR/grafana-dashboard.json"

if [ -f "$DASHBOARD_FILE" ]; then
    # Wait for Grafana API to be fully ready
    for attempt in $(seq 1 "$HEALTH_RETRIES"); do
        grafana_ok=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$GRAFANA_URL/api/health" 2>/dev/null || echo "000")
        if [ "$grafana_ok" -ge 200 ] && [ "$grafana_ok" -lt 400 ]; then
            break
        fi
        sleep "$HEALTH_INTERVAL"
    done

    # Create InfluxDB datasource if not exists
    DS_EXISTS=$(curl -s -u "admin:${ADMIN_PASSWORD}" "$GRAFANA_URL/api/datasources/name/InfluxDB-Factory" -o /dev/null -w '%{http_code}' 2>/dev/null || echo "000")
    if [ "$DS_EXISTS" != "200" ]; then
        echo "  Creating InfluxDB datasource..."
        curl -s -u "admin:${ADMIN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -X POST "$GRAFANA_URL/api/datasources" \
            -d '{
                "name": "InfluxDB-Factory",
                "type": "influxdb",
                "access": "proxy",
                "url": "http://influxdb:8086",
                "jsonData": {
                    "version": "Flux",
                    "organization": "electron-rare",
                    "defaultBucket": "machines"
                },
                "secureJsonData": {
                    "token": ""
                }
            }' >/dev/null 2>&1 && echo "  Datasource created." || echo "  Datasource creation failed (may already exist)."
    else
        echo "  Datasource InfluxDB-Factory already exists."
    fi

    # Get datasource UID for template substitution
    DS_UID=$(curl -s -u "admin:${ADMIN_PASSWORD}" "$GRAFANA_URL/api/datasources/name/InfluxDB-Factory" 2>/dev/null \
        | python3 -c 'import sys,json; print(json.load(sys.stdin).get("uid",""))' 2>/dev/null || echo "")

    # Import dashboard
    echo "  Importing dashboard from grafana-dashboard.json..."

    # Build import payload: wrap dashboard and replace datasource input
    python3 -c "
import json, sys

with open('$DASHBOARD_FILE') as f:
    dash = json.load(f)

# Remove import-only fields
dash.pop('__inputs', None)
dash.pop('__requires', None)
dash['id'] = None

# Replace datasource UID placeholders
ds_uid = '${DS_UID}' or 'influxdb-factory'
raw = json.dumps(dash)
raw = raw.replace('\${DS_INFLUXDB}', ds_uid)
dash = json.loads(raw)

payload = {
    'dashboard': dash,
    'overwrite': True,
    'message': 'Auto-imported by deploy_factory.sh'
}
print(json.dumps(payload))
" | curl -s -u "admin:${ADMIN_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST "$GRAFANA_URL/api/dashboards/db" \
        -d @- >/dev/null 2>&1 \
    && echo "  Dashboard imported successfully." \
    || echo "  Dashboard import failed."
else
    echo "  grafana-dashboard.json not found, skipping."
fi

# ─── Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Factory 4.0 pret ==="
echo "  Mascarade API:  http://${FACTORY_DOMAIN}:${MASCARADE_PORT}"
echo "  Fake Ollama:    http://${FACTORY_DOMAIN}:11434"
echo "  Grafana:        http://${FACTORY_DOMAIN}:${GRAFANA_PORT}  (admin / ${ADMIN_PASSWORD:0:3}***)"
echo "  Node-RED:       http://${FACTORY_DOMAIN}:${NODERED_PORT}"
echo "  InfluxDB:       http://${FACTORY_DOMAIN}:${INFLUXDB_PORT}"
echo "  MQTT Broker:    mqtt://${FACTORY_DOMAIN}:${MOSQUITTO_PORT}"
echo ""
echo "Pour simuler des donnees capteurs:"
echo "  python3 $SCRIPT_DIR/simulate_data.py --broker ${FACTORY_DOMAIN} --interval 5 --duration 300"
