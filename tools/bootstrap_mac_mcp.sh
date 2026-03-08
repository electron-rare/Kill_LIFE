#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-codex}"

KILL_LIFE_DIR="$REPO_DIR"
MASCARADE_DIR="${MASCARADE_DIR:-$(cd "$REPO_DIR/../mascarade" 2>/dev/null && pwd || true)}"
CODEX_BIN="${CODEX_BIN:-codex}"
INCLUDE_PLAYWRIGHT=1
APPLY=0

usage() {
  cat <<'EOF'
Usage:
  bash tools/bootstrap_mac_mcp.sh codex [--apply] [--kill-life-dir DIR] [--mascarade-dir DIR] [--without-playwright]
  bash tools/bootstrap_mac_mcp.sh json  [--kill-life-dir DIR] [--mascarade-dir DIR] [--without-playwright]

Modes:
  codex   Print Codex MCP registration commands. Use --apply on the target Mac to execute them.
  json    Print a generic mcpServers JSON config with absolute paths.

Notes:
  - The target Mac should clone Kill_LIFE and the companion mascarade repo side by side.
  - Playwright MCP uses the official package `@playwright/mcp@latest`.
  - For Codex, this script relies on `codex mcp add`.
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

emit_json() {
  cat <<EOF
{
  "mcpServers": {
    "kicad": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/hw/run_kicad_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    },
    "validate-specs": {
      "type": "local",
      "command": "python3",
      "args": ["$KILL_LIFE_DIR/tools/validate_specs.py", "--mcp"],
      "tools": ["*"]
    },
    "knowledge-base": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_knowledge_base_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    },
    "github-dispatch": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_github_dispatch_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    },
    "freecad": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_freecad_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    },
    "openscad": {
      "type": "local",
      "command": "bash",
      "args": ["$KILL_LIFE_DIR/tools/run_openscad_mcp.sh"],
      "env": {
        "MASCARADE_DIR": "$MASCARADE_DIR"
      },
      "tools": ["*"]
    },
    "huggingface": {
      "type": "url",
      "url": "https://huggingface.co/mcp",
      "headers": {
        "Authorization": "Bearer \${HUGGINGFACE_API_KEY}"
      }
    }$(if [[ $INCLUDE_PLAYWRIGHT -eq 1 ]]; then cat <<'JSON'
,
    "playwright": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "tools": ["*"]
    }
JSON
fi)
  }
}
EOF
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
  codex_add kicad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/hw/run_kicad_mcp.sh"
  codex_add validate-specs -- python3 "$KILL_LIFE_DIR/tools/validate_specs.py" --mcp
  codex_add knowledge-base --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_knowledge_base_mcp.sh"
  codex_add github-dispatch --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_github_dispatch_mcp.sh"
  codex_add freecad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_freecad_mcp.sh"
  codex_add openscad --env "MASCARADE_DIR=$MASCARADE_DIR" -- bash "$KILL_LIFE_DIR/tools/run_openscad_mcp.sh"
  codex_add huggingface --url "https://huggingface.co/mcp" --bearer-token-env-var "HUGGINGFACE_API_KEY"
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
