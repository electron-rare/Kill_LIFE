#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

AUTONOMOUS_SCRIPT="${ROOT_DIR}/tools/run_autonomous_next_lots.sh"
LOT_CHAIN_SCRIPT="${ROOT_DIR}/tools/cockpit/lot_chain.sh"

MAX_ROUNDS=12
MAX_LOTS_PER_ROUND=1
VERBOSE=0
UPDATE_TRACKER=0

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/run_next_lots_autonomously.sh [options]

Execute automatiquement les lots utiles détectés, un par un, jusqu'à épuisement.

Options:
  --max-rounds <n>  Nombre max de cycles (défaut: 12)
  --max-lots <n>    Limite de lots à traiter par cycle (défaut: 1)
  --update-tracker  Met à jour `specs/03_plan.md` et `specs/04_tasks.md` à chaque cycle.
  --verbose         Logs de progression.
  -h, --help        Affiche cette aide.
EOF
}

log() {
  if [[ "${VERBOSE}" == "1" ]]; then
    printf '[lot-drain] %s\n' "$*"
  fi
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

lot_count_from_json() {
  local json="$1"
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(len(data.get("lots", [])))' "${json}"
}

lot_keys_from_json() {
  local json="$1"
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(" ".join(item.get("key", "") for item in data.get("lots", [])))' "${json}"
}

run_status_json() {
  bash "${AUTONOMOUS_SCRIPT}" json
}

status_no_lots() {
  local status_json="$1"
  local count
  count="$(lot_count_from_json "${status_json}")"
  if [[ "${count}" == "0" ]]; then
    return 0
  fi
  return 1
}

run_one_cycle() {
  local -a run_args=(run)
  run_args+=("--max-lots")
  run_args+=("${MAX_LOTS_PER_ROUND}")

  local output
  output="$(
    cd "${ROOT_DIR}" && bash "${AUTONOMOUS_SCRIPT}" "${run_args[@]}"
  )"
  printf '%s\n' "${output}"

  if printf '%s\n' "${output}" | rg -q "blocked=[1-9]"; then
    die "Blocage détecté sur le lot courant. Arrêt de la chaîne."
  fi

  if [[ "${UPDATE_TRACKER}" == "1" ]]; then
    bash "${LOT_CHAIN_SCRIPT}" all --yes >/dev/null
  else
    bash "${LOT_CHAIN_SCRIPT}" status >/dev/null
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-rounds)
      if [[ $# -lt 2 ]]; then
        die "Option --max-rounds nécessite une valeur"
      fi
      MAX_ROUNDS="$2"
      shift 2
      ;;
    --max-lots)
      if [[ $# -lt 2 ]]; then
        die "Option --max-lots nécessite une valeur"
      fi
      MAX_LOTS_PER_ROUND="$2"
      shift 2
      ;;
    --update-tracker)
      UPDATE_TRACKER=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Option inconnue: $1"
      ;;
  esac
done

if [[ "${MAX_ROUNDS}" -le 0 ]]; then
  die "max-rounds doit être un entier strictement positif."
fi
if [[ "${MAX_LOTS_PER_ROUND}" -le 0 ]]; then
  die "max-lots doit être un entier strictement positif."
fi

round=0
signature=""

while true; do
  if (( round >= MAX_ROUNDS )); then
    die "Limite max de cycles atteinte (${MAX_ROUNDS})."
  fi

  status_json="$(run_status_json)"
  if status_no_lots "${status_json}"; then
    log "Aucun lot utile détecté. Fin."
    break
  fi

  count="$(lot_count_from_json "${status_json}")"
  keys="$(lot_keys_from_json "${status_json}")"
  current_signature="${count}|${keys}"
  if [[ "${signature}" == "${current_signature}" ]]; then
    log "Aucun progrès détecté entre deux cycles successifs. Fin de la chaîne."
    break
  fi
  signature="${current_signature}"

  round=$((round + 1))
  printf '▶ Cycle %s/%s — %s lot(s): %s\n' "${round}" "${MAX_ROUNDS}" "${count}" "${keys}"
  run_one_cycle
done

printf '✅ Chaîne automatique terminée: %s cycle(s) executé(s).\n' "${round}"
