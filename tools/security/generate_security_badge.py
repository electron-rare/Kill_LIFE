#!/usr/bin/env python3
# Script de génération du badge sécurité pour Kill_LIFE
# Analyse les rapports Snyk, CodeQL, Trivy et génère un summary JSON pour shields.io

import json
import os
from datetime import datetime

# Chemins des rapports (exemples)
SNYK_REPORT = 'docs/security/snyk_report.json'
CODEQL_REPORT = 'docs/security/codeql_report.json'
TRIVY_REPORT = 'docs/security/trivy_report.json'
OUTPUT = 'docs/security-summary.json'

status = 'success'
issues = []

# Fonction pour charger un rapport JSON
def load_report(path):
    if not os.path.exists(path):
        return None
    with open(path, 'r') as f:
        return json.load(f)

# Analyse Snyk
snyk = load_report(SNYK_REPORT)
if snyk and snyk.get('issues', []):
    status = 'fail'
    issues += snyk['issues']

# Analyse CodeQL
codeql = load_report(CODEQL_REPORT)
if codeql and codeql.get('alerts', []):
    status = 'fail'
    issues += codeql['alerts']

# Analyse Trivy
trivy = load_report(TRIVY_REPORT)
if trivy and trivy.get('results', []):
    for result in trivy['results']:
        if result.get('Vulnerabilities'):
            status = 'fail'
            issues += result['Vulnerabilities']

# Génération du summary pour shields.io
badge = {
    "schemaVersion": 1,
    "label": "Security Scan",
    "message": "OK" if status == 'success' else f"{len(issues)} vuln",
    "color": "green" if status == 'success' else "red",
    "timestamp": datetime.utcnow().isoformat() + 'Z',
    "details": issues
}

with open(OUTPUT, 'w') as f:
    json.dump(badge, f, indent=2)

print(f"Badge sécurité généré : {OUTPUT} (status: {badge['message']})")
