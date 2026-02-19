#!/bin/bash
# Script de scan automatique des secrets/tokens/code source dans la VM
set -euo pipefail

# Recherche de patterns sensibles dans /home et /root
find /home /root -type f \( -name '*' \) -exec grep -H -i -E 'token|secret|key|password|passwd|PRIVATE|API[_-]?KEY|Bearer' {} \; > /tmp/scan_secrets_report.txt || true

if [ -s /tmp/scan_secrets_report.txt ]; then
  echo "[ALERTE] Des patterns sensibles ont été trouvés :"
  cat /tmp/scan_secrets_report.txt
else
  echo "[OK] Aucun secret/token/code source détecté."
fi
