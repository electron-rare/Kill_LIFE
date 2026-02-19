#!/usr/bin/env python3
# Génère un rapport d’audit CI/CD pour tous les workflows .github/workflows/*.yml

import glob
import yaml
import json
from datetime import datetime

workflows = glob.glob('.github/workflows/*.yml')

report = {
    'schemaVersion': 1,
    'label': 'Audit CI/CD',
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'workflows': {},
    'summary': {
        'tests': 0,
        'coverage': 0,
        'badges': 0,
        'compliance': 0,
        'docs': 0,
        'hardware': 0,
        'ai': 0
    }
}

for wf in workflows:
    with open(wf, 'r') as f:
        data = yaml.safe_load(f)
    wf_name = data.get('name', wf)
    jobs = data.get('jobs', {})
    wf_info = {'tests': False, 'coverage': False, 'badges': False, 'compliance': False, 'docs': False, 'hardware': False, 'ai': False}
    for job in jobs.values():
        steps = job.get('steps', [])
        for step in steps:
            run = step.get('run', '')
            if 'pytest' in run or 'pio test' in run or 'unittest' in run:
                wf_info['tests'] = True
            if 'coverage' in run:
                wf_info['coverage'] = True
            if 'badge' in run or 'shields.io' in run:
                wf_info['badges'] = True
            if 'compliance' in run or 'validate' in run:
                wf_info['compliance'] = True
            if 'mkdocs' in run:
                wf_info['docs'] = True
            if 'KiCad' in run or 'hw_gate' in run or 'schops' in run:
                wf_info['hardware'] = True
            if 'Codex' in step.get('name', '') or 'openai' in run:
                wf_info['ai'] = True
    for k in wf_info:
        if wf_info[k]:
            report['summary'][k] += 1
    report['workflows'][wf_name] = wf_info

with open('docs/ci-audit-summary.json', 'w') as f:
    json.dump(report, f, indent=2)

print(f"Rapport d’audit CI/CD généré : docs/ci-audit-summary.json")
