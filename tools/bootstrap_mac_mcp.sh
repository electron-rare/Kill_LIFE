#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-codex}"

KILL_LIFE_DIR="$REPO_DIR"
CODEX_BIN="${CODEX_BIN:-codex}"
INCLUDE_PLAYWRIGHT=1
INCLUDE_KICAD="auto"
INCLUDE_HUGGINGFACE="auto"
APPLY=0

source "$REPO_DIR/tools/lib/runtime_home.sh"

usage() {
  cat <<'EOF'
Usage:
  bash tools/bootstrap_mac_mcp.sh codex [--apply] [--kill-life-dir DIR] [--mascarade-dir DIR] [--without-playwright] [--with-kicad|--without-kicad] [--with-huggingface|--without-huggingface]
  bash tools/bootstrap_mac_mcp.sh json  [--kill-life-dir DIR] [--mascarade-dir DIR] [--without-playwright] [--with-kicad|--without-kicad] [--with-huggingface|--without-huggingface]

Modes:
  codex   Print Codex MCP registration commands. Use --apply on the target Mac to execute them.
  json    Print a generic mcpServers JSON config with absolute paths.

Notes:
  - The target Mac should clone Kill_LIFE and the companion mascarade repo side by side.
  - Playwright MCP uses the official package `@playwright/mcp@latest`.
  - For Codex, this script relies on `codex mcp add`.
  - By default, `kicad` is included only when `mascarade/finetune/kicad_mcp_server` is populated.
  - By default, `huggingface` is included only when `HUGGINGFACE_API_KEY` is already set.
EOF
}

abs_path() {
  local input="$1"
  (cd "$input" >/dev/null 2>&1 && pwd)
}

quote_cmd() {
  local first=1
  for arg in "$@"; do
    if [[ $first -eq 0 ]]; then
      printf ' '
    fi
    printf '%q' "$arg"
    first=0
  done
  printf '\n'
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

kicad_server_dir() {
  printf '%s' "$MASCARADE_DIR/finetune/kicad_mcp_server"
}

has_kicad_server_source() {
  local server_dir
  server_dir="$(kicad_server_dir)"
  [[ -f "$server_dir/package.json" || -f "$server_dir/dist/index.js" ]]
}

has_kicad_seeed_runtime() {
  command -v uvx >/dev/null 2>&1
}

resolve_kicad_launcher() {
  if has_kicad_server_source; then
    printf '%s' "$KILL_LIFE_DIR/tools/hw/run_kicad_mcp.sh"
    return 0
  fi
  if has_kicad_seeed_runtime; then
    printf '%s' "$KILL_LIFE_DIR/tools/hw/run_kicad_seeed_mcp.sh"
    return 0
  fi
  return 1
}

explain_kicad_skip() {
  if has_kicad_server_source; then
    return 0
  fi
  if has_kicad_seeed_runtime; then
    return 0
  fi
  printf 'missing %s/package.json, %s/dist/index.js, and no uvx on PATH' "$(kicad_server_dir)" "$(kicad_server_dir)"
}

should_include_kicad() {
  case "${INCLUDE_KICAD:-auto}" in
    auto)
      has_kicad_server_source || has_kicad_seeed_runtime
      ;;
    *)
      is_truthy "$INCLUDE_KICAD"
      ;;
  esac
}

should_include_huggingface() {
  case "${INCLUDE_HUGGINGFACE:-auto}" in
    auto)
      [[ -n "${HUGGINGFACE_API_KEY:-}" ]]
      ;;
    *)
      is_truthy "$INCLUDE_HUGGINGFACE"
      ;;
  esac
}

warn_skip() {
  printf '[bootstrap_mac_mcp] skipping %s: %s\n' "$1" "$2" >&2
}

emit_json() {
  local -a blocks=()
  local kicad_launcher=""

  if should_include_kicad; then
    kicad_launcher="$(resolve_kicad_launcher)"
    blocks+=("$(cat <<EOF
    "kicad": {
      "type": "local",
      "command": "bash",
      "args": ["$kicad_launcher"],
      "tools": ["*"]
    }
EOF
)")
  else
    warn_skip "kicad" "$(explain_kicad_skip)"
  fi

  blocks+=("$(cat <<EOF
    "validate-specs": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_validate_specs_mcp.sh"],
      "tools": ["*"]
    }
EOF
)")

  blocks+=("$(cat <<EOF
    "knowledge-base": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_knowledge_base_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    }
EOF
)")

  blocks+=("$(cat <<EOF
    "github-dispatch": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_github_dispatch_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    }
EOF
)")

  blocks+=("$(cat <<EOF
    "freecad": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_freecad_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    }
EOF
)")

  blocks+=("$(cat <<EOF
    "openscad": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_openscad_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    }
EOF
)")

  if should_include_huggingface; then
    blocks+=("$(cat <<'EOF'
    "huggingface": {
      "type": "url",
      "url": "https://huggingface.co/mcp",
      "headers": {
        "Authorization": "Bearer ${HUGGINGFACE_API_KEY}"
      }
    }
EOF
)")
  else
    warn_skip "huggingface" "HUGGINGFACE_API_KEY is not set"
  fi

  if [[ $INCLUDE_PLAYWRIGHT -eq 1 ]]; then
    blocks+=("$(cat <<'EOF'
    "playwright": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "tools": ["*"]
    }
EOF
)")
  fi

  printf '{\n'
  printf '  "mcpServers": {\n'
  local i
  for ((i = 0; i < ${#blocks[@]}; i++)); do
    if (( i > 0 )); then
      printf ',\n'
    fi
    printf '%s' "${blocks[$i]}"
  done
  printf '\n'
  printf '  }\n'
  printf '}\n'
}

codex_add() {
  local name="$1"
  shift
  local -a cmd=("$CODEX_BIN" mcp add "$name")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env)
        cmd+=("--env" "$2")
        shift 2
        ;;
      --url)
        cmd+=("--url" "$2")
        shift 2
        ;;
      --bearer-token-env-var)
        cmd+=("--bearer-token-env-var" "$2")
        shift 2
        ;;
      --)
        cmd+=("--")
        shift
        while [[ $# -gt 0 ]]; do
          cmd+=("$1")
          shift
        done
        ;;
      *)
        echo "Unknown codex_add arg: $1" >&2
        exit 1
        ;;
    esac
  done
  if [[ $APPLY -eq 1 ]]; then
    "${cmd[@]}"
  else
    quote_cmd "${cmd[@]}"
  fi
}

emit_codex() {
  local kicad_launcher=""
  if should_include_kicad; then
    kicad_launcher="$(resolve_kicad_launcher)"
    if [[ "$kicad_launcher" == *"/run_kicad_mcp.sh" ]]; then
      codex_add kicad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$kicad_launcher"
    else
      codex_add kicad -- bash "$kicad_launcher"
    fi
  else
    warn_skip "kicad" "$(explain_kicad_skip)"
  fi
  codex_add validate-specs -- bash "$KILL_LIFE_DIR/tools/run_validate_specs_mcp.sh"
  codex_add knowledge-base --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_knowledge_base_mcp.sh"
  codex_add github-dispatch --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_github_dispatch_mcp.sh"
  codex_add freecad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_freecad_mcp.sh"
  codex_add openscad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_openscad_mcp.sh"
  if should_include_huggingface; then
    codex_add huggingface --url "https://huggingface.co/mcp" --bearer-token-env-var "HUGGINGFACE_API_KEY"
  else
    warn_skip "huggingface" "HUGGINGFACE_API_KEY is not set"
  fi
  if [[ $INCLUDE_PLAYWRIGHT -eq 1 ]]; then
    codex_add playwright -- npx -y "@playwright/mcp@latest"
  fi
}

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kill-life-dir)
      KILL_LIFE_DIR="$(abs_path "$2")"
      shift 2
      ;;
    --mascarade-dir)
      MASCARADE_DIR="$(abs_path "$2")"
      shift 2
      ;;
    --without-playwright)
      INCLUDE_PLAYWRIGHT=0
      shift
      ;;
    --with-kicad)
      INCLUDE_KICAD=1
      shift
      ;;
    --without-kicad)
      INCLUDE_KICAD=0
      shift
      ;;
    --with-huggingface)
      INCLUDE_HUGGINGFACE=1
      shift
      ;;
    --without-huggingface)
      INCLUDE_HUGGINGFACE=0
      shift
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "$KILL_LIFE_DIR" ]] || { echo "Unable to resolve Kill_LIFE path" >&2; exit 1; }
if [[ -z "${MASCARADE_DIR:-}" ]]; then
  MASCARADE_DIR="$(
    kill_life_resolve_mascarade_dir \
      "$REPO_DIR" \
      "core/mascarade" \
      "finetune"
  )"
fi
[[ -n "$MASCARADE_DIR" ]] || { echo "Unable to resolve mascarade companion path" >&2; exit 1; }

case "$MODE" in
  codex)
    emit_codex
    ;;
  json)
    emit_json
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
