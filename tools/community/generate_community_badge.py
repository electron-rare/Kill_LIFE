#!/usr/bin/env python3
# Script de génération du badge communauté pour Kill_LIFE
# Analyse les données GitHub Contributors, Discussions, Code of Conduct et génère un summary JSON pour shields.io

import json
import os
from datetime import datetime

CONTRIB_PATH = 'docs/community/contributors.json'
DISCUSS_PATH = 'docs/community/discussions.json'
COC_PATH = 'docs/community/code_of_conduct.json'
OUTPUT = 'docs/community-summary.json'

contributors = 0
active_discussions = 0
coc_status = 'absent'

# Charger rapport contributors
def load_report(path):
    if not os.path.exists(path):
        return None
    with open(path, 'r') as f:
        return json.load(f)

contrib = load_report(CONTRIB_PATH)
discuss = load_report(DISCUSS_PATH)
coc = load_report(COC_PATH)

if contrib and contrib.get('count'):
    contributors = contrib['count']
if discuss and discuss.get('active'):
    active_discussions = discuss['active']
if coc and coc.get('status') == 'present':
    coc_status = 'présent'

badge = {
    "schemaVersion": 1,
    "label": "Community",
    "message": f"{contributors} contrib, {active_discussions} discussions, COC {coc_status}",
    "color": "purple" if contributors > 2 and active_discussions > 0 and coc_status == 'présent' else "grey",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": {
        "contributors": contributors,
        "active_discussions": active_discussions,
        "code_of_conduct": coc_status
    }
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge communauté généré : {OUTPUT} (status: {badge['message']})")
