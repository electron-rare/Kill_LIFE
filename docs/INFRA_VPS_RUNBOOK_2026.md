# INFRA VPS RUNBOOK 2026

## Objectif

Ce runbook definit la procedure operatoire pour superviser les services VPS exposes et remonter leur etat dans la gateway cockpit.

## Sources et artefacts

- Inventaire canonique: artifacts/cockpit/infra_vps_inventory.json
- Healthcheck live: artifacts/cockpit/infra_vps_healthcheck_latest.json
- Gateway runtime: artifacts/cockpit/runtime_mcp_ia_gateway_latest.json

## Commandes standard

1. Verifier le statut runtime global:

```bash
bash tools/cockpit/runtime_ai_gateway.sh --action status --json
```

2. Lancer le healthcheck infra VPS complet:

```bash
bash tools/cockpit/infra_vps_healthcheck.sh --json \
  > artifacts/cockpit/infra_vps_healthcheck_latest.json
```

3. Regenerer la gateway apres healthcheck:

```bash
bash tools/cockpit/runtime_ai_gateway.sh --action status --json \
  > artifacts/cockpit/runtime_mcp_ia_gateway_latest.json
```

## Verification rapide

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path('artifacts/cockpit/runtime_mcp_ia_gateway_latest.json')
if not path.exists():
    print('missing runtime payload')
    raise SystemExit(1)

payload = json.loads(path.read_text(encoding='utf-8'))
infra = (payload.get('surfaces') or {}).get('infra_vps') or {}
print('overall:', payload.get('status'))
print('infra_vps.status:', infra.get('status'))
print('infra_vps.summary_short:', infra.get('summary_short'))
print('infra_vps.degraded_reasons:', infra.get('degraded_reasons', []))
PY
```

## Decision matrix

- Statut infra_vps = ready
  - Action: aucune action corrective immediate.
  - Suivi: relancer le healthcheck en routine operatoire.

- Statut infra_vps = degraded
  - Action 1: relancer le healthcheck pour confirmer la degradation.
  - Action 2: identifier les services en echec (dns, tcp, tls, http).
  - Action 3: corriger service par service, puis republier le fichier live.

- Statut infra_vps = blocked
  - Action 1: traiter comme incident operatoire prioritaire.
  - Action 2: verifier reverse proxy, DNS et certificats.
  - Action 3: publier un brief incident dans docs/evidence.

## Criteres de cloture

- artifacts/cockpit/infra_vps_healthcheck_latest.json present et coherent.
- surface infra_vps visible dans le payload runtime gateway.
- next_steps runtime reduits ou vides pour la lane infra_vps.