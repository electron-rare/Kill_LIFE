#!/usr/bin/env bash

json_contract_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_contract_append_string() {
  local current="$1"
  local value="$2"
  local escaped=""
  escaped="$(json_contract_escape "${value}")"
  if [[ -z "${current}" ]]; then
    printf '"%s"' "${escaped}"
  else
    printf '%s,"%s"' "${current}" "${escaped}"
  fi
}

json_contract_array_from_args() {
  local payload=""
  local value=""
  for value in "$@"; do
    [[ -n "${value}" ]] || continue
    payload="$(json_contract_append_string "${payload}" "${value}")"
  done
  printf '[%s]' "${payload}"
}

json_contract_map_status() {
  case "${1:-unknown}" in
    ok|done|ready|success)
      printf 'ok'
      ;;
    degraded|warn|warning|no-op|pending|running|skipped|unknown)
      printf 'degraded'
      ;;
    blocked|ko|error|fail|failed|cancelled|cancel_unresolved)
      printf 'error'
      ;;
    *)
      printf 'degraded'
      ;;
  esac
}
