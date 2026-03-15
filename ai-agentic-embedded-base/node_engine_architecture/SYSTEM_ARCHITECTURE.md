# Universal Node Engine — System Architecture

## Vision

Créer une plateforme nodale universelle capable d’orchestrer :

- IA / LLM
- pipelines de datasets
- conception CAD
- électronique (PCB)
- firmware
- hardware temps réel (PIO)
- fabrication
- automation

Le système agit comme un **orchestrateur de systèmes complexes**.

Inspirations :

- Node-RED
- ComfyUI
- Kubeflow
- FreeCAD automation
- KiCad scripting

Objectif : **une interface visuelle unique pour concevoir des systèmes intelligents physiques et numériques**.

---

# Architecture globale

Le moteur est basé sur un **graph nodal exécuté par un orchestrateur**.

Node Editor
↓
Graph Store
↓
Pipeline Orchestrator
↓
Scheduler
↓
Execution Workers
↓
Artifacts / Hardware

---

# Les quatre domaines du moteur

AI Pipeline  
CAD Pipeline  
Electronics Pipeline  
Hardware Runtime  

---

# AI / LLM Pipeline

Dataset Source  
↓  
Data Processing  
↓  
Dataset Builder  
↓  
Training  
↓  
Evaluation  
↓  
Model Registry  
↓  
Deployment  

Nodes typiques:

dataset_file  
clean_text  
tokenize  
instruction_dataset  
lora_training  
benchmark  
deploy_model  

Artifacts :

datasets  
models  
metrics  
experiments  

---

# CAD Pipeline

Parameters  
↓  
Geometry Generation  
↓  
CAD Modeling  
↓  
Simulation  
↓  
Manufacturing  

Outils:

OpenSCAD  
FreeCAD  

Nodes:

dimension_parameter  
openscad_geometry  
freecad_sketch  
freecad_extrude  
generate_stl  
generate_step  

Artifacts:

3D models  
STL  
STEP  

---

# Electronics Pipeline

Schematic  
↓  
Netlist  
↓  
PCB Layout  
↓  
Fabrication Files  

Outils:

KiCad  
ngspice  

Nodes:

kicad_create_project  
kicad_add_component  
kicad_connect_net  
kicad_route_board  
kicad_export_gerber  

---

# Hardware Runtime

pio_program_load  
pio_stream_write  
pio_stream_read  
hardware_trigger  
dma_transfer  

Pipeline typique:

model_inference  
↓  
command_generation  
↓  
pio_stream_write  
↓  
hardware_execution  

---

# Scheduler

local_cpu  
local_gpu  
gpu_cluster  
cloud_api  
hardware_device  

---

# Execution Workers

dataset_worker  
training_worker  
cad_worker  
electronics_worker  
hardware_worker  
inference_worker  

---

# Artifacts System

artifacts/

datasets/  
models/  
cad_models/  
pcb/  
firmware/  
experiments/  

---

# Objectif final

Créer une plateforme capable de concevoir, entraîner, générer, fabriquer et piloter des systèmes intelligents dans une seule interface nodale.
