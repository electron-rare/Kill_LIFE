#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────
#  Frappe → Aperant Task Sync
#  Queries Frappe MariaDB directly on tower and pushes to Aperant API
# ─────────────────────────────────────────────────────────────────

APERANT_API="http://localhost:5181"
FRAPPE_CONTAINER="tower-frappe-suite-app"
FRAPPE_DB="_b99c0621d4d1bf2d"
MARIADB_CONTAINER="tower-frappe-suite-mariadb"

echo "[frappe-sync] Starting sync $(date -Iseconds)"

# Query tasks from MariaDB via the mariadb container
TASKS_JSON=$(docker exec "$MARIADB_CONTAINER" mariadb -u "$FRAPPE_DB" -p"iRyKw3deMst6Tf6z" "$FRAPPE_DB" -N -e "
SELECT JSON_ARRAYAGG(JSON_OBJECT(
  'name', name,
  'subject', subject,
  'status', status,
  'project', COALESCE(project, ''),
  'priority', COALESCE(priority, 'Medium'),
  'exp_start_date', COALESCE(exp_start_date, ''),
  'exp_end_date', COALESCE(exp_end_date, ''),
  'description', COALESCE(LEFT(description, 500), '')
)) FROM tabTask;
" 2>/dev/null)

if [ -z "$TASKS_JSON" ] || [ "$TASKS_JSON" = "NULL" ]; then
  echo "[frappe-sync] No tasks found"
  exit 0
fi

TASK_COUNT=$(echo "$TASKS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "[frappe-sync] Found $TASK_COUNT tasks in Frappe"

# Push to Aperant sync endpoint
curl -s -X POST "$APERANT_API/api/frappe/sync-bulk" \
  -H "Content-Type: application/json" \
  -d "{\"tasks\": $TASKS_JSON}" | python3 -m json.tool

echo "[frappe-sync] Done"
