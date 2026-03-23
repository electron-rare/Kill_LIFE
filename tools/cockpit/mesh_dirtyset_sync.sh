#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${ROOT_DIR}/artifacts/cockpit"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/mesh_dirtyset_sync_$(date '+%Y%m%d_%H%M%S').log"

MODE="apply"
JSON=0

KILL_LIFE_SRC="/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/Kill_LIFE-main"
MASCARADE_SRC="/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main"
CRAZY_SRC="/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/crazy_life-main"

TARGETS=(
  "clems@192.168.0.120|/home/clems/Kill_LIFE-main|/home/clems/mascarade-main|/home/clems/crazy_life-main"
  "kxkm@kxkm-ai|/home/kxkm/Kill_LIFE-main|/home/kxkm/mascarade-main|/home/kxkm/crazy_life-main"
  "root@192.168.0.119|/root/Kill_LIFE-main|/root/mascarade-main|/root/crazy_life-main"
  "cils@100.126.225.111|/Users/cils/Kill_LIFE-main|/Users/cils/mascarade-main|/Users/cils/crazy_life-main"
)

log_line() {
  local level="$1"
  shift
  local msg="${level} $(date '+%Y-%m-%d %H:%M:%S %z') ${*}"
  printf '%s\n' "${msg}" | tee -a "${LOG_FILE}" >&2
}

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/mesh_dirtyset_sync.sh [--dry-run] [--json]

Synchronise uniquement les fichiers dirty des lanes mesh locales vers les lanes distantes,
et purge les artefacts Apple (`._*`, `.DS_Store`) qui polluent les dirty-sets.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

should_skip_path() {
  local rel="$1"
  case "${rel}" in
    .DS_Store|*/.DS_Store|._*|*/._*|artifacts/cockpit/*.log|artifacts/cockpit/*.json)
      return 0
      ;;
  esac
  return 1
}

collect_sync_list() {
  local repo_root="$1"
  local out_file="$2"
  : > "${out_file}"

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    should_skip_path "${rel}" && continue
    printf '%s\n' "${rel}" >> "${out_file}"
  done < <(git -C "${repo_root}" ls-files -m -o --exclude-standard)
}

collect_delete_list() {
  local repo_root="$1"
  local out_file="$2"
  : > "${out_file}"

  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    should_skip_path "${rel}" && continue
    printf '%s\n' "${rel}" >> "${out_file}"
  done < <(git -C "${repo_root}" ls-files -d)
}

clean_local_apple_junk() {
  local repo_root="$1"
  find "${repo_root}" \( -name '._*' -o -name '.DS_Store' \) -type f -delete 2>/dev/null || true
}

clean_remote_apple_junk() {
  local host="$1"
  local repo_root="$2"
  ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
    "find '${repo_root}' \\( -name '._*' -o -name '.DS_Store' \\) -type f -delete 2>/dev/null || true" >/dev/null
}

sync_repo_dirtyset() {
  local repo_name="$1"
  local src_root="$2"
  local host="$3"
  local dst_root="$4"
  local sync_list delete_list sync_count delete_count

  sync_list="$(mktemp)"
  delete_list="$(mktemp)"
  collect_sync_list "${src_root}" "${sync_list}"
  collect_delete_list "${src_root}" "${delete_list}"
  clean_local_apple_junk "${src_root}"

  sync_count="$(wc -l < "${sync_list}" | tr -d ' ')"
  delete_count="$(wc -l < "${delete_list}" | tr -d ' ')"

  log_line "INFO" "repo=${repo_name} target=${host} sync=${sync_count} delete=${delete_count} mode=${MODE}"

  if [[ "${MODE}" == "apply" ]]; then
    clean_remote_apple_junk "${host}" "${dst_root}"

    if [[ "${sync_count}" != "0" ]]; then
      tar -C "${src_root}" -cf - -T "${sync_list}" | \
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
          "mkdir -p '${dst_root}' && tar -C '${dst_root}' -xf -" >/dev/null
    fi

    if [[ "${delete_count}" != "0" ]]; then
      while IFS= read -r rel; do
        [[ -n "${rel}" ]] || continue
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" \
          "rm -f '${dst_root}/${rel}'" >/dev/null
      done < "${delete_list}"
    fi

    clean_remote_apple_junk "${host}" "${dst_root}"
  fi

  rm -f "${sync_list}" "${delete_list}"
}

for target in "${TARGETS[@]}"; do
  IFS='|' read -r host kill_dst masc_dst crazy_dst <<< "${target}"
  sync_repo_dirtyset "Kill_LIFE" "${KILL_LIFE_SRC}" "${host}" "${kill_dst}"
  sync_repo_dirtyset "mascarade" "${MASCARADE_SRC}" "${host}" "${masc_dst}"
  sync_repo_dirtyset "crazy_life" "${CRAZY_SRC}" "${host}" "${crazy_dst}"
done

if [[ "${JSON}" -eq 1 ]]; then
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf '  "mode": "%s",\n' "${MODE}"
  printf '  "targets": %s,\n' "${#TARGETS[@]}"
  printf '  "log_file": "%s"\n' "${LOG_FILE}"
  printf '}\n'
else
  log_line "INFO" "Dirty-set sync complete"
fi
