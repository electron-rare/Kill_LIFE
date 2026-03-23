#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
REGISTRY_FILE="${PROJECT_DIR}/specs/contracts/machine_registry.mesh.json"
LOG_DIR="${PROJECT_DIR}/artifacts/cockpit"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/mesh_sync_preflight_${TIMESTAMP}.log"
JSON_OUTPUT=0
VERBOSE=0
LOAD_PROFILE="tower-first"
OVERLOAD_LOAD_RATIO_LIMIT="1.8"
SSH_CONNECT_TIMEOUT="5"
SSH_REMOTE_COMMAND_TIMEOUT="15"
SSH_KEEPALIVE_INTERVAL="4"
SSH_KEEPALIVE_COUNT="2"
TOWER_HOST="clems@192.168.0.120"
KXKM_HOST="kxkm@kxkm-ai"
CILS_HOST="cils@100.126.225.111"
ROOT_HOST="root@192.168.0.119"
LOCAL_HOST_LABEL="local"
CRITICAL_REPOS=(Kill_LIFE)
ROOT_RESERVE_SCORE_BONUS="5000"
REGISTRY_STATUS="defaults"
declare -A HOST_BASE_SCORE=()
declare -A HOST_LOAD_RATIO=()
declare -A HOST_LOAD_PENALTY=()
declare -A HOST_LOAD_REASON=()
declare -A HOST_CONNECT_STATE=()
declare -A HOST_ID_BY_TARGET=()
declare -A HOST_PORT_BY_TARGET=()
declare -A HOST_ROLE_BY_TARGET=()
declare -A HOST_PRIORITY_BY_TARGET=()
declare -A HOST_PLACEMENT_BY_TARGET=()
declare -A HOST_ENABLED_PROFILES_BY_TARGET=()
declare -A HOST_CRITICAL_REPOS_BY_TARGET=()
declare -A HOST_NON_ESSENTIAL_POLICY=()
declare -A HOST_RESERVE_ONLY=()
declare -A HOST_LOAD_BIAS=()

RESULTS=()
TARGETS=()
TARGETS_ORDERED=()
HOST_ORDER=()

usage() {
  cat <<'USAGE'
Usage: bash tools/cockpit/mesh_sync_preflight.sh [options]

Options:
  --json           Emit a JSON summary to stdout.
  --no-log         Disable log file creation.
  --verbose        Show command-level details.
  --load-profile <tower-first|photon-safe>
                   Définit la stratégie de charge P2P.
                   - tower-first (défaut): clems -> kxkm -> cils -> local -> root (réserve)
                   - photon-safe: même ordre, mais CILS est totalement hors charge pour les préchecks non-SSH.
                   Ce mode évite les services non essentiels sur CILS et maintient les checks critiques
                   sur les hôtes de priorité plus haute/contrôlable.
                   Le runner calcule une charge relative par hôte (load/cpu) et allège
                   les vérifications non critiques sur les hôtes en surcharge.
                   Priorité métier: `tower (clems)` → `kxkm` → `cils (déchargé)` → `local` → `root (réserve reprise)`.
  --photon-safe    Alias de --load-profile photon-safe.
  -h, --help       Show this help message.

This script snapshots the tri-repo mesh state across the local workspace and the
known SSH machines, then reports whether the observed state is `ready`,
`degraded`, or `blocked`.
USAGE
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

trim_spaces() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s\n' "${msg}" >> "${LOG_FILE}"
  fi
}

run_ssh_command() {
  local host="$1"
  local port="$2"
  shift 2

  local script
  local tmp_script
  local output_file
  local pid=0
  local waited=0
  local rc=124

  script="$(cat)"
  tmp_script="$(mktemp)"
  output_file="$(mktemp)"
  printf '%s\n' "${script}" > "${tmp_script}"

  (
    ssh -o BatchMode=yes \
      -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
      -o ServerAliveInterval="${SSH_KEEPALIVE_INTERVAL}" \
      -o ServerAliveCountMax="${SSH_KEEPALIVE_COUNT}" \
      -o StrictHostKeyChecking=accept-new \
      -p "${port}" \
      "${host}" \
      bash -s -- "$@" < "${tmp_script}" > "${output_file}" 2>&1
  ) &
  pid=$!

  while (( waited < SSH_REMOTE_COMMAND_TIMEOUT )); do
    if kill -0 "${pid}" 2>/dev/null; then
      sleep 1
      waited=$((waited + 1))
    else
      break
    fi
  done

  if kill -0 "${pid}" 2>/dev/null; then
    kill -TERM "${pid}" 2>/dev/null || true
    sleep 1
    kill -KILL "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  else
    wait "${pid}" && rc=0 || rc=$?
  fi

  local output
  output="$(cat "${output_file}")"
  rm -f "${tmp_script}" "${output_file}"
  printf '%s\n' "${output}"
  return "${rc}"
}

run_ssh_command_direct() {
  local host="$1"
  local port="$2"
  shift 2

  local script
  local tmp_script
  local output
  local rc=0

  script="$(cat)"
  tmp_script="$(mktemp)"
  printf '%s\n' "${script}" > "${tmp_script}"

  output="$(
    ssh -o BatchMode=yes \
      -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
      -o ServerAliveInterval="${SSH_KEEPALIVE_INTERVAL}" \
      -o ServerAliveCountMax="${SSH_KEEPALIVE_COUNT}" \
      -o StrictHostKeyChecking=accept-new \
      -p "${port}" \
      "${host}" \
      bash -s -- "$@" < "${tmp_script}" 2>&1
  )" || rc=$?

  rm -f "${tmp_script}"
  printf '%s\n' "${output}"
  return "${rc}"
}

resolve_optional_local_path() {
  local candidate=""
  for candidate in "$@"; do
    [[ -n "${candidate}" ]] || continue
    if [[ -d "${candidate}" ]]; then
      (cd "${candidate}" >/dev/null 2>&1 && pwd)
      return 0
    fi
  done
  return 1
}

load_machine_registry() {
  local raw_registry=""
  local id=""
  local target=""
  local port=""
  local role=""
  local priority=""
  local placement=""
  local profiles=""
  local critical_repos=""
  local non_essential_policy=""
  local reserve_only=""
  local load_order_bias=""

  if [[ ! -f "${REGISTRY_FILE}" ]]; then
    REGISTRY_STATUS="missing"
    log_line "WARN" "Machine registry missing (${REGISTRY_FILE}); using embedded defaults"
    return 0
  fi

  if ! raw_registry="$(
    python3 - "${REGISTRY_FILE}" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
data = json.loads(registry_path.read_text(encoding="utf-8"))
for item in data.get("targets", []):
    fields = [
        item.get("id", ""),
        item.get("target", ""),
        str(item.get("port", 0)),
        item.get("role", ""),
        str(item.get("priority", 0)),
        item.get("placement", ""),
        ",".join(item.get("enabled_profiles", [])),
        ",".join(item.get("critical_repos", [])),
        item.get("non_essential_policy", ""),
        "true" if item.get("reserve_only") else "false",
        str(item.get("load_order_bias", 0)),
    ]
    print("|".join(value.replace("|", "/") for value in fields))
PY
  )"; then
    REGISTRY_STATUS="invalid"
    log_line "WARN" "Machine registry unreadable (${REGISTRY_FILE}); using embedded defaults"
    return 0
  fi

  if [[ -z "${raw_registry}" ]]; then
    REGISTRY_STATUS="empty"
    log_line "WARN" "Machine registry empty (${REGISTRY_FILE}); using embedded defaults"
    return 0
  fi

  while IFS='|' read -r id target port role priority placement profiles critical_repos non_essential_policy reserve_only load_order_bias; do
    [[ -n "${id}" && -n "${target}" ]] || continue
    HOST_ID_BY_TARGET["${target}"]="${id}"
    HOST_PORT_BY_TARGET["${target}"]="${port}"
    HOST_ROLE_BY_TARGET["${target}"]="${role}"
    HOST_PRIORITY_BY_TARGET["${target}"]="${priority}"
    HOST_PLACEMENT_BY_TARGET["${target}"]="${placement}"
    HOST_ENABLED_PROFILES_BY_TARGET["${target}"]="${profiles}"
    HOST_CRITICAL_REPOS_BY_TARGET["${target}"]="${critical_repos}"
    HOST_NON_ESSENTIAL_POLICY["${target}"]="${non_essential_policy}"
    HOST_RESERVE_ONLY["${target}"]="${reserve_only}"
    HOST_LOAD_BIAS["${target}"]="${load_order_bias}"

    case "${id}" in
      tower) TOWER_HOST="${target}" ;;
      kxkm) KXKM_HOST="${target}" ;;
      cils) CILS_HOST="${target}" ;;
      local) LOCAL_HOST_LABEL="${target}" ;;
      root-reserve) ROOT_HOST="${target}" ;;
    esac
  done <<< "${raw_registry}"

  if [[ "${#HOST_ID_BY_TARGET[@]}" -eq 0 ]]; then
    REGISTRY_STATUS="empty"
    log_line "WARN" "Machine registry has no usable targets (${REGISTRY_FILE}); using embedded defaults"
    return 0
  fi

  REGISTRY_STATUS="loaded"
}

host_base_priority() {
  local host="$1"
  local priority="${HOST_PRIORITY_BY_TARGET["${host}"]:-}"
  if [[ "${priority}" =~ ^[0-9]+$ ]] && [[ "${priority}" -gt 0 ]]; then
    echo "${priority}"
    return 0
  fi
  case "${host}" in
    "${TOWER_HOST}") echo 1 ;;
    "${KXKM_HOST}") echo 2 ;;
    "${CILS_HOST}") echo 3 ;;
    "${LOCAL_HOST_LABEL}") echo 4 ;;
    "${ROOT_HOST}") echo 5 ;;
    *) echo 10 ;;
  esac
}

host_static_score() {
  local host="$1"
  local load_bias="${HOST_LOAD_BIAS["${host}"]:-}"
  if [[ "${load_bias}" =~ ^[0-9]+$ ]] && [[ "${load_bias}" -gt 0 ]]; then
    echo "${load_bias}"
    return 0
  fi
  echo $(( $(host_base_priority "${host}") * 1000 ))
}

host_is_reserve_only() {
  local host="$1"
  if [[ "${HOST_RESERVE_ONLY["${host}"]:-false}" == "true" ]]; then
    return 0
  fi
  [[ "${host}" == "${ROOT_HOST}" ]]
}

host_role_or_default() {
  local host="$1"
  local fallback="$2"
  local role="${HOST_ROLE_BY_TARGET["${host}"]:-}"
  if [[ -n "${role}" ]]; then
    printf '%s\n' "${role}"
  else
    printf '%s\n' "${fallback}"
  fi
}

host_port_or_default() {
  local host="$1"
  local fallback="$2"
  local port="${HOST_PORT_BY_TARGET["${host}"]:-}"
  if [[ "${port}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${port}"
  else
    printf '%s\n' "${fallback}"
  fi
}

is_critical_repo() {
  local host="$1"
  local repo_name="$2"
  local critical
  local critical_repos="${HOST_CRITICAL_REPOS_BY_TARGET["${host}"]:-}"
  local critical_items=()

  if [[ -n "${critical_repos}" ]]; then
    IFS=',' read -r -a critical_items <<< "${critical_repos}"
  else
    critical_items=("${CRITICAL_REPOS[@]}")
  fi

  for critical in "${critical_items[@]}"; do
    if [[ "${repo_name}" == "${critical}" ]]; then
      return 0
    fi
  done
  return 1
}

host_load_is_overloaded() {
  local host="$1"
  local ratio="${HOST_LOAD_RATIO["${host}"]:-0}"
  if [[ "${HOST_CONNECT_STATE["${host}"]:-down}" != "ok" ]]; then
    return 1
  fi
  awk -v ratio="${ratio}" -v limit="${OVERLOAD_LOAD_RATIO_LIMIT}" 'BEGIN{exit (ratio > limit ? 0 : 1)}'
}

collect_local_load_profile() {
  local host="$1"
  local base_score
  local load_value="0"
  local cpu_count="1"
  local load_ratio="0"
  local load_penalty="0"
  local score

  if command -v nproc >/dev/null 2>&1; then
    cpu_count="$(nproc 2>/dev/null || printf '%s' "${cpu_count}")"
  elif command -v getconf >/dev/null 2>&1; then
    cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '%s' "${cpu_count}")"
  fi
  if command -v uptime >/dev/null 2>&1; then
    load_value="$(uptime | sed -n 's/.*load average: //p' | awk -F',' '{print $1}' | tr -d ' ')"
  fi
  [[ "${load_value}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || load_value="0"
  if [[ "${cpu_count}" -le 0 ]]; then
    cpu_count=1
  fi
  load_ratio="$(awk -v load="${load_value}" -v cpus="${cpu_count}" 'BEGIN{ratio=load/cpus; if (ratio < 0 || cpus <= 0) ratio = 0; printf "%.3f", ratio}')"
  load_penalty="$(awk -v ratio="${load_ratio}" 'BEGIN{printf "%d", ratio * 1000}')"
  base_score="$(host_static_score "${host}")"
  if host_is_reserve_only "${host}"; then
    score=$((base_score + load_penalty + ROOT_RESERVE_SCORE_BONUS))
  else
    score=$((base_score + load_penalty))
  fi
  HOST_BASE_SCORE["${host}"]="${score}"
  HOST_LOAD_RATIO["${host}"]="${load_ratio}"
  HOST_LOAD_PENALTY["${host}"]="${load_penalty}"
  HOST_LOAD_REASON["${host}"]="ready"
  HOST_CONNECT_STATE["${host}"]="ok"
}

collect_remote_load_profile() {
  local host="$1"
  local port="$2"
  local result
  local rc=0
  local load_value="0"
  local cpu_count="1"
  local load_ratio="0"
  local load_penalty="0"
  local base_score
  local score
  local output_line
  local parsed_ok=1

  if ! result="$(
    run_ssh_command "${host}" "${port}" <<'EOF'
load_value="0"
cpu_count="1"
if [ -f /proc/loadavg ]; then
  load_value=$(awk '{print $1}' /proc/loadavg)
elif command -v uptime >/dev/null 2>&1; then
  load_value=$(uptime | sed -n 's/.*load average: //p' | awk -F',' '{print $1}' | tr -d ' ')
fi
if [ -z "${load_value}" ]; then
  load_value="0"
fi
if command -v getconf >/dev/null 2>&1; then
  cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '%s' "${cpu_count}")
elif command -v nproc >/dev/null 2>&1; then
  cpu_count=$(nproc 2>/dev/null || printf '%s' "${cpu_count}")
fi
if [ -z "${cpu_count}" ] || [ "${cpu_count}" -le 0 ]; then
  cpu_count=1
fi
printf '%s|%s\n' "${load_value}" "${cpu_count}"
EOF
  )"; then
    rc=$?
  fi
  if [[ "${rc}" -ne 0 ]]; then
    if host_is_reserve_only "${host}"; then
      HOST_BASE_SCORE["${host}"]=$((99999 + ROOT_RESERVE_SCORE_BONUS))
    else
      HOST_BASE_SCORE["${host}"]=99999
    fi
    HOST_LOAD_RATIO["${host}"]="999"
    HOST_LOAD_PENALTY["${host}"]="999"
    HOST_LOAD_REASON["${host}"]="unreachable"
    HOST_CONNECT_STATE["${host}"]="unreachable"
    return 0
  fi

  output_line="$(printf '%s' "${result}" | tr -d '\r' | sed '/^$/d' | tail -n 1 || true)"
  if [[ -z "${output_line}" ]]; then
    if host_is_reserve_only "${host}"; then
      HOST_BASE_SCORE["${host}"]=$((99999 + ROOT_RESERVE_SCORE_BONUS))
    else
      HOST_BASE_SCORE["${host}"]=99999
    fi
    HOST_LOAD_RATIO["${host}"]="999"
    HOST_LOAD_PENALTY["${host}"]="999"
    HOST_LOAD_REASON["${host}"]="unreachable:empty-load-output"
    HOST_CONNECT_STATE["${host}"]="unreachable"
    return 0
  fi

  output_line=""
  while IFS= read -r parsed_line; do
    if [[ "${parsed_line}" =~ ^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*$ ]]; then
      output_line="$(printf '%s' "${parsed_line}" | tr -d '[:space:]')"
    fi
  done <<< "$(printf '%s' "${result}" | tr -d '\r' | awk '/\|/ { print }')"
  if [[ -z "${output_line}" ]]; then
    base_score="$(host_static_score "${host}")"
    if host_is_reserve_only "${host}"; then
      HOST_BASE_SCORE["${host}"]=$((base_score + 40 + ROOT_RESERVE_SCORE_BONUS))
    else
      HOST_BASE_SCORE["${host}"]=$((base_score + 40))
    fi
    HOST_LOAD_RATIO["${host}"]="0.000"
    HOST_LOAD_PENALTY["${host}"]="40"
    HOST_LOAD_REASON["${host}"]="degraded:invalid-load-output"
    HOST_CONNECT_STATE["${host}"]="degraded"
    return 0
  fi
  output_line="$(printf '%s' "${output_line}" | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//')"
  cpu_count="$(printf '%s' "${output_line##*|}" | tr -d '[:space:]')"
  load_value="$(printf '%s' "${output_line%%|*}" | tr -d '[:space:]')"
  [[ "${load_value}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || load_value="0"
  if ! [[ "${cpu_count}" =~ ^[0-9]+$ ]]; then
    parsed_ok=0
    cpu_count="1"
  fi

  if [[ "${cpu_count}" -le 0 ]]; then
    cpu_count=1
  fi
  if [[ "${parsed_ok}" -eq 0 ]]; then
    log_line "WARN" "Invalid cpu_count for ${host}; forcing safe default: '${cpu_count}'"
  fi
  load_ratio="$(awk -v load="${load_value}" -v cpus="${cpu_count}" 'BEGIN{ratio=load/cpus; if (ratio < 0 || cpus <= 0) ratio = 0; printf "%.3f", ratio}')"
  load_penalty="$(awk -v ratio="${load_ratio}" 'BEGIN{printf "%d", ratio * 1000}')"
  if awk -v ratio="${load_ratio}" -v limit="${OVERLOAD_LOAD_RATIO_LIMIT}" 'BEGIN{exit (ratio > limit ? 0 : 1)}'; then
    HOST_LOAD_REASON["${host}"]="overload"
  else
    HOST_LOAD_REASON["${host}"]="ready"
  fi
  base_score="$(host_static_score "${host}")"
  if host_is_reserve_only "${host}"; then
    score=$((base_score + load_penalty + ROOT_RESERVE_SCORE_BONUS))
  else
    score=$((base_score + load_penalty))
  fi
  HOST_BASE_SCORE["${host}"]="${score}"
  HOST_LOAD_RATIO["${host}"]="${load_ratio}"
  HOST_LOAD_PENALTY["${host}"]="${load_penalty}"
  HOST_CONNECT_STATE["${host}"]="ok"
}

build_host_profiles() {
  local host
  local port
  local entry
  declare -A seen_hosts=()

  for entry in "${TARGETS[@]}"; do
    IFS='|' read -r host port _ <<< "${entry}"
    if [[ -n "${seen_hosts["${host}"]+x}" ]]; then
      continue
    fi
    seen_hosts["${host}"]=1
    if [[ "${LOAD_PROFILE}" == "photon-safe" ]] && [[ "${HOST_ID_BY_TARGET["${host}"]:-}" == "cils" ]]; then
      HOST_BASE_SCORE["${host}"]=99999
      HOST_LOAD_RATIO["${host}"]="999"
      HOST_LOAD_PENALTY["${host}"]="999"
      HOST_LOAD_REASON["${host}"]="cils-load-check-skipped-photon-safe"
      HOST_CONNECT_STATE["${host}"]="skipped"
      continue
    fi
    if [[ "${host}" == "${LOCAL_HOST_LABEL}" ]]; then
      collect_local_load_profile "${host}"
    else
      collect_remote_load_profile "${host}" "${port}"
    fi
  done

  HOST_ORDER=()
  while IFS='|' read -r _score host; do
    [[ -n "${host}" ]] || continue
    HOST_ORDER+=("${host}")
  done < <(for host in "${!HOST_BASE_SCORE[@]}"; do
    printf '%s|%s\n' "${HOST_BASE_SCORE["${host}"]}" "${host}"
  done | sort -t'|' -k1,1n)

  if [[ "${#HOST_ORDER[@]}" -eq 0 ]]; then
    log_line "WARN" "No host found for profiling; fallback to static order."
    TARGETS_ORDERED=("${TARGETS[@]}")
  fi
}

build_targets_ordered() {
  local host
  local entry
  TARGETS_ORDERED=()
  for host in "${HOST_ORDER[@]}"; do
    for entry in "${TARGETS[@]}"; do
      local target_host
      IFS='|' read -r target_host _ <<< "${entry}"
      if [[ "${target_host}" == "${host}" ]]; then
        TARGETS_ORDERED+=("${entry}")
      fi
    done
  done

  if [[ "${#TARGETS_ORDERED[@]}" -eq 0 ]]; then
    TARGETS_ORDERED=("${TARGETS[@]}")
  fi
}

append_load_skip_entry() {
  local repo_name="$1"
  local target_host="$2"
  local role="$3"
  local repo_path="$4"
  local reason="$5"
  append_result \
    "${repo_name}" "${target_host}" "${role}" "${repo_path}" "degraded" "" "load-skipped:${reason}" "" "1" "${reason}" "no"
}

build_targets() {
  local local_kill_life=""
  local local_mascarade=""
  local local_crazy=""

  local_kill_life="$(
    resolve_optional_local_path \
      "${PROJECT_DIR}/../Github_Repos/Perso/Kill_LIFE-main" \
      "${PROJECT_DIR}/../Kill_LIFE-main" \
      "${PROJECT_DIR}" \
      || true
  )"

  local_mascarade="$(
    resolve_optional_local_path \
      "${PROJECT_DIR}/../mascarade-main" \
      "${PROJECT_DIR}/../mascarade" \
      "${PROJECT_DIR}/../Github_Repos/Perso/mascarade-main" \
      "${PROJECT_DIR}/../mascarade-github" \
      "${PROJECT_DIR}/../Github_Repos/Perso/mascarade" \
      "${PROJECT_DIR}/../Github_Repos/mascarade" \
      || true
  )"
  if [[ -n "${local_mascarade}" ]]; then
    TARGETS+=("local|0|Workspace companion|mascarade|${local_mascarade}|docker-compose.yml")
  fi

  local_crazy="$(
    resolve_optional_local_path \
      "${PROJECT_DIR}/../crazy_life-main" \
      "${PROJECT_DIR}/../crazy_life" \
      "${PROJECT_DIR}/../crazy-life" \
      "${PROJECT_DIR}/../Github_Repos/Perso/crazy_life-main" \
      "${PROJECT_DIR}/../Github_Repos/Perso/crazy_life" \
      "${PROJECT_DIR}/../Github_Repos/Perso/crazy-life" \
      || true
  )"
  TARGETS+=(
    "${TOWER_HOST}|$(host_port_or_default "${TOWER_HOST}" 22)|$(host_role_or_default "${TOWER_HOST}" "Machine de pilotage / orchestration locale")|Kill_LIFE|/home/clems/Kill_LIFE-main|tools/repo_state/repo_refresh.sh"
    "${TOWER_HOST}|$(host_port_or_default "${TOWER_HOST}" 22)|$(host_role_or_default "${TOWER_HOST}" "Machine de pilotage / orchestration locale")|mascarade|/home/clems/mascarade-main|docker-compose.yml"
    "${TOWER_HOST}|$(host_port_or_default "${TOWER_HOST}" 22)|$(host_role_or_default "${TOWER_HOST}" "Machine de pilotage / orchestration locale")|crazy_life|/home/clems/crazy_life-main|"
    "${KXKM_HOST}|$(host_port_or_default "${KXKM_HOST}" 22)|$(host_role_or_default "${KXKM_HOST}" "Mac opérateur")|Kill_LIFE|/home/kxkm/Kill_LIFE-main|tools/repo_state/repo_refresh.sh"
    "${KXKM_HOST}|$(host_port_or_default "${KXKM_HOST}" 22)|$(host_role_or_default "${KXKM_HOST}" "Mac opérateur")|mascarade|/home/kxkm/mascarade-main|docker-compose.yml"
    "${KXKM_HOST}|$(host_port_or_default "${KXKM_HOST}" 22)|$(host_role_or_default "${KXKM_HOST}" "Mac opérateur")|crazy_life|/home/kxkm/crazy_life-main|"
    "${CILS_HOST}|$(host_port_or_default "${CILS_HOST}" 22)|$(host_role_or_default "${CILS_HOST}" "Mac opérateur secondaire")|Kill_LIFE|/Users/cils/Kill_LIFE-main|tools/repo_state/repo_refresh.sh"
    "${CILS_HOST}|$(host_port_or_default "${CILS_HOST}" 22)|$(host_role_or_default "${CILS_HOST}" "Mac opérateur secondaire")|mascarade|/Users/cils/mascarade-main|docker-compose.yml"
    "${CILS_HOST}|$(host_port_or_default "${CILS_HOST}" 22)|$(host_role_or_default "${CILS_HOST}" "Mac opérateur secondaire")|crazy_life|/Users/cils/crazy_life-main|"
    "${ROOT_HOST}|$(host_port_or_default "${ROOT_HOST}" 22)|$(host_role_or_default "${ROOT_HOST}" "Serveur système / exécution matérielle")|Kill_LIFE|/root/Kill_LIFE-main|tools/repo_state/repo_refresh.sh"
    "${ROOT_HOST}|$(host_port_or_default "${ROOT_HOST}" 22)|$(host_role_or_default "${ROOT_HOST}" "Serveur système / exécution matérielle")|mascarade|/root/mascarade-main|docker-compose.yml"
    "${ROOT_HOST}|$(host_port_or_default "${ROOT_HOST}" 22)|$(host_role_or_default "${ROOT_HOST}" "Serveur système / exécution matérielle")|crazy_life|/root/crazy_life-main|"
  )

  if [[ -n "${local_kill_life}" ]]; then
    TARGETS+=("${LOCAL_HOST_LABEL}|0|Workspace local|Kill_LIFE|${local_kill_life}|tools/repo_state/repo_refresh.sh")
  fi
  if [[ -n "${local_mascarade}" ]]; then
    TARGETS+=("${LOCAL_HOST_LABEL}|0|Workspace companion|mascarade|${local_mascarade}|docker-compose.yml")
  fi
  if [[ -n "${local_crazy}" ]]; then
    TARGETS+=("${LOCAL_HOST_LABEL}|0|Workspace companion|crazy_life|${local_crazy}|")
  fi
}

should_skip_entry() {
  local host="$1"
  local repo_name="$2"
  local reason=""
  local host_id="${HOST_ID_BY_TARGET["${host}"]:-}"

  if [[ "${LOAD_PROFILE}" == "photon-safe" ]] && [[ "${host_id}" == "cils" ]]; then
    reason="cils-lockdown-photon-safe"
    echo "${reason}"
    return 0
  fi

  if [[ "${host_id}" == "cils" ]] && ! is_critical_repo "${host}" "${repo_name}"; then
    reason="cils-lockdown"
    if [[ "${LOAD_PROFILE}" == "photon-safe" ]]; then
      reason="cils-lockdown-photon-safe"
    fi
    echo "${reason}"
    return 0
  fi

  if [[ "${host}" != "${LOCAL_HOST_LABEL}" ]] && host_load_is_overloaded "${host}" && ! is_critical_repo "${host}" "${repo_name}"; then
    reason="overload-${HOST_LOAD_RATIO["${host}"]}"
    echo "${reason}"
    return 0
  fi

  return 1
}

append_result() {
  local repo_name="$1"
  local target_host="$2"
  local role="$3"
  local repo_path="$4"
  local status="$5"
  local branch="$6"
  local sha="$7"
  local remote="$8"
  local dirty_count="$9"
  local dirty_sample="${10}"
  local script_ok="${11}"

  RESULTS+=("${repo_name}|${target_host}|${role}|${repo_path}|${status}|${branch}|${sha}|${remote}|${dirty_count}|${dirty_sample}|${script_ok}")
}

companion_preflight_script_for_repo() {
  local repo_name="$1"
  case "${repo_name}" in
    mascarade) printf '%s\n' "scripts/mesh_runtime_preflight.sh" ;;
    crazy_life) printf '%s\n' "scripts/mesh_web_preflight.sh" ;;
    *) return 1 ;;
  esac
}

snapshot_kv_lines_from_output() {
  local parsed_line=""
  local key=""
  local value=""

  while IFS= read -r parsed_line; do
    parsed_line="$(trim_spaces "${parsed_line}")"
    [[ -z "${parsed_line}" ]] && continue

    if [[ "${parsed_line}" == *"="* ]]; then
      printf '%s\n' "${parsed_line}"
      continue
    fi

    case "${parsed_line}" in
      \"status\"*|\"branch\"*|\"sha\"*|\"remote\"*|\"dirty_count\"*|\"dirty_sample\"*|\"script_ok\"*|\"required_ok\"*)
        key="$(printf '%s\n' "${parsed_line}" | sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p')"
        value="$(printf '%s\n' "${parsed_line}" | sed -n 's/^[[:space:]]*"[^"]*":[[:space:]]*//p')"
        value="$(printf '%s\n' "${value}" | sed 's/,[[:space:]]*$//')"
        value="$(trim_spaces "${value}")"
        value="${value#\"}"
        value="${value%\"}"
        [[ "${key}" == "required_ok" ]] && key="script_ok"
        if [[ -n "${key}" ]]; then
          printf '%s=%s\n' "${key}" "${value}"
        fi
        ;;
    esac
  done
}

extract_snapshot_json_field() {
  local json_payload="$1"
  local field_name="$2"
  printf '%s\n' "${json_payload}" | sed -n "s/.*\"${field_name}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

extract_snapshot_log_kv_field() {
  local log_payload="$1"
  local field_name="$2"
  printf '%s\n' "${log_payload}" | sed -n "s/.*${field_name}=\\([^[:space:]]*\\).*/\\1/p" | head -n 1
}

extract_snapshot_log_branch() {
  local log_payload="$1"
  printf '%s\n' "${log_payload}" | sed -n 's/.* branch=\([^[:space:]]*\).*/\1/p' | head -n 1
}

extract_snapshot_log_sha() {
  local log_payload="$1"
  printf '%s\n' "${log_payload}" | sed -n 's/.* sha=\([^[:space:]]*\).*/\1/p' | head -n 1
}

extract_snapshot_log_dirty_count() {
  local log_payload="$1"
  printf '%s\n' "${log_payload}" | sed -n 's/.* dirty=\([0-9][0-9]*\).*/\1/p' | head -n 1
}

resolve_remote_repo_path() {
  local target_host="$1"
  local port="$2"
  local candidate_paths="$3"
  local resolved_path=""

  if ! resolved_path="$(
    run_ssh_command "${target_host}" "${port}" "${candidate_paths}" <<'EOF'
candidate_paths="$1"
selected=""
IFS=',' read -r -a candidates <<< "${candidate_paths}"
for candidate in "${candidates[@]}"; do
  if [ -d "${candidate}/.git" ]; then
    printf '%s\n' "${candidate}"
    exit 0
  fi
done
for candidate in "${candidates[@]}"; do
  if [ -d "${candidate}" ]; then
    printf '%s\n' "${candidate}"
    exit 0
  fi
done
printf '%s\n' "${candidates[0]}"
EOF
  )"; then
    log_line "WARN" "resolve_remote_repo_path timeout/unreachable host ${target_host}:${port}"
  fi

  if [[ -n "${resolved_path}" ]]; then
    printf '%s\n' "${resolved_path}"
  else
    printf '%s\n' "${candidate_paths%%,*}"
  fi
}

snapshot_repo_local() {
  local repo_name="$1"
  local target_host="$2"
  local role="$3"
  local repo_path="$4"
  local required_path="$5"
  local status="ready"
  local branch=""
  local sha=""
  local remote=""
  local dirty_count="0"
  local dirty_sample=""
  local script_ok="no"
  local dirty_output=""

  if [[ ! -d "${repo_path}" ]]; then
    status="blocked"
  elif ! git -C "${repo_path}" rev-parse --git-dir >/dev/null 2>&1; then
    status="blocked"
  else
    sha="$(git -C "${repo_path}" rev-parse HEAD 2>/dev/null || true)"
    branch="$(git -C "${repo_path}" branch --show-current 2>/dev/null || true)"
    remote="$(git -C "${repo_path}" remote get-url origin 2>/dev/null || true)"
    dirty_output="$(git -C "${repo_path}" status --short 2>/dev/null || true)"
    dirty_count="$(printf '%s\n' "${dirty_output}" | sed '/^$/d' | wc -l | tr -d ' ')"
    dirty_sample="$(printf '%s\n' "${dirty_output}" | sed -n '1,3p' | tr '\n' ';' | sed 's/;*$//' | tr '|' '/')"
    if [[ -z "${required_path}" || -e "${repo_path}/${required_path}" ]]; then
      script_ok="yes"
    fi
    if [[ "${script_ok}" != "yes" ]]; then
      status="degraded"
    fi
  fi

  append_result \
    "${repo_name}" "${target_host}" "${role}" "${repo_path}" "${status}" "${branch}" "${sha}" "${remote}" "${dirty_count}" "${dirty_sample}" "${script_ok}"
}

snapshot_repo_remote() {
  local target_host="$1"
  local port="$2"
  local role="$3"
  local repo_name="$4"
  local repo_path_field="$5"
  local required_path="$6"
  local remote_payload_script=""
  local repo_path=""
  local output=""
  local rc=0
  local status=""
  local branch=""
  local sha=""
  local remote=""
  local dirty_count="0"
  local dirty_sample=""
  local script_ok="no"
  local parsed_line=""
  local normalized_output=""
  local key=""
  local value=""
  local parsed_values=0
  local fallback_script=""

  repo_path="${repo_path_field}"
  remote_payload_script="$(cat <<'EOF'
repo_path="$1"
required_path="$2"
repo_status="ready"
branch=""
sha=""
remote=""
dirty_count="0"
dirty_sample=""
script_ok="no"
if [ ! -d "${repo_path}" ]; then
  repo_status="blocked"
elif ! git -C "${repo_path}" rev-parse --git-dir >/dev/null 2>&1; then
  repo_status="blocked"
else
  sha=$(git -C "${repo_path}" rev-parse HEAD 2>/dev/null || true)
  branch=$(git -C "${repo_path}" branch --show-current 2>/dev/null || true)
  remote=$(git -C "${repo_path}" remote get-url origin 2>/dev/null || true)
  dirty_output=$(git -C "${repo_path}" status --short 2>/dev/null || true)
  dirty_count=$(printf '%s\n' "${dirty_output}" | sed '/^$/d' | wc -l | tr -d ' ')
  dirty_sample=$(printf '%s\n' "${dirty_output}" | sed -n '1,3p' | tr '\n' ';' | sed 's/;*$//' | tr '|' '/')
  if [ -z "${required_path}" ] || [ -e "${repo_path}/${required_path}" ]; then
    script_ok="yes"
  fi
if [ "${script_ok}" != "yes" ]; then
  repo_status="degraded"
fi
fi
printf 'status=%s\nbranch=%s\nsha=%s\nremote=%s\ndirty_count=%s\ndirty_sample=%s\nscript_ok=%s\n' \
  "${repo_status}" "${branch}" "${sha}" "${remote}" "${dirty_count}" "${dirty_sample}" "${script_ok}"
EOF
)"
  if ! output="$(run_ssh_command "${target_host}" "${port}" "${repo_path}" "${required_path}" <<< "${remote_payload_script}")"; then
    rc=$?
  fi

  normalized_output="$(printf '%s' "${output}" | tr -d '\r')"
  while IFS='=' read -r key value; do
    key="$(trim_spaces "${key}")"
    value="$(trim_spaces "${value}")"

    case "${key}" in
      status) status="${value}"; parsed_values=$((parsed_values + 1)) ;;
      branch) branch="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      sha) sha="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      remote) remote="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      dirty_count) dirty_count="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      dirty_sample) dirty_sample="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      script_ok) script_ok="${value}" ; parsed_values=$((parsed_values + 1)) ;;
    esac
  done < <(printf '%s\n' "${normalized_output}" | snapshot_kv_lines_from_output)

  if [[ "${parsed_values}" -eq 0 ]]; then
    log_line "INFO" "Remote snapshot retry host=${target_host} repo=${repo_name} mode=generic"
    output=""
    rc=0
    if ! output="$(run_ssh_command "${target_host}" "${port}" "${repo_path}" "${required_path}" <<< "${remote_payload_script}")"; then
      rc=$?
    fi

    normalized_output="$(printf '%s' "${output}" | tr -d '\r')"
    while IFS='=' read -r key value; do
      key="$(trim_spaces "${key}")"
      value="$(trim_spaces "${value}")"

      case "${key}" in
        status) status="${value}"; parsed_values=$((parsed_values + 1)) ;;
        branch) branch="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        sha) sha="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        remote) remote="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        dirty_count) dirty_count="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        dirty_sample) dirty_sample="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        script_ok) script_ok="${value}" ; parsed_values=$((parsed_values + 1)) ;;
      esac
    done < <(printf '%s\n' "${normalized_output}" | snapshot_kv_lines_from_output)
  fi

  if [[ "${parsed_values}" -eq 0 ]]; then
    fallback_script="$(companion_preflight_script_for_repo "${repo_name}" || true)"
    if [[ -n "${fallback_script}" ]]; then
      log_line "INFO" "Remote snapshot fallback host=${target_host} repo=${repo_name} via=${fallback_script}"
      output=""
      rc=0
      if ! output="$(run_ssh_command_direct "${target_host}" "${port}" "${repo_path}" "${fallback_script}" <<'EOF'
repo_path="$1"
fallback_script="$2"

if [ -d "${repo_path}" ] && [ -x "${repo_path}/${fallback_script}" ]; then
  cd "${repo_path}" >/dev/null 2>&1 || exit 1
  "${repo_path}/${fallback_script}" --json 2>/dev/null || exit 1
fi
EOF
      )"; then
        rc=$?
      fi

      normalized_output="$(printf '%s' "${output}" | tr -d '\r')"
      while IFS='=' read -r key value; do
        key="$(trim_spaces "${key}")"
        value="$(trim_spaces "${value}")"

        case "${key}" in
          status) status="${value}"; parsed_values=$((parsed_values + 1)) ;;
          branch) branch="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          sha) sha="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          remote) remote="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          dirty_count) dirty_count="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          dirty_sample) dirty_sample="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          script_ok) script_ok="${value}" ; parsed_values=$((parsed_values + 1)) ;;
        esac
      done < <(printf '%s\n' "${normalized_output}" | snapshot_kv_lines_from_output)

      if [[ "${parsed_values}" -eq 0 ]]; then
        log_line "INFO" "Remote snapshot fallback retry host=${target_host} repo=${repo_name} via=${fallback_script}"
        output=""
        rc=0
        if ! output="$(run_ssh_command_direct "${target_host}" "${port}" "${repo_path}" "${fallback_script}" <<'EOF'
repo_path="$1"
fallback_script="$2"

if [ -d "${repo_path}" ] && [ -x "${repo_path}/${fallback_script}" ]; then
  cd "${repo_path}" >/dev/null 2>&1 || exit 1
  "${repo_path}/${fallback_script}" --json 2>/dev/null || exit 1
fi
EOF
        )"; then
          rc=$?
        fi

        normalized_output="$(printf '%s' "${output}" | tr -d '\r')"
        while IFS='=' read -r key value; do
          key="$(trim_spaces "${key}")"
          value="$(trim_spaces "${value}")"

          case "${key}" in
            status) status="${value}"; parsed_values=$((parsed_values + 1)) ;;
            branch) branch="${value}" ; parsed_values=$((parsed_values + 1)) ;;
            sha) sha="${value}" ; parsed_values=$((parsed_values + 1)) ;;
            remote) remote="${value}" ; parsed_values=$((parsed_values + 1)) ;;
            dirty_count) dirty_count="${value}" ; parsed_values=$((parsed_values + 1)) ;;
            dirty_sample) dirty_sample="${value}" ; parsed_values=$((parsed_values + 1)) ;;
            script_ok) script_ok="${value}" ; parsed_values=$((parsed_values + 1)) ;;
          esac
        done < <(printf '%s\n' "${normalized_output}" | snapshot_kv_lines_from_output)
      fi

      if [[ "${parsed_values}" -eq 0 ]]; then
        log_line "INFO" "Remote snapshot fallback direct-exec host=${target_host} repo=${repo_name} via=${fallback_script}"
        output="$(
          ssh -o BatchMode=yes \
            -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
            -o ServerAliveInterval="${SSH_KEEPALIVE_INTERVAL}" \
            -o ServerAliveCountMax="${SSH_KEEPALIVE_COUNT}" \
            -o StrictHostKeyChecking=accept-new \
            -p "${port}" \
            "${target_host}" \
            "if [ -x \"${repo_path}/${fallback_script}\" ]; then bash \"${repo_path}/${fallback_script}\" --json 2>/dev/null; fi" 2>&1
        )" || rc=$?

        normalized_output="$(printf '%s' "${output}" | tr -d '\r')"
      fi

      if [[ "${parsed_values}" -eq 0 ]]; then
        status="$(extract_snapshot_json_field "${normalized_output}" "status")"
        branch="$(extract_snapshot_json_field "${normalized_output}" "branch")"
        sha="$(extract_snapshot_json_field "${normalized_output}" "sha")"
        remote="$(extract_snapshot_json_field "${normalized_output}" "remote")"
        dirty_count="$(extract_snapshot_json_field "${normalized_output}" "dirty_count")"
        dirty_sample="$(extract_snapshot_json_field "${normalized_output}" "dirty_sample")"
        script_ok="$(extract_snapshot_json_field "${normalized_output}" "script_ok")"
        if [[ -z "${script_ok}" ]]; then
          script_ok="$(extract_snapshot_json_field "${normalized_output}" "required_ok")"
        fi
        if [[ -n "${status}${branch}${sha}${remote}${dirty_count}${dirty_sample}${script_ok}" ]]; then
          parsed_values=7
        fi
      fi

      if [[ "${parsed_values}" -eq 0 ]]; then
        status="$(extract_snapshot_log_kv_field "${normalized_output}" "runtime_mesh_status")"
        if [[ -z "${status}" ]]; then
          status="$(extract_snapshot_log_kv_field "${normalized_output}" "web_mesh_status")"
        fi
        branch="$(extract_snapshot_log_branch "${normalized_output}")"
        sha="$(extract_snapshot_log_sha "${normalized_output}")"
        dirty_count="$(extract_snapshot_log_dirty_count "${normalized_output}")"
        script_ok="$(extract_snapshot_log_kv_field "${normalized_output}" "required_ok")"
        if [[ -z "${script_ok}" ]]; then
          script_ok="$(extract_snapshot_log_kv_field "${normalized_output}" "contract_ok")"
        fi
        if [[ -n "${status}${branch}${sha}${dirty_count}${script_ok}" ]]; then
          parsed_values=7
        fi
      fi
    fi
  fi

  if [[ "${status}" != "ready" && "${status}" != "degraded" && "${status}" != "blocked" ]]; then
    status="degraded"
  fi
  if [[ -z "${status}" ]]; then
    if [[ "${rc}" -ne 0 && -z "${normalized_output}" ]]; then
      status="blocked"
    else
      status="degraded"
    fi
  elif [[ "${status}" == "blocked" && "${parsed_values}" -eq 0 ]]; then
    status="degraded"
  fi
  if [[ "${status}" == "ready" && "${script_ok}" != "yes" ]]; then
    status="degraded"
  fi

  log_line "DEBUG" "Remote snapshot host=${target_host} repo=${repo_name} status=${status} rc=${rc} fields_parsed=${parsed_values}"

  append_result \
    "${repo_name}" "${target_host}" "${role}" "${repo_path}" "${status}" "${branch}" "${sha}" "${remote}" "${dirty_count}" "${dirty_sample}" "${script_ok}"
}

repo_has_entries() {
  local repo_name="$1"
  local entry=""
  for entry in "${RESULTS[@]}"; do
    IFS='|' read -r current_repo _rest <<< "${entry}"
    if [[ "${current_repo}" == "${repo_name}" ]]; then
      return 0
    fi
  done
  return 1
}

repo_convergence_status() {
  local repo_name="$1"
  local entry=""
  local seen=0
  local baseline=""
  local status="ready"

  for entry in "${RESULTS[@]}"; do
    local current_repo=""
    local current_status=""
    local branch=""
    local sha=""
    local remote=""
    local dirty_count=""
    local dirty_sample=""
    local script_ok=""
    IFS='|' read -r current_repo _target _role _path current_status branch sha remote dirty_count dirty_sample script_ok <<< "${entry}"
    [[ "${current_repo}" == "${repo_name}" ]] || continue
    seen=1
    if [[ "${current_status}" == "blocked" ]]; then
      status="blocked"
      break
    fi
    local signature="${current_status}|${branch}|${sha}|${remote}|${dirty_count}|${dirty_sample}|${script_ok}"
    if [[ -z "${baseline}" ]]; then
      baseline="${signature}"
    elif [[ "${signature}" != "${baseline}" ]]; then
      status="degraded"
    fi
  done

  if [[ "${seen}" -eq 0 ]]; then
    status="blocked"
  fi
  printf '%s' "${status}"
}

overall_mesh_status() {
  local repo_name=""
  local repo_status=""
  local overall="ready"
  for repo_name in Kill_LIFE mascarade crazy_life; do
    if ! repo_has_entries "${repo_name}"; then
      continue
    fi
    repo_status="$(repo_convergence_status "${repo_name}")"
    if [[ "${repo_status}" == "blocked" ]]; then
      overall="blocked"
      break
    fi
    if [[ "${repo_status}" == "degraded" ]]; then
      overall="degraded"
    fi
  done
  printf '%s' "${overall}"
}

emit_json() {
  local overall="$1"
  local generated_at
  local repo_name=""
  local entry=""
  local first=1

  generated_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(json_escape "${generated_at}")"
  printf '  "registry_file": "%s",\n' "$(json_escape "${REGISTRY_FILE}")"
  printf '  "registry_status": "%s",\n' "$(json_escape "${REGISTRY_STATUS}")"
  printf '  "load_profile": "%s",\n' "$(json_escape "${LOAD_PROFILE}")"
  printf '  "load_overload_limit": "%s",\n' "$(json_escape "${OVERLOAD_LOAD_RATIO_LIMIT}")"
  printf '  "host_order": [\n'
  first=1
  for host in "${HOST_ORDER[@]}"; do
    if [[ "${first}" -eq 0 ]]; then
      printf ',\n'
    fi
    printf '    "%s"' "$(json_escape "${host}")"
    first=0
  done
  printf '\n  ],\n'
  printf '  "host_profiles": [\n'
  first=1
  for host in "${HOST_ORDER[@]}"; do
    if [[ "${first}" -eq 0 ]]; then
      printf ',\n'
    fi
    printf '    {"id":"%s","target":"%s","role":"%s","placement":"%s","reserve_only":"%s","score":"%s","ratio":"%s","reason":"%s","state":"%s"}' \
      "$(json_escape "${HOST_ID_BY_TARGET["${host}"]:-unknown}")" \
      "$(json_escape "${host}")" \
      "$(json_escape "$(host_role_or_default "${host}" "")")" \
      "$(json_escape "${HOST_PLACEMENT_BY_TARGET["${host}"]:-unknown}")" \
      "$(json_escape "${HOST_RESERVE_ONLY["${host}"]:-false}")" \
      "$(json_escape "${HOST_BASE_SCORE["${host}"]}")" \
      "$(json_escape "${HOST_LOAD_RATIO["${host}"]}")" \
      "$(json_escape "${HOST_LOAD_REASON["${host}"]}")" \
      "$(json_escape "${HOST_CONNECT_STATE["${host}"]}")"
    first=0
  done
  printf '\n  ],\n'
  printf '  "mesh_status": "%s",\n' "$(json_escape "${overall}")"
  printf '  "repo_statuses": [\n'
  first=1
  for repo_name in Kill_LIFE mascarade crazy_life; do
    if ! repo_has_entries "${repo_name}"; then
      continue
    fi
    if [[ "${first}" -eq 0 ]]; then
      printf ',\n'
    fi
    printf '    {"repo":"%s","status":"%s"}' \
      "$(json_escape "${repo_name}")" \
      "$(json_escape "$(repo_convergence_status "${repo_name}")")"
    first=0
  done
  printf '\n  ],\n'
  printf '  "snapshots": [\n'
  first=1
  for entry in "${RESULTS[@]}"; do
    local repo=""
    local target=""
    local role=""
    local path=""
    local status=""
    local branch=""
    local sha=""
    local remote=""
    local dirty_count=""
    local dirty_sample=""
    local script_ok=""
    IFS='|' read -r repo target role path status branch sha remote dirty_count dirty_sample script_ok <<< "${entry}"
    if [[ "${first}" -eq 0 ]]; then
      printf ',\n'
    fi
    printf '    {"repo":"%s","target":"%s","role":"%s","path":"%s","status":"%s","branch":"%s","sha":"%s","remote":"%s","dirty_count":"%s","dirty_sample":"%s","script_ok":"%s"}' \
      "$(json_escape "${repo}")" \
      "$(json_escape "${target}")" \
      "$(json_escape "${role}")" \
      "$(json_escape "${path}")" \
      "$(json_escape "${status}")" \
      "$(json_escape "${branch}")" \
      "$(json_escape "${sha}")" \
      "$(json_escape "${remote}")" \
      "$(json_escape "${dirty_count}")" \
      "$(json_escape "${dirty_sample}")" \
      "$(json_escape "${script_ok}")"
    first=0
  done
  printf '\n  ]\n'
  printf '}\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=1
      ;;
    --no-log)
      LOG_FILE=""
      ;;
    --verbose)
      VERBOSE=1
      ;;
    --load-profile)
      LOAD_PROFILE="${2:-}"
      if [[ -z "${LOAD_PROFILE}" || ! "${LOAD_PROFILE}" =~ ^(tower-first|photon-safe)$ ]]; then
        echo "[error] --load-profile requires tower-first|photon-safe" >&2
        exit 2
      fi
      shift
      ;;
    --photon-safe)
      LOAD_PROFILE="photon-safe"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -n "${LOG_FILE}" ]]; then
  mkdir -p "${LOG_DIR}"
  log_line "INFO" "Log file: ${LOG_FILE}"
fi

load_machine_registry
log_line "INFO" "Machine registry: ${REGISTRY_FILE} status=${REGISTRY_STATUS}"
build_targets
log_line "INFO" "Starting tri-repo mesh sync preflight"
log_line "INFO" "Load profile: ${LOAD_PROFILE}"
build_host_profiles
build_targets_ordered
log_line "INFO" "Load-aware target order:"
for host in "${HOST_ORDER[@]}"; do
  log_line "INFO" "  - ${host}: score=${HOST_BASE_SCORE["${host}"]} ratio=${HOST_LOAD_RATIO["${host}"]} reason=${HOST_LOAD_REASON["${host}"]} state=${HOST_CONNECT_STATE["${host}"]}"
done

for entry in "${TARGETS_ORDERED[@]}"; do
  IFS='|' read -r target_host port role repo_name repo_path required_path <<< "${entry}"
  skip_reason="$(should_skip_entry "${target_host}" "${repo_name}" || true)"
  if [[ -n "${skip_reason}" ]]; then
    log_line "WARN" "Load-aware skip (${skip_reason}): ${repo_name} on ${target_host}"
    append_load_skip_entry "${repo_name}" "${target_host}" "${role}" "${repo_path}" "${skip_reason}"
    continue
  fi
  if [[ "${target_host}" == "local" ]]; then
    snapshot_repo_local "${repo_name}" "${target_host}" "${role}" "${repo_path}" "${required_path}"
  else
    snapshot_repo_remote "${target_host}" "${port}" "${role}" "${repo_name}" "${repo_path}" "${required_path}"
  fi
done

overall_status="blocked"
overall_status="$(overall_mesh_status || printf '%s' "${overall_status}")"
log_line "INFO" "mesh_status=${overall_status}"

for repo_name in Kill_LIFE mascarade crazy_life; do
  if repo_has_entries "${repo_name}"; then
    log_line "INFO" "repo=${repo_name} convergence=$(repo_convergence_status "${repo_name}")"
  fi
done

for entry in "${RESULTS[@]}"; do
  IFS='|' read -r repo_name target_host role repo_path status branch sha remote dirty_count dirty_sample script_ok <<< "${entry}"
  log_line "INFO" "snapshot repo=${repo_name} target=${target_host} status=${status} branch=${branch:-unknown} sha=${sha:-missing} dirty=${dirty_count} script_ok=${script_ok} path=${repo_path}"
done

if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
  emit_json "${overall_status}"
fi

if [[ "${overall_status}" == "blocked" ]]; then
  log_line "WARN" "Mesh sync preflight blocked: operator-controlled sync required"
  exit 1
fi

if [[ "${overall_status}" == "degraded" ]]; then
  log_line "WARN" "Mesh sync preflight degraded: downgrade to controlled lots for affected repos"
else
  log_line "INFO" "Mesh sync preflight ready"
fi

exit 0
