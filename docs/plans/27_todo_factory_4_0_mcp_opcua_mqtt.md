# Todo 27 — Factory 4.0 : MCP OPC-UA/MQTT + IA industrielle

## P0 — MCP servers industriels

- [x] Créer `tools/industrial/opcua_mcp.py` — MCP server OPC-UA (browse, read, write, subscribe, discover) — asyncua + stub
- [x] Créer `tools/industrial/mqtt_mcp.py` — MCP server MQTT (subscribe, publish, topics, history) — paho-mqtt + stub
- [x] Créer `tools/industrial/run_opcua_mcp.sh` + `run_mqtt_mcp.sh` — scripts de lancement (pattern apify_mcp)
- [ ] Enregistrer les 2 MCP dans Cline + Claude Code settings
- [ ] Tester OPC-UA avec un simulateur (Prosys, open62541)
- [ ] Tester MQTT avec Mosquitto local

## P0 — Agents industriels

- [ ] Créer agent `factory-copilot` — chatbot opérateur interrogeant données machines (OPC-UA/MQTT)
- [ ] Créer agent `maintenance-predictor` — analyse séries temporelles, alertes maintenance prédictive
- [ ] Créer agent `log-analyst` — lecture logs MES/ERP, génération rapports automatiques
- [ ] Configurer le routing Mascarade pour les agents industriels (strategy: domain, provider: ollama)

## P0 — Documentation commerciale

- [ ] Rédiger fiche offre Starter (Copilote Opérateur)
- [ ] Rédiger fiche offre Pro (Factory Intelligence)
- [ ] Rédiger fiche offre Enterprise (Full Factory 4.0)
- [ ] Créer démo slide deck avec architecture Mermaid

## P1 — Vision industrielle

- [ ] Créer `tools/industrial/vision_mcp.py` — MCP server caméra RTSP + YOLOv8
- [ ] Pipeline ComfyUI/SAM2 pour segmentation défauts
- [ ] Script déploiement Jetson Nano/Xavier
- [ ] Agent `quality-inspector` — contrôle qualité automatisé

## P1 — Pipeline données

- [ ] Pipeline InfluxDB → PatchTST/TimesNet pour maintenance prédictive
- [x] Connecteur Node-RED → Mascarade (HTTP nodes) — `tools/industrial/nodered_connector.py` + `deploy/factory/nodered-flows.json`
- [ ] Connecteur OpenMES/Odoo → MCP server
- [ ] Dashboard Grafana template industriel (vibrations, température, courant)

## P1 — Packaging déploiement

- [ ] Docker Compose `factory-stack.yml` (Mascarade + Ollama + Qdrant + Grafana + InfluxDB + Mosquitto)
- [ ] Script `deploy_factory.sh` one-liner
- [ ] Documentation déploiement on-premise
- [ ] Test end-to-end avec données simulées

## P2 — Formation & documentation

- [ ] Agent `training-generator` — génère procédures maintenance depuis logs
- [ ] Base RAG manuels machines (ingestion PDF → Qdrant)
- [ ] Chatbot multilingue opérateur (FR/EN/DE) via Mascarade + agent translator
- [ ] Template rapport automatique (PDF export)
