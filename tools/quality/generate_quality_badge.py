#!/usr/bin/env python3
# Script de génération du badge qualité pour Kill_LIFE
# Analyse les rapports lint, tests, build et génère un summary JSON pour shields.io

import json
import os
from datetime import datetime

LINT_PATH = 'docs/quality/lint_report.json'
TEST_PATH = 'docs/quality/test_report.json'
BUILD_PATH = 'docs/quality/build_report.json'
OUTPUT = 'docs/quality-summary.json'

status = 'success'
issues = []

# Charger rapport lint
def load_report(path):
    if not os.path.exists(path):
        return None
    with open(path, 'r') as f:
        return json.load(f)

lint = load_report(LINT_PATH)
test = load_report(TEST_PATH)
build = load_report(BUILD_PATH)

if lint and lint.get('errors', []):
    status = 'fail'
    issues += lint['errors']
if test and test.get('failures', []):
    status = 'fail'
    issues += test['failures']
if build and build.get('status') != 'success':
    status = 'fail'
    issues.append('Build failed')

badge = {
    "schemaVersion": 1,
    "label": "Quality",
    "message": "OK" if status == 'success' else f"{len(issues)} issues",
    "color": "green" if status == 'success' else "red",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": issues
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge qualité généré : {OUTPUT} (status: {badge['message']})")
