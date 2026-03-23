#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────
#  Deploy Aperant Web to tower (clems@192.168.0.120)
#  Target: aperant.saillant.cc
# ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

TOWER_HOST="clems@192.168.0.120"
TOWER_APP_DIR="/home/clems/aperant-web"
DOMAIN="aperant.saillant.cc"

echo "── Aperant Web Deploy → ${DOMAIN} (tower)"
echo ""

# ── Step 1: Build locally ────────────────────────────────────────
echo "[1/5] Building web UI …"
(cd "${SCRIPT_DIR}" && npm run build)

# ── Step 2: Ensure remote directory ─────────────────────────────
echo "[2/5] Preparing tower …"
ssh "${TOWER_HOST}" "mkdir -p ${TOWER_APP_DIR}/{dist,server}"

# ── Step 3: Sync build artifacts ────────────────────────────────
echo "[3/5] Syncing build → tower …"
rsync -az --delete \
  "${SCRIPT_DIR}/dist/" \
  "${TOWER_HOST}:${TOWER_APP_DIR}/dist/"

rsync -az \
  "${SCRIPT_DIR}/server/" \
  "${TOWER_HOST}:${TOWER_APP_DIR}/server/"

rsync -az \
  "${SCRIPT_DIR}/package.json" \
  "${SCRIPT_DIR}/tsconfig.json" \
  "${TOWER_HOST}:${TOWER_APP_DIR}/"

# ── Step 4: Install server deps + build server on tower ─────────
echo "[4/5] Installing deps on tower …"
ssh "${TOWER_HOST}" "cd ${TOWER_APP_DIR} && npm install --omit=dev 2>&1 | tail -3"

# ── Step 5: Restart service ─────────────────────────────────────
echo "[5/5] Restarting aperant-web service …"
ssh "${TOWER_HOST}" "cd ${TOWER_APP_DIR} && \
  (pm2 delete aperant-web 2>/dev/null || true) && \
  pm2 start 'npx tsx server/index.ts' \
    --name aperant-web \
    --cwd ${TOWER_APP_DIR} \
    --env PORT=5181 && \
  pm2 save"

echo ""
echo "✓ Deployed to https://${DOMAIN}"
echo "  → API:  https://${DOMAIN}/api/health"
echo "  → PM2:  ssh ${TOWER_HOST} 'pm2 logs aperant-web'"
