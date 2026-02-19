#!/usr/bin/env python3
# Script de génération du badge SBOM pour Kill_LIFE
# Analyse le fichier sbom.json et génère un summary JSON pour shields.io

import json
import os
from datetime import datetime

SBOM_PATH = 'docs/compliance/sbom.json'
OUTPUT = 'docs/sbom-summary.json'

status = 'success'
missing = []

# Charger SBOM
def load_sbom(path):
    if not os.path.exists(path):
        return None
    with open(path, 'r') as f:
        return json.load(f)

sbom = load_sbom(SBOM_PATH)
if not sbom or not sbom.get('components'):
    status = 'partial'
    missing.append('SBOM incomplet ou absent')

# Critère : SBOM complet (tous les composants listés)
count = len(sbom['components']) if sbom and sbom.get('components') else 0

badge = {
    "schemaVersion": 1,
    "label": "SBOM",
    "message": f"{count} composants" if status == 'success' else "incomplet",
    "color": "green" if status == 'success' else "yellow",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": missing
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge SBOM généré : {OUTPUT} (status: {badge['message']})")
