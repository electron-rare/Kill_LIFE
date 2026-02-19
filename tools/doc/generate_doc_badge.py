#!/usr/bin/env python3
# Script de génération du badge documentation pour Kill_LIFE
# Analyse le rapport de couverture doc et génère un summary JSON pour shields.io

import json
import os
from datetime import datetime

DOC_COVERAGE_PATH = 'docs/doc/doc_coverage.json'
OUTPUT = 'docs/doc-summary.json'

coverage = 0
missing = []

# Charger rapport doc coverage
def load_doc_coverage(path):
    if not os.path.exists(path):
        return None
    with open(path, 'r') as f:
        return json.load(f)

doc = load_doc_coverage(DOC_COVERAGE_PATH)
if doc and doc.get('coverage'):
    coverage = doc['coverage']
else:
    missing.append('Rapport doc coverage absent')

badge = {
    "schemaVersion": 1,
    "label": "Doc Coverage",
    "message": f"{coverage}%" if coverage else "absent",
    "color": "blue" if coverage >= 80 else "yellow" if coverage >= 50 else "red",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": missing
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge documentation généré : {OUTPUT} (status: {badge['message']})")
