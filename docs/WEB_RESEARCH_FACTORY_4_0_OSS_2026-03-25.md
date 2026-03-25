# Web Research — Factory 4.0 Open-Source Tools

Date: 2026-03-25

---

## 1. Predictive Maintenance & Time-Series Frameworks

### PatchTST (via Time-Series-Library)
- **URL**: https://github.com/thuml/Time-Series-Library
- **Stars**: ~7k (Time-Series-Library umbrella)
- **Last update**: Active (2025-2026)
- **Description**: Patch-based Transformer for long-term time-series forecasting. Treats series as sequences of patches rather than individual time steps. Channel-independent design reduces computational cost.
- **Relevance**: Direct fit for maintenance-predictor agent — vibration/temperature trend forecasting. Can predict degradation curves from InfluxDB data.
- **Integration difficulty**: Medium. Requires PyTorch, training pipeline. Best used via NeuralForecast wrapper.

### TimesNet (via Time-Series-Library)
- **URL**: https://github.com/thuml/Time-Series-Library
- **Stars**: Same umbrella repo
- **Last update**: Active
- **Description**: Temporal 2D-variation modeling for general time-series analysis (ICLR 2023). Handles forecasting, classification, imputation, and anomaly detection in a single architecture.
- **Relevance**: Multi-task capability ideal for factory: forecast + anomaly detection from the same model. Classification mode useful for failure-type identification.
- **Integration difficulty**: Medium. Same as PatchTST — PyTorch dependency, training pipeline needed.

### NeuralForecast (Nixtla)
- **URL**: https://github.com/Nixtla/neuralforecast
- **Stars**: ~4,000
- **Last update**: Active (v3.1.5, 2025-2026)
- **Description**: Unified interface for 30+ state-of-the-art neural forecasting models including PatchTST and TimesNet. Integrates with Ray/Optuna for hyperparameter optimization. Transfer learning support.
- **Relevance**: **Best entry point** for our stack. Single API wrapping PatchTST, TimesNet, NHITS, etc. Transfer learning means we can fine-tune on small factory datasets.
- **Integration difficulty**: Low-Medium. pip install, pandas DataFrame interface. Pair with InfluxDB export.

### PyOD (Python Outlier Detection)
- **URL**: https://github.com/yzhao062/pyod
- **Stars**: ~8,500
- **Last update**: Active
- **Description**: 20+ outlier/anomaly detection algorithms: isolation forest, autoencoders, LOF, ECOD, deep learning models. Unified API.
- **Relevance**: Ideal for real-time anomaly detection on sensor data. Complements time-series forecasting with point-anomaly detection. Lightweight, no training required for unsupervised methods.
- **Integration difficulty**: Low. pip install, sklearn-like API. Can run in maintenance-predictor agent.

### ADTK (Anomaly Detection Toolkit)
- **URL**: https://github.com/arundo/adtk
- **Stars**: ~1,100
- **Last update**: Maintenance mode (last release 0.6.2)
- **Description**: Rule-based and unsupervised anomaly detection specifically for time series. Built by Arundo for industrial IoT. Detectors, transformers, aggregators with pipe API.
- **Relevance**: Perfect for rule-based industrial thresholds (vibration > X mm/s). Simple to deploy, no ML training needed. Good complement to PyOD for structured rules.
- **Integration difficulty**: Low. pip install, pandas-native. Caveat: maintenance mode, may need forking for long-term use.

---

## 2. Vision Inspection

### Ultralytics YOLO (YOLOv8 / YOLO11 / YOLO26)
- **URL**: https://github.com/ultralytics/ultralytics
- **Stars**: ~55,000+
- **Last update**: Very active (2026)
- **Description**: State-of-the-art object detection, segmentation, classification, pose estimation. YOLOv8 is the stable industrial workhorse; YOLO11 and upcoming YOLO26 add architectural improvements.
- **Relevance**: Core of quality-inspector agent. Detect defects, missing components, label errors on production line. Runs on Jetson Nano/Xavier for edge deployment.
- **Integration difficulty**: Low. pip install ultralytics, train with labeled images. ONNX/TensorRT export for edge.

### Grounding DINO
- **URL**: https://github.com/IDEA-Research/GroundingDINO
- **Stars**: ~7,000+
- **Last update**: Active (ECCV 2024 paper)
- **Description**: Open-set object detection with text prompts. No training needed — describe what to find in natural language.
- **Relevance**: Zero-shot defect detection: operator types "scratch on surface" and model finds it. Useful for rare defects where training data is insufficient.
- **Integration difficulty**: Medium. PyTorch + transformers. Heavier than YOLO, better suited for offline analysis or GPU-equipped stations.

### Grounded-SAM (Grounding DINO + SAM2)
- **URL**: https://github.com/IDEA-Research/Grounded-Segment-Anything
- **Stars**: ~16,000+
- **Last update**: Active (2025-2026, SAM2 integration)
- **Description**: Combines Grounding DINO detection with SAM2 segmentation. Text-prompted detection + pixel-perfect masks. Autodistill integration for auto-labeling YOLOv8 training data.
- **Relevance**: **Key pipeline**: use Grounded-SAM to auto-label defect images, then train lightweight YOLOv8 for production edge. Also useful for measuring defect area/dimensions.
- **Integration difficulty**: Medium-High. Requires GPU, multi-model pipeline. Best as offline labeling/analysis tool, not real-time edge.

### SAM2 (Segment Anything Model 2)
- **URL**: https://github.com/facebookresearch/sam2
- **Stars**: ~12,000+
- **Last update**: Active
- **Description**: Meta's universal segmentation model. Video-capable. Supports prompted segmentation with points, boxes, or masks.
- **Relevance**: Video inspection on production lines (conveyor tracking). Segment parts in motion for counting, dimensional analysis.
- **Integration difficulty**: Medium. PyTorch, GPU recommended. Pairs with ComfyUI for visual pipeline building.

---

## 3. MES / SCADA / OPC-UA

### open62541
- **URL**: https://github.com/open62541/open62541
- **Stars**: ~3,000+
- **Last update**: Active (2025-2026)
- **Description**: OPC-UA stack in pure C. Platform-independent, certified for Standard Server 2017 Profile. MPLv2 license (commercial-friendly). Suitable for embedded systems.
- **Relevance**: If we need a lightweight OPC-UA server on edge devices (Jetson, RPi). Our opcua_mcp.py uses asyncua (Python), but open62541 is the reference for embedded C deployments.
- **Integration difficulty**: High (C library). Use only if Python asyncua is insufficient for edge performance.

### Eclipse Milo
- **URL**: https://github.com/eclipse-milo/milo
- **Stars**: ~1,100+
- **Last update**: Active
- **Description**: Java OPC-UA client/server SDK. Reference implementation for Eclipse IoT. Used as basis for PLC4X OPC-UA integration.
- **Relevance**: Relevant if factory runs Java/JVM stack. Our Python stack prefers asyncua, but Milo is the go-to for JVM-based SCADA integration.
- **Integration difficulty**: Medium (Java). Not directly useful for our Python stack unless bridging via PLC4X.

### Apache PLC4X
- **URL**: https://github.com/apache/plc4x / https://plc4x.apache.org/
- **Stars**: ~1,200+
- **Last update**: Active (Apache incubator graduate)
- **Description**: Universal PLC communication library. Supports S7 (Siemens), Modbus, ADS (Beckhoff), EtherNet/IP, OPC-UA, BACnet, KNX, and more. Java primary, Go secondary, C in progress.
- **Relevance**: **High value** for multi-vendor factories. Single library to talk to Siemens, Allen-Bradley, Beckhoff PLCs. Could replace multiple protocol-specific tools.
- **Integration difficulty**: Medium. Java-first (needs JVM). Python bindings limited. Could be called via HTTP gateway or used alongside our MCP servers.

### OpenMES / Open Source MES
- **URL**: Various — no single dominant OSS MES project
- **Last update**: Fragmented landscape
- **Description**: Open source Manufacturing Execution Systems are rare. Closest options: Odoo Manufacturing module, ERPNext manufacturing, or custom builds on top of MQTT/InfluxDB/Grafana.
- **Relevance**: Our stack (Mascarade + MQTT + InfluxDB + Grafana) effectively acts as a lightweight MES. Better to extend our own stack than adopt a half-maintained OSS MES.
- **Integration difficulty**: N/A — recommend building on our existing stack instead.

---

## 4. Node-RED Industrial Nodes

### node-red-contrib-opcua
- **URL**: https://flows.nodered.org/node/node-red-contrib-opcua
- **Stars**: Most popular OPC-UA package for Node-RED
- **Last update**: Active
- **Description**: OPC-UA client/server nodes for Node-RED. Browse, read, write, subscribe to OPC-UA servers directly from flows.
- **Relevance**: Direct complement to our nodered_connector.py. Allows flows that read OPC-UA data AND send to Mascarade agents in the same pipeline.
- **Integration difficulty**: Low. npm install in Node-RED.

### node-red-contrib-modbus
- **URL**: https://flows.nodered.org/node/node-red-contrib-modbus
- **Stars**: Most popular Modbus package
- **Last update**: Active
- **Description**: Full Modbus TCP/RTU/ASCII support. Read coils, registers, write outputs. Well-documented.
- **Relevance**: Essential for legacy PLC communication. Many older factory machines only support Modbus.
- **Integration difficulty**: Low. npm install.

### node-red-contrib-s7
- **URL**: https://flows.nodered.org/node/node-red-contrib-s7
- **Last update**: Active
- **Description**: Direct Siemens S7 PLC communication (S7-300, S7-400, S7-1200, S7-1500). Read/write PLC variables.
- **Relevance**: Critical for Siemens-heavy factories. Bypasses OPC-UA overhead for direct S7 protocol access.
- **Integration difficulty**: Low. npm install. Requires S7 PLC network access.

### node-red-contrib-mqtt-broker
- **URL**: Built into Node-RED core
- **Last update**: Always current
- **Description**: MQTT client nodes (subscribe, publish) are built into Node-RED core. No extra install needed.
- **Relevance**: Foundation of our Flow 1 (sensor data → Mascarade). Already used in nodered-flows.json.
- **Integration difficulty**: None. Built-in.

### FlowFuse (Node-RED management)
- **URL**: https://flowfuse.com / https://github.com/FlowFuse/flowfuse
- **Stars**: ~600+
- **Last update**: Active (2025-2026)
- **Description**: Enterprise Node-RED management platform. Multi-instance, team collaboration, DevOps pipelines for Node-RED flows. Open-source core.
- **Relevance**: Useful for scaling Node-RED across multiple factory sites. Manages flow deployment, version control, access control.
- **Integration difficulty**: Medium. Docker deployment. Adds operational overhead but valuable at scale.

---

## Summary — Recommended Integration Priority

| Priority | Tool | Use Case | Effort |
|----------|------|----------|--------|
| 1 | NeuralForecast (PatchTST/TimesNet) | Predictive maintenance forecasting | Medium |
| 1 | PyOD | Real-time anomaly detection | Low |
| 1 | Ultralytics YOLOv8 | Quality inspection edge | Low |
| 1 | node-red-contrib-opcua + modbus | Node-RED industrial protocol nodes | Low |
| 2 | Grounded-SAM | Auto-labeling pipeline for YOLOv8 | Medium |
| 2 | Apache PLC4X | Multi-vendor PLC gateway | Medium |
| 2 | ADTK | Rule-based threshold alerts | Low |
| 3 | FlowFuse | Multi-site Node-RED management | Medium |
| 3 | open62541 | Embedded OPC-UA (C) | High |

Sources:
- [Time-Series-Library (PatchTST, TimesNet)](https://github.com/thuml/Time-Series-Library)
- [NeuralForecast](https://github.com/Nixtla/neuralforecast)
- [PyOD](https://github.com/yzhao062/pyod)
- [ADTK](https://github.com/arundo/adtk)
- [Ultralytics YOLO](https://github.com/ultralytics/ultralytics)
- [Grounding DINO](https://github.com/IDEA-Research/GroundingDINO)
- [Grounded-SAM](https://github.com/IDEA-Research/Grounded-Segment-Anything)
- [SAM2](https://github.com/facebookresearch/sam2)
- [open62541](https://github.com/open62541/open62541)
- [Eclipse Milo](https://github.com/eclipse-milo/milo)
- [Apache PLC4X](https://plc4x.apache.org/)
- [FlowFuse](https://github.com/FlowFuse/flowfuse)
