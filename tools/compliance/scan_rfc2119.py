#!/usr/bin/env python3
# Scan RFC2119 conformité dans docs/specs/*.md et génère docs/rfc2119-summary.json

import glob
import json
import re
from datetime import datetime

files = glob.glob('docs/specs/*.md')

rfc_terms = ['MUST', 'SHOULD', 'MAY']
forbidden = [r'must', r'should', r'may', r'Must', r'Should', r'May']

summary = {
    'schemaVersion': 1,
    'label': 'Conformité RFC2119',
    'counts': {t: 0 for t in rfc_terms},
    'forbidden': [],
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'files': {}
}

for f in files:
    with open(f, 'r') as fd:
        content = fd.read()
    summary['files'][f] = {'MUST': 0, 'SHOULD': 0, 'MAY': 0, 'forbidden': []}
    for t in rfc_terms:
        summary['counts'][t] += len(re.findall(rf'\b{t}\b', content))
        summary['files'][f][t] = len(re.findall(rf'\b{t}\b', content))
    for forb in forbidden:
        matches = re.findall(rf'\b{forb}\b', content)
        if matches:
            summary['forbidden'] += matches
            summary['files'][f]['forbidden'] += matches

with open('docs/rfc2119-summary.json', 'w') as fd:
    json.dump(summary, fd, indent=2)

print(f"Conformité RFC2119 : {summary['counts']} | Interdits : {summary['forbidden']}")
