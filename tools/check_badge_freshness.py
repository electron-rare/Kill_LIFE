#!/usr/bin/env python3
# Vérifie la fraîcheur des fichiers badge summary JSON par rapport au dernier commit

import json
import os
import subprocess
from datetime import datetime, timezone

BADGE_PATHS = [
    'docs/security-summary.json',
    'docs/sbom-summary.json',
    'docs/doc-summary.json',
    'docs/quality-summary.json',
    'docs/community-summary.json',
    'docs/coverage-summary.json'
]

# Récupérer le timestamp du dernier commit (UTC)
def get_last_commit_timestamp():
    result = subprocess.run(['git', 'log', '-1', '--format=%ct'], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError('Impossible de récupérer le timestamp du dernier commit')
    return int(result.stdout.strip())

last_commit_ts = get_last_commit_timestamp()

errors = []
for path in BADGE_PATHS:
    if not os.path.exists(path):
        errors.append(f"Fichier absent : {path}")
        continue
    with open(path, 'r') as f:
        data = json.load(f)
    badge_ts = None
    if 'timestamp' in data:
        try:
            badge_ts = int(datetime.fromisoformat(data['timestamp'].replace('Z','')).replace(tzinfo=timezone.utc).timestamp())
        except Exception:
            errors.append(f"Timestamp invalide dans {path}")
    else:
        errors.append(f"Pas de champ timestamp dans {path}")
    if badge_ts and badge_ts < last_commit_ts:
        errors.append(f"Badge non actualisé : {path} (badge {badge_ts}, commit {last_commit_ts})")

if errors:
    print("\n\n--- ERREURS FRAÎCHEUR BADGE ---")
    for err in errors:
        print(err)
    print("\nÉchec : au moins un badge n'est pas actualisé.")
    exit(1)
else:
    print("Tous les badges sont actualisés (timestamp >= commit).")
    exit(0)
