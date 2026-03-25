# Todo 27 — Factory 4.0 : MCP OPC-UA/MQTT + IA industrielle

## P0 — MCP servers industriels

- [x] Créer `tools/industrial/opcua_mcp.py` — MCP server OPC-UA (browse, read, write, subscribe, discover) — asyncua + stub
- [x] Créer `tools/industrial/mqtt_mcp.py` — MCP server MQTT (subscribe, publish, topics, history) — paho-mqtt + stub
- [x] Créer `tools/industrial/run_opcua_mcp.sh` + `run_mqtt_mcp.sh` — scripts de lancement (pattern apify_mcp)
- [x] Enregistrer les 2 MCP dans Cline + Claude Code settings — DONE (opcua + mqtt registered in Cline MCP settings)
- [x] Tester OPC-UA avec un simulateur (Prosys, open62541) — `tools/industrial/test_opcua_simulator.py`
- [x] Tester MQTT avec Mosquitto local — `tools/industrial/test_mqtt_local.py`

## P0 — Agents industriels

- [x] Créer agent `factory-copilot` — chatbot opérateur interrogeant données machines (OPC-UA/MQTT) — Mascarade PR #30
- [x] Créer agent `maintenance-predictor` — analyse séries temporelles, alertes maintenance prédictive — Mascarade PR #30
- [x] Créer agent `log-analyst` — lecture logs MES/ERP, génération rapports automatiques — Mascarade PR #30
- [x] Configurer le routing Mascarade pour les agents industriels (strategy: domain, provider: ollama) — DEFAULT_PROVIDER=ollama on Tower

## P0 — Documentation commerciale

- [x] Rédiger fiche offre Starter (Copilote Opérateur) — DONE in `docs/commercial/factory_4_0_starter.md`
- [x] Rédiger fiche offre Pro (Factory Intelligence) — DONE in `docs/commercial/factory_4_0_pro.md`
- [x] Rédiger fiche offre Enterprise (Full Factory 4.0) — DONE in `docs/commercial/factory_4_0_enterprise.md`
- [x] Créer démo slide deck avec architecture Mermaid — DONE in `docs/commercial/factory_4_0_slide_deck.md`

## P1 — Vision industrielle

- [ ] Créer `tools/industrial/vision_mcp.py` — MCP server caméra RTSP + YOLOv8
- [ ] Pipeline ComfyUI/SAM2 pour segmentation défauts
- [ ] Script déploiement Jetson Nano/Xavier
- [ ] Agent `quality-inspector` — contrôle qualité automatisé

## P1 — Pipeline données

- [x] Pipeline InfluxDB → PatchTST/TimesNet pour maintenance prédictive — `tools/industrial/influxdb_ml_pipeline.py` (moving avg + z-score)
- [x] Connecteur Node-RED → Mascarade (HTTP nodes) — `tools/industrial/nodered_connector.py` + `deploy/factory/nodered-flows.json`
- [x] Connecteur OpenMES/Odoo → MCP server — `tools/industrial/odoo_connector.py`
- [x] Dashboard Grafana template industriel (vibrations, température, courant) — `deploy/factory/grafana-dashboard.json`

## P1 — Packaging déploiement

- [x] Docker Compose `factory-stack.yml` (Mascarade + Ollama + Qdrant + Grafana + InfluxDB + Mosquitto) — DONE in `deploy/factory/docker-compose.yml`
- [x] Script `deploy_factory.sh` one-liner — health check retry, Grafana auto-import, env var customization
- [x] Documentation déploiement on-premise — `docs/FACTORY_4_0_DEPLOY_GUIDE.md`
- [x] Test end-to-end avec données simulées — `deploy/factory/simulate_data.py` (MQTT fake sensors + anomalies)

## P2 — Formation & documentation

- [x] Agent `training-generator` — génère procédures maintenance depuis logs — `tools/industrial/training_generator.py`
- [x] Base RAG manuels machines (ingestion PDF → Qdrant) — `tools/industrial/rag_ingestor.py`
- [x] Chatbot multilingue opérateur (FR/EN/DE) — intégré dans training_generator (templates FR/EN/DE)
- [x] Template rapport automatique (PDF export) — `tools/industrial/report_generator.py`
