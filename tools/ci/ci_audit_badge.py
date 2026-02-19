#!/usr/bin/env python3
# Génère un badge endpoint pour l’audit CI/CD

import json
from datetime import datetime

INPUT = 'docs/ci-audit-summary.json'
OUTPUT = 'docs/ci-audit-badge.json'

with open(INPUT, 'r') as f:
    report = json.load(f)

score = sum(1 for v in report['summary'].values() if v > 0)
max_score = len(report['summary'])

badge = {
    "schemaVersion": 1,
    "label": "CI Audit",
    "message": f"{score}/{max_score} domaines",
    "color": "green" if score == max_score else "yellow" if score >= max_score - 1 else "red",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": report['summary']
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge CI Audit généré : {OUTPUT} (score: {badge['message']})")
