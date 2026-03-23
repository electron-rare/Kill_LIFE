#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

LOG_DIR="${ROOT_DIR}/artifacts/refonte_tui"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/refonte_tui_${TIMESTAMP}.log"
ACTION=""
DAYS_KEEP=14
YES=0
AUTO_PURGE=0
VERBOSE=0
MESH_LOAD_PROFILE="tower-first"

usage() {
  cat <<'EOF_USAGE'
Usage:
  bash tools/cockpit/refonte_tui.sh [options]
  bash tools/cockpit/refonte_tui.sh --action <action> [options]

Options:
  --action <readme|mesh-preflight|ssh-health|mascarade-health|mascarade-logs|mascarade-logs-summary|mascarade-logs-latest|mascarade-logs-list|mascarade-logs-purge|mascarade-incidents|mascarade-incidents-watch|mascarade-incidents-brief|mascarade-incidents-registry|mascarade-incidents-queue|mascarade-incidents-daily|mesh-health|lot-chain|mcp-check|yiacad-fusion|yiacad-fusion:prepare|yiacad-fusion:smoke|yiacad-fusion:status|yiacad-fusion:logs|yiacad-fusion:clean-logs|intelligence|intelligence:audit|intelligence:feature-map|intelligence:spec|intelligence:plan|intelligence:todo|intelligence:research|intelligence:owners|intelligence:logs-summary|intelligence:logs-list|intelligence:logs-latest|intelligence:purge-logs|weekly-summary|daily-align|validate|logs|clean-logs|log-ops|status|all>
      Exécuter un lot directement au lieu d'un menu interactif.
  --days <int>      Nombre de jours pour la rétention de logs (clean-logs). Défaut: 14.
  --mesh-load-profile <tower-first|photon-safe>
                    Profil P2P pour le préflight mesh (tower-first|photon-safe).
  --yes             Accepter les mises à jour écrivant les fichiers de plan.
  --yes-auto        Accepter automatiquement les purges via clean-logs.
  --verbose         Afficher la sortie live des commandes appelées.
  -h, --help        Affiche ce message.

Description:
  Outil TUI textuel pour la refonte Kill_LIFE.
  - loge toutes les exécutions dans artifacts/refonte_tui/
  - lit les artefacts docs/plans/specs
  - supprime les logs en mode contrôlé
  - expose les opérations log_ops (résumé + purge) en mode contrôlé
EOF_USAGE
}

log_event() {
  local level="$1"
  shift
  local msg="$*"
  printf '[%s] %-7s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$level" "$msg" | tee -a "$LOG_FILE"
}

run_and_log() {
  local label="$1"
  shift
  log_event "START" "${label}"

  if [[ "${VERBOSE}" == "1" ]]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local rc="${PIPESTATUS[0]}"
  else
    "$@" >>"$LOG_FILE" 2>&1
    local rc="$?"
  fi

  if [[ "$rc" -eq 0 ]]; then
    log_event "OK" "${label}"
    return 0
  fi
  log_event "FAIL" "${label} (code=$rc)"
  return "$rc"
}

ensure_dirs() {
  mkdir -p "$LOG_DIR"
  [[ -f "$LOG_FILE" ]] || touch "$LOG_FILE"
}

cmd_readme_audit() {
  local args=(bash tools/doc/readme_repo_coherence.sh all)
  if [[ "$YES" -eq 1 ]]; then
    args+=(--yes)
  fi
  run_and_log "Readme coherence + plan sync" "${args[@]}"
}

cmd_mesh_preflight() {
  local args=(
    bash tools/cockpit/mesh_sync_preflight.sh --json --load-profile "${MESH_LOAD_PROFILE}"
  )
  run_and_log "Tri-repo mesh sync preflight" "${args[@]}"
}

cmd_ssh_health() {
  local args=(
    bash tools/cockpit/ssh_healthcheck.sh --json
  )
  run_and_log "SSH operator health-check" "${args[@]}"
}

cmd_mascarade_health() {
  local args=(
    bash tools/cockpit/mascarade_runtime_health.sh --json
  )
  run_and_log "Mascarade/Ollama runtime health-check" "${args[@]}"
}

cmd_mascarade_logs() {
  local logs_action="${1:-summary}"
  local args=(
    bash tools/cockpit/full_operator_lane.sh logs --json --logs-action "${logs_action}"
  )
  run_and_log "Mascarade/Ollama operator lane logs (${logs_action})" "${args[@]}"
}

cmd_mascarade_incidents() {
  local incidents_action="${1:-summary}"
  local args=(
    bash tools/cockpit/mascarade_incidents_tui.sh --action "${incidents_action}" --lines 18
  )
  run_and_log "Mascarade incidents view (${incidents_action})" "${args[@]}"
}

cmd_lot_chain() {
  local args=(bash tools/cockpit/lot_chain.sh all)
  if [[ "$YES" -eq 1 ]]; then
    args+=(--yes)
  fi
  run_and_log "Autonomous lot chain + plans" "${args[@]}"
}

cmd_yiacad_fusion() {
  local yiacad_action="prepare"
  if [[ "${ACTION}" == yiacad-fusion:* ]]; then
    yiacad_action="${ACTION#yiacad-fusion:}"
  fi

  if [[ "${ACTION}" == "yiacad-fusion" ]]; then
    yiacad_action="prepare"
  fi

  case "${yiacad_action}" in
    prepare|smoke|status|logs|clean-logs)
      ;;
    *)
      echo "Action YiACAD inconnue: ${yiacad_action}" >&2
      echo "Actions valides: prepare|smoke|status|logs|clean-logs" >&2
      return 1
      ;;
  esac

  local args=(bash tools/cad/yiacad_fusion_lot.sh --action "${yiacad_action}")
  if [[ "${yiacad_action}" == "clean-logs" ]]; then
    args+=(--days "${DAYS_KEEP}")
  fi
  if [[ "$YES" -eq 1 ]]; then
    args+=(--yes)
  fi
  run_and_log "YiACAD lot (${yiacad_action})" "${args[@]}"
}

cmd_weekly_summary() {
  local args=(bash tools/cockpit/render_weekly_refonte_summary.sh)
  run_and_log "Weekly refonte summary" "${args[@]}"
}

cmd_mcp_check() {
  local args=(
    bash tools/run_autonomous_next_lots.sh status
  )
  run_and_log "Autonomous lot status" "${args[@]}"
}

cmd_daily_align() {
  local args=(bash tools/cockpit/run_alignment_daily.sh --json --mesh-load-profile "${MESH_LOAD_PROFILE}")
  run_and_log "Daily alignment + repo refresh" "${args[@]}"
}

cmd_validate() {
  local args=(
    bash tools/test_python.sh --suite stable
  )
  run_and_log "Python stable suite" "${args[@]}"
}

cmd_log_ops() {
  local args=(
    bash tools/cockpit/log_ops.sh --action summary --json
  )
  run_and_log "Log ops summary" "${args[@]}"
}

cmd_mesh_health() {
  local args=(
    bash tools/cockpit/mesh_health_check.sh --json --load-profile "${MESH_LOAD_PROFILE}"
  )
  run_and_log "Mesh health reconcile" "${args[@]}"
}

cmd_intelligence_program() {
  local intelligence_action="status"

  if [[ "${ACTION}" == intelligence:* ]]; then
    intelligence_action="${ACTION#intelligence:}"
  fi

  local args=(
    bash tools/cockpit/intelligence_tui.sh --action "${intelligence_action}"
  )
  run_and_log "Intelligence program (${intelligence_action})" "${args[@]}"
}

list_logs() {
  echo "=== Logs disponibles (refonte_tui) ==="
  if ! ls -1 "$LOG_DIR"/*.log 2>/dev/null | head -n 20; then
    echo "Aucun fichier log trouvé dans $LOG_DIR"
    return 0
  fi
}

collect_refonte_logs_by_mtime_desc() {
  local path
  local epoch
  while IFS= read -r -d '' path; do
    if epoch="$(stat -c '%Y' "$path" 2>/dev/null)"; then
      : # GNU coreutils
    elif epoch="$(stat -f '%m' "$path" 2>/dev/null)"; then
      : # BSD/macOS
    else
      epoch="0"
    fi
    printf '%s %s\n' "$epoch" "$path"
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -print0)
}

analyze_logs() {
  echo "=== Analyse rapide des 20 logs les plus récents ==="
  list_logs
  echo
  collect_refonte_logs_by_mtime_desc | sort -nr | head -n 20 | awk '{print $2}' | while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local_fail="$(grep -cE "FAIL|ERROR|KO|blocked|syntax fail|timeout" "$file" 2>/dev/null || true)"
    local_lines="$(wc -l < "$file")"
    local_name="$(basename "$file")"
    printf '%s | lines=%s | fails=%s\n' "$local_name" "$local_lines" "$local_fail"
  done
  echo
  echo "Dernier log (tail 30):"
  local last_file
  last_file="$(collect_refonte_logs_by_mtime_desc | sort -nr | head -n 1 | awk '{print $2}')"
  if [[ -n "$last_file" ]]; then
    tail -n 30 "$last_file"
  else
    echo "Aucun log trouvé."
  fi
}

cmd_logs_report() {
  list_logs
  echo
  analyze_logs
  cmd_log_ops
}

clean_logs() {
  local cutoff_days="${1:-$DAYS_KEEP}"
  ensure_dirs
  local target=$((cutoff_days))
  if [[ "$target" -lt 1 ]]; then
    echo "days doit être >= 1."
    return 1
  fi

  local count=0
  while IFS= read -r file; do
    rm -f "$file"
    ((count += 1))
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -mtime +"$target")

  log_event "INFO" "Logs anciens supprimés (>${target}j): $count"
  echo "Logs supprimés: $count"
  cmd_log_ops
}

show_status() {
  echo "=== Statuts et repères rapides ==="
  echo "- Contrat mesh: docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md"
  echo "- Plan principal: specs/03_plan.md (section AUTO LOT-CHAIN PLAN)"
  echo "- Tâches: specs/04_tasks.md"
  echo "- Plan d'agents: docs/plans/12_plan_gestion_des_agents.md"
  echo "- Lot chain: tools/autonomous_next_lots.py, tools/cockpit/lot_chain.sh"
  echo "- Continuité kill_life JSON: artifacts/cockpit/kill_life_memory/latest.json"
  echo "- Continuité kill_life Markdown: artifacts/cockpit/kill_life_memory/latest.md"
  echo "- Handoff quotidien: artifacts/cockpit/daily_operator_summary_latest.md"
  echo "- Handoff produit JSON: artifacts/cockpit/product_contract_handoff/latest.json"
  echo "- Handoff produit Markdown: artifacts/cockpit/product_contract_handoff/latest.md"
  echo "- Lot YiACAD: tools/cad/yiacad_fusion_lot.sh (prepare/smoke/status/logs)"
  echo "- Préflight mesh: tools/cockpit/mesh_sync_preflight.sh"
  echo "- Health consolidate: tools/cockpit/mesh_health_check.sh"
  echo "- Santé SSH: tools/cockpit/ssh_healthcheck.sh"
  echo "- Santé Mascarade: tools/cockpit/mascarade_runtime_health.sh"
  echo "- Logs Mascarade: tools/cockpit/mascarade_logs_tui.sh"
  echo "- Incidents Mascarade: tools/cockpit/mascarade_incidents_tui.sh"
  echo "- MCP setup: docs/MCP_SETUP.md"
  echo "- Manifeste: docs/REFACTOR_MANIFEST_2026-03-20.md"
  echo "- Web research: docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md"
  echo "- Intelligence spec: specs/agentic_intelligence_integration_spec.md"
  echo "- Intelligence TUI: tools/cockpit/intelligence_tui.sh"
  echo "- Log ops: tools/cockpit/log_ops.sh"
  echo "- Cad fusion logs: artifacts/cad-fusion"
  echo "- Weekly summary: artifacts/cockpit/weekly_refonte_summary.md"
}

run_all() {
  cmd_mesh_preflight
  cmd_ssh_health
  cmd_mascarade_health
  cmd_mascarade_logs
  cmd_readme_audit
  cmd_lot_chain
  cmd_mcp_check
  cmd_validate
  cmd_log_ops
  cmd_weekly_summary
}

menu() {
  while true; do
    echo
    echo "== Refonte TUI Kill_LIFE =="
    echo "1) Préflight mesh tri-repo"
    echo "2) Santé SSH opérateur"
    echo "3) Santé Mascarade/Ollama"
    echo "4) Audit README + plans"
    echo "5) Executer chain autonome (lot_chain)"
    echo "6) Status lot détectés (autonomous)"
    echo "7) Tests stables (python suite)"
    echo "8) Vérification quotidienne (alignment)"
  echo "9) Voir logs récents"
  echo "10) Analyser logs (échecs + tail)"
  echo "11) Statut repère"
  echo "12) Résumé LogOps"
  echo "13) Vérification santé consolidée (mesh/readme/logs)"
  echo "14) Purger logs anciens (${DAYS_KEEP}j)"
  echo "15) Lot YiACAD (prepare/smoke/status/logs/clean-logs)"
  echo "16) Synthèse hebdomadaire refonte"
  echo "17) Logs Mascarade/Ollama (summary)"
  echo "18) Logs Mascarade/Ollama (latest)"
  echo "19) Logs Mascarade/Ollama (list)"
  echo "20) Logs Mascarade/Ollama (purge)"
  echo "21) Incidents Mascarade (summary)"
  echo "22) Incidents Mascarade (watch)"
  echo "23) Incidents Mascarade (brief)"
  echo "24) Incidents Mascarade (registry)"
  echo "25) Incidents Mascarade (queue)"
    echo "26) Incidents Mascarade (daily)"
    echo "27) Intelligence program (status)"
    echo "28) Intelligence program (plan)"
    echo "29) Intelligence program (todo)"
    echo "30) Intelligence program (research)"
    echo "0) Quitter"
    echo -n "Choix: "
    read -r choice

    case "${choice}" in
      1)
        cmd_mesh_preflight
        ;;
      2)
        cmd_ssh_health
        ;;
      3)
        cmd_mascarade_health
        ;;
      4)
        cmd_readme_audit
        ;;
      5)
        cmd_lot_chain
        ;;
      6)
        cmd_mcp_check
        ;;
      7)
        cmd_validate
        ;;
      8)
        cmd_daily_align
        ;;
      9)
        list_logs
        ;;
      10)
        cmd_logs_report
        ;;
      11)
        show_status
        ;;
      12)
        cmd_log_ops
        ;;
      13)
        cmd_mesh_health
        ;;
      14)
        if [[ "$AUTO_PURGE" -eq 1 ]]; then
          clean_logs "$DAYS_KEEP"
        else
          echo "Confirmer la suppression des logs > ${DAYS_KEEP} jours ? [y/N]"
          read -r confirm
          if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
            clean_logs "$DAYS_KEEP"
          else
            echo "Annulé."
          fi
        fi
        ;;
      15)
        cmd_yiacad_fusion
        ;;
      16)
        cmd_weekly_summary
        ;;
      17)
        cmd_mascarade_logs summary
        ;;
      18)
        cmd_mascarade_logs latest
        ;;
      19)
        cmd_mascarade_logs list
        ;;
      20)
        cmd_mascarade_logs purge
        ;;
      21)
        cmd_mascarade_incidents summary
        ;;
      22)
        cmd_mascarade_incidents watch
        ;;
      23)
        cmd_mascarade_incidents brief
        ;;
      24)
        cmd_mascarade_incidents registry
        ;;
      25)
        cmd_mascarade_incidents queue
        ;;
      26)
        cmd_mascarade_incidents daily
        ;;
      27)
        ACTION="intelligence"
        cmd_intelligence_program
        ;;
      28)
        ACTION="intelligence:plan"
        cmd_intelligence_program
        ;;
      29)
        ACTION="intelligence:todo"
        cmd_intelligence_program
        ;;
      30)
        ACTION="intelligence:research"
        cmd_intelligence_program
        ;;
      0)
        echo "Sortie."
        break
        ;;
      *)
        echo "Choix invalide: ${choice}"
        ;;
    esac
  done
}

main() {
  ensure_dirs
  log_event "INFO" "refonte_tui start action=${ACTION:-interactive} yes=${YES} verbose=${VERBOSE}"

  case "${ACTION}" in
    readme)
      cmd_readme_audit
      ;;
    "mesh-preflight")
      cmd_mesh_preflight
      ;;
    "ssh-health")
      cmd_ssh_health
      ;;
    "mascarade-health")
      cmd_mascarade_health
      ;;
    "mascarade-logs")
      cmd_mascarade_logs summary
      ;;
    "mascarade-logs-summary")
      cmd_mascarade_logs summary
      ;;
    "mascarade-logs-latest")
      cmd_mascarade_logs latest
      ;;
    "mascarade-logs-list")
      cmd_mascarade_logs list
      ;;
    "mascarade-logs-purge")
      cmd_mascarade_logs purge
      ;;
    "mascarade-incidents")
      cmd_mascarade_incidents summary
      ;;
    "mascarade-incidents-watch")
      cmd_mascarade_incidents watch
      ;;
    "mascarade-incidents-brief")
      cmd_mascarade_incidents brief
      ;;
    "mascarade-incidents-registry")
      cmd_mascarade_incidents registry
      ;;
    "mascarade-incidents-queue")
      cmd_mascarade_incidents queue
      ;;
    "mascarade-incidents-daily")
      cmd_mascarade_incidents daily
      ;;
    "lot-chain")
      cmd_lot_chain
      ;;
    "mcp-check")
      cmd_mcp_check
      ;;
    daily-align)
      cmd_daily_align
      ;;
    validate)
      cmd_validate
      ;;
    logs)
      cmd_logs_report
      ;;
    "clean-logs")
      if [[ "$AUTO_PURGE" -ne 1 ]]; then
        echo "Refus de purger sans --yes-auto pour l'action non interactive clean-logs." >&2
        echo "Relancer avec: bash tools/cockpit/refonte_tui.sh --action clean-logs --days ${DAYS_KEEP} --yes-auto" >&2
        exit 2
      fi
      clean_logs "$DAYS_KEEP"
      ;;
    "log-ops")
      cmd_log_ops
      ;;
    yiacad-fusion|yiacad-fusion:*)
      cmd_yiacad_fusion
      ;;
    intelligence|intelligence:*)
      cmd_intelligence_program
      ;;
    "weekly-summary")
      cmd_weekly_summary
      ;;
    "mesh-health")
      cmd_mesh_health
      ;;
    status)
      show_status
      ;;
    all)
      run_all
      ;;
    "")
      menu
      ;;
    *)
      echo "Action inconnue: ${ACTION}"
      usage
      exit 1
      ;;
  esac

  log_event "INFO" "refonte_tui end"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      if [[ $# -lt 2 ]]; then
        echo "--action nécessite une valeur." >&2
        exit 1
      fi
      ACTION="$2"
      shift 2
      ;;
    --days)
      if [[ $# -lt 2 ]]; then
        echo "--days nécessite une valeur." >&2
        exit 1
      fi
      DAYS_KEEP="$2"
      shift 2
      ;;
    --mesh-load-profile)
      if [[ $# -lt 2 ]]; then
        echo "--mesh-load-profile nécessite une valeur." >&2
        exit 1
      fi
      MESH_LOAD_PROFILE="$2"
      if [[ ! "${MESH_LOAD_PROFILE}" =~ ^(tower-first|photon-safe)$ ]]; then
        echo "Profil invalide: ${MESH_LOAD_PROFILE}. Valeurs: tower-first|photon-safe" >&2
        exit 2
      fi
      shift 2
      ;;
    --yes)
      YES=1
      shift
      ;;
    --yes-auto)
      YES=1
      AUTO_PURGE=1
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
      echo "Option inconnue: $1" >&2
      usage
      exit 1
      ;;
  esac
 done

main "$@"
