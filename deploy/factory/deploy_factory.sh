#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Factory 4.0 — Déploiement on-premise ==="
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker requis. Installez: https://docs.docker.com/engine/install/"; exit 1; }
command -v docker compose >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1 || { echo "Docker Compose requis."; exit 1; }

echo "1. Démarrage des services..."
cd "$SCRIPT_DIR"
docker compose up -d

echo ""
echo "2. Attente du démarrage (30s)..."
sleep 30

echo ""
echo "3. Pull des modèles Ollama..."
docker exec -it $(docker compose ps -q ollama) ollama pull devstral 2>/dev/null || echo "  devstral: skip (pull manuellement)"
docker exec -it $(docker compose ps -q ollama) ollama pull nomic-embed-text 2>/dev/null || echo "  nomic-embed-text: skip"
docker exec -it $(docker compose ps -q ollama) ollama pull qwen3:4b 2>/dev/null || echo "  qwen3:4b: skip"

echo ""
echo "4. Vérification..."
echo "  Mascarade:  $(curl -s -m 5 http://localhost:8100/health | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status","?"))' 2>/dev/null || echo 'DOWN')"
echo "  Ollama:     $(curl -s -m 5 http://localhost:11435/api/tags | python3 -c 'import sys,json; print(f"{len(json.load(sys.stdin).get(\"models\",[]))} models")' 2>/dev/null || echo 'DOWN')"
echo "  Qdrant:     $(curl -s -m 5 http://localhost:6333/collections | python3 -c 'import sys,json; print("OK")' 2>/dev/null || echo 'DOWN')"
echo "  Grafana:    $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:3000 || echo 'DOWN')"
echo "  InfluxDB:   $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:8086/health || echo 'DOWN')"
echo "  Mosquitto:  $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:9001 2>/dev/null && echo 'OK' || echo 'OK (MQTT only)')"
echo "  Node-RED:   $(curl -s -m 5 -o /dev/null -w '%{http_code}' http://localhost:1880 || echo 'DOWN')"

echo ""
echo "=== Factory 4.0 prêt ==="
echo "  Mascarade API:  http://localhost:8100"
echo "  Fake Ollama:    http://localhost:11434"
echo "  Grafana:        http://localhost:3000  (admin / factory4.0)"
echo "  Node-RED:       http://localhost:1880"
echo "  InfluxDB:       http://localhost:8086"
