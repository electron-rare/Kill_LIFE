#!/usr/bin/env python3
# Scan RFC2119 conformité dans specs/*.md et génère docs/rfc2119-summary.json

import json
import re
from datetime import datetime, timezone
from pathlib import Path

files = sorted(Path("specs").rglob("*.md"))

rfc_terms = ['MUST', 'SHOULD', 'MAY']
forbidden = [r'must', r'should', r'may', r'Must', r'Should', r'May']

summary = {
    'schemaVersion': 1,
    'label': 'Conformité RFC2119',
    'counts': {t: 0 for t in rfc_terms},
    'forbidden': [],
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'files': {}
}

for f in files:
    with open(f, 'r', encoding='utf-8') as fd:
        content = fd.read()
    key = str(f).replace("\\", "/")
    summary['files'][key] = {'MUST': 0, 'SHOULD': 0, 'MAY': 0, 'forbidden': []}
    for t in rfc_terms:
        summary['counts'][t] += len(re.findall(rf'\b{t}\b', content))
        summary['files'][key][t] = len(re.findall(rf'\b{t}\b', content))
    for forb in forbidden:
        matches = re.findall(rf'\b{forb}\b', content)
        if matches:
            summary['forbidden'] += matches
            summary['files'][key]['forbidden'] += matches

with open('docs/rfc2119-summary.json', 'w', encoding='utf-8') as fd:
    json.dump(summary, fd, indent=2)

print(f"Conformité RFC2119 : {summary['counts']} | Interdits : {summary['forbidden']}")
