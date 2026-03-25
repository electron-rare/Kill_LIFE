# Factory 4.0 — Guide de deploiement on-premise

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Factory Floor                         │
│  PLC/SCADA ──► OPC-UA Server ──► opcua_mcp.py           │
│  Sensors   ──► MQTT Broker   ──► mqtt_mcp.py            │
│  Camera    ──► RTSP Stream   ──► vision_mcp.py (opt.)   │
└───────────────────┬─────────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────────┐
│                 Edge Server (Tower)                       │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐              │
│  │ Mascarade│  │  Ollama   │  │  Qdrant   │              │
│  │  (API)   │◄─┤ (LLM 7B) │  │ (vectors) │              │
│  └────┬─────┘  └──────────┘  └───────────┘              │
│       │                                                  │
│  ┌────▼──────────────────────────────────┐              │
│  │ Agents:                                │              │
│  │  - factory-copilot (operateur)         │              │
│  │  - maintenance-predictor (predictif)   │              │
│  │  - log-analyst (rapports)              │              │
│  └────────────────────────────────────────┘              │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐              │
│  │ InfluxDB │  │ Grafana  │  │ Mosquitto │              │
│  │ (TSDB)   │  │ (dashb.) │  │ (broker)  │              │
│  └──────────┘  └──────────┘  └───────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

| Composant | Version min. | Recommande |
|-----------|-------------|------------|
| Docker + Compose | 24.x | 25.x |
| RAM | 16 Go | 32 Go |
| CPU | 4 cores | 8 cores |
| Disque | 50 Go SSD | 200 Go NVMe |
| GPU (optionnel) | - | NVIDIA RTX 3060+ pour LLM rapide |
| OS | Ubuntu 22.04 / Debian 12 | Ubuntu 24.04 |

## 1. Installation rapide

```bash
# Cloner le depot
git clone https://github.com/yourorg/Kill_LIFE.git
cd Kill_LIFE

# Deployer la stack complete
bash deploy/factory/deploy_factory.sh
```

Le script `deploy_factory.sh` effectue :
- Pull des images Docker (Mascarade, Ollama, Qdrant, InfluxDB, Grafana, Mosquitto)
- Configuration des variables d'environnement
- Demarrage de la stack Docker Compose
- Health checks avec retry
- Import automatique du dashboard Grafana

## 2. Configuration des variables d'environnement

Creer un fichier `.env` a la racine :

```bash
# --- Mascarade / LLM ---
MASCARADE_PORT=8000
DEFAULT_PROVIDER=ollama
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=mistral:7b-instruct-v0.3-q4_K_M

# --- OPC-UA ---
OPCUA_ENDPOINT=opc.tcp://192.168.1.10:4840

# --- MQTT ---
MQTT_BROKER=localhost:1883
MQTT_USERNAME=
MQTT_PASSWORD=

# --- InfluxDB ---
INFLUXDB_URL=http://localhost:8086
INFLUXDB_TOKEN=my-super-secret-token
INFLUXDB_ORG=factory
INFLUXDB_BUCKET=sensors

# --- Grafana ---
GRAFANA_ADMIN_PASSWORD=admin

# --- Odoo (optionnel) ---
ODOO_URL=http://odoo.local:8069
ODOO_DB=production
ODOO_USERNAME=api_user
ODOO_PASSWORD=api_password
```

## 3. Deploiement par composant

### 3.1 Mosquitto (broker MQTT)

```bash
# Si deja un broker MQTT interne, pointer MQTT_BROKER dessus.
# Sinon, le compose le demarre automatiquement.
docker compose -f deploy/factory/factory-stack.yml up -d mosquitto

# Test :
mosquitto_pub -t "test/hello" -m "world"
mosquitto_sub -t "test/#" -C 1
```

### 3.2 OPC-UA

Le serveur OPC-UA est fourni par l'automate/SCADA existant. Configurer `OPCUA_ENDPOINT` vers celui-ci.

Pour tester sans materiel :

```bash
# Lancer le simulateur OPC-UA integre
pip install asyncua
python tools/industrial/test_opcua_simulator.py
```

### 3.3 InfluxDB + Grafana

```bash
docker compose -f deploy/factory/factory-stack.yml up -d influxdb grafana

# Creer le bucket "sensors" dans InfluxDB :
influx bucket create -n sensors -o factory -r 90d

# Le dashboard Grafana est importe automatiquement depuis :
# deploy/factory/grafana-dashboard.json
```

### 3.4 Ollama + Mascarade

```bash
docker compose -f deploy/factory/factory-stack.yml up -d ollama mascarade

# Telecharger le modele LLM
docker exec ollama ollama pull mistral:7b-instruct-v0.3-q4_K_M

# Verifier
curl http://localhost:8000/health
curl http://localhost:11434/api/tags
```

### 3.5 MCP Servers industriels

```bash
# OPC-UA MCP server
bash tools/industrial/run_opcua_mcp.sh

# MQTT MCP server
bash tools/industrial/run_mqtt_mcp.sh
```

Les MCP servers sont enregistres dans Cline/Claude Code via les settings JSON.

## 4. Agents industriels

Les 3 agents sont configures dans Mascarade avec routing par domaine :

| Agent | Role | Provider |
|-------|------|----------|
| `factory-copilot` | Chatbot operateur, interroge OPC-UA/MQTT | ollama (local) |
| `maintenance-predictor` | Analyse series temporelles, alertes | ollama (local) |
| `log-analyst` | Lecture logs MES/ERP, rapports auto | ollama (local) |

Le routing Mascarade (strategy: domain) dirige les requetes vers Ollama sur le Tower pour garantir que les donnees industrielles ne quittent pas le reseau local.

## 5. Pipeline de donnees

### 5.1 Capteurs -> MQTT -> InfluxDB

Les capteurs publient sur MQTT. Un bridge Telegraf ou Node-RED ecrit dans InfluxDB :

```bash
# Avec Node-RED (deja configure) :
# Voir deploy/factory/nodered-flows.json

# Ou avec Telegraf :
# [[inputs.mqtt_consumer]]
#   servers = ["tcp://localhost:1883"]
#   topics = ["factory/#"]
# [[outputs.influxdb_v2]]
#   urls = ["http://localhost:8086"]
```

### 5.2 Detection d'anomalies

```bash
# Mode demo (sans InfluxDB) :
python tools/industrial/influxdb_ml_pipeline.py --demo

# Mode production :
python tools/industrial/influxdb_ml_pipeline.py --measurements temperature pressure vibration

# Sortie JSON pour integration :
python tools/industrial/influxdb_ml_pipeline.py --demo --json
```

### 5.3 Connecteur Odoo/OpenMES

```bash
# Lister les ordres de fabrication
python tools/industrial/odoo_connector.py list-mo

# Creer un OF
python tools/industrial/odoo_connector.py create-mo --product "Widget A" --qty 100

# Resume production
python tools/industrial/odoo_connector.py summary --days 30
```

## 6. Securite reseau

Recommandations pour un deploiement on-premise :

- **Isolation reseau** : La stack Factory 4.0 doit etre sur un VLAN dedie, separe du reseau bureautique
- **Pas d'acces internet** : Ollama tourne en local, aucune donnee ne sort du site
- **TLS MQTT** : Configurer Mosquitto avec certificats TLS pour le trafic capteur
- **OPC-UA Security** : Activer le mode `SignAndEncrypt` avec certificats X.509
- **Authentification** : Tous les services (Grafana, InfluxDB, Odoo) doivent avoir des credentials non-default
- **Firewall** : N'ouvrir que les ports necessaires entre les VLANs (1883, 4840, 8086, 3000, 8000)

## 7. Monitoring et maintenance

```bash
# Health check global
curl http://localhost:8000/health          # Mascarade
curl http://localhost:11434/api/tags       # Ollama
curl http://localhost:8086/health          # InfluxDB
curl http://localhost:3000/api/health      # Grafana

# Logs
docker compose -f deploy/factory/factory-stack.yml logs -f --tail=100

# Donnees simulees pour test
python deploy/factory/simulate_data.py
```

## 8. Mise a jour

```bash
cd Kill_LIFE
git pull
docker compose -f deploy/factory/factory-stack.yml pull
docker compose -f deploy/factory/factory-stack.yml up -d
bash deploy/factory/deploy_factory.sh  # re-run health checks + grafana import
```

## 9. Contacts support

- Documentation technique : `docs/plans/27_todo_factory_4_0_mcp_opcua_mqtt.md`
- Agents Mascarade : voir PR #30 dans le repo mascarade
- Architecture MCP : `tools/industrial/opcua_mcp.py`, `mqtt_mcp.py`
