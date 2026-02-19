# coverage_badge.py
"""
Script pour extraire le taux de couverture et générer un badge dynamique pour shields.io
"""
import json
import re

# Extraction du taux depuis coverage report
coverage_file = 'docs/coverage_report/index.html'
output_json = 'docs/coverage-summary.json'

try:
    with open(coverage_file, 'r', encoding='utf-8') as f:
        html = f.read()
    # Recherche du taux de couverture (ex: 'xx% covered')
    match = re.search(r'(\d+)%\s*covered', html)
    if match:
        coverage = int(match.group(1))
    else:
        coverage = 0
except Exception:
    coverage = 0

# Génération du JSON pour shields.io
badge = {
    "schemaVersion": 1,
    "label": "coverage",
    "message": f"{coverage}%",
    "color": "brightgreen" if coverage >= 80 else "orange" if coverage >= 50 else "red"
}

with open(output_json, 'w', encoding='utf-8') as f:
    json.dump(badge, f)

print(f"Coverage badge generated: {badge}")
