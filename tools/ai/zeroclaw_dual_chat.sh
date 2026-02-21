#!/usr/bin/env bash
set -euo pipefail

load_local_env() {
  local env_file="${ZEROCLAW_ENV_FILE:-$HOME/.zeroclaw/env}"
  [[ -f "$env_file" ]] || return 0
  chmod 600 "$env_file" >/dev/null 2>&1 || true
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

load_local_env

ZEROCLAW_BIN="${ZEROCLAW_BIN:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/zeroclaw/target/release/zeroclaw}"
RTC_REPO="/Users/cils/Documents/Lelectron_rare/RTC_BL_PHONE"
ZACUS_REPO="/Users/cils/Documents/Lelectron_rare/le-mystere-professeur-zacus"

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") <rtc|zacus|path> -m "message"
  $(basename "$0") <rtc|zacus|path> --interactive
  $(basename "$0") <rtc|zacus|path> --hardware
  $(basename "$0") <rtc|zacus|path> --provider-check
  $(basename "$0") <rtc|zacus|path> --cheap -m "message"
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

target="$1"
shift

case "$target" in
  rtc) workspace="$RTC_REPO" ;;
  zacus) workspace="$ZACUS_REPO" ;;
  *) workspace="$target" ;;
esac

if [[ ! -d "$workspace" ]]; then
  echo "Workspace not found: $workspace" >&2
  exit 1
fi

if [[ ! -x "$ZEROCLAW_BIN" ]]; then
  if command -v zeroclaw >/dev/null 2>&1; then
    ZEROCLAW_BIN="$(command -v zeroclaw)"
  else
    echo "zeroclaw binary not found." >&2
    exit 1
  fi
fi

if [[ "${1:-}" == "--hardware" ]]; then
  ZEROCLAW_WORKSPACE="$workspace" "$ZEROCLAW_BIN" hardware discover
  exit 0
fi

if [[ "${1:-}" == "--cheap" ]]; then
  export ZEROCLAW_PREFER_LOCAL_AI=1
  shift
fi

resolve_provider() {
  if [[ -n "${ZEROCLAW_PROVIDER:-}" ]]; then
    echo "$ZEROCLAW_PROVIDER"
    return 0
  fi

  if [[ "${ZEROCLAW_PREFER_LOCAL_AI:-0}" == "1" ]] && command -v ollama >/dev/null 2>&1; then
    local ollama_model
    ollama_model="${ZEROCLAW_OLLAMA_MODEL:-llama3.2:1b}"
    if ollama list >/dev/null 2>&1; then
      if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | rg -qx "$ollama_model"; then
        echo "ollama"
        return 0
      fi
      local first_model
      first_model="$(ollama list 2>/dev/null | awk 'NR==2 {print $1}')"
      if [[ -n "$first_model" ]]; then
        export ZEROCLAW_OLLAMA_MODEL="$first_model"
        echo "ollama"
        return 0
      fi
    fi
  fi

  if [[ "${ZEROCLAW_SKIP_COPILOT_CHECK:-0}" != "1" ]] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh api /user/copilot/billing --silent >/dev/null 2>&1; then
      local gh_token
      gh_token="$(gh auth token)"
      export API_KEY="$gh_token"
      echo "copilot"
      return 0
    fi
  fi

  if env -u ZEROCLAW_WORKSPACE "$ZEROCLAW_BIN" auth status 2>/dev/null | rg -q "openai-codex:"; then
    echo "openai-codex"
    return 0
  fi

  if env -u ZEROCLAW_WORKSPACE "$ZEROCLAW_BIN" auth list 2>/dev/null | rg -q "openai-codex:"; then
    echo "openai-codex"
    return 0
  fi

  if [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]]; then
    echo "gemini"
    return 0
  fi

  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    export API_KEY="$OPENROUTER_API_KEY"
    echo "openrouter"
    return 0
  fi

  if [[ -n "${ANTHROPIC_API_KEY:-}" || -n "${ANTHROPIC_OAUTH_TOKEN:-}" ]]; then
    echo "anthropic"
    return 0
  fi

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    echo "openai"
    return 0
  fi

  cat <<'ERR' >&2
No provider credentials detected.
- Option 0: install local model and set ZEROCLAW_PREFER_LOCAL_AI=1 (ollama)
- Option 1: ZEROCLAW_PROVIDER=copilot with GitHub Copilot subscription + gh auth login
- Option 2: zeroclaw auth login --provider openai-codex --device-code
- Option 3: export OPENROUTER_API_KEY=... and ZEROCLAW_PROVIDER=openrouter
ERR
  return 1
}

provider="$(resolve_provider)"
echo "[zeroclaw-dual-chat] workspace=$workspace provider=$provider"

if [[ "${1:-}" == "--provider-check" ]]; then
  exit 0
fi

export ZEROCLAW_WORKSPACE="$workspace"

if [[ "${1:-}" == "--interactive" ]]; then
  exec "$ZEROCLAW_BIN" agent -p "$provider"
fi

if [[ "${1:-}" != "-m" || -z "${2:-}" ]]; then
  usage
  exit 1
fi

exec "$ZEROCLAW_BIN" agent -p "$provider" -m "$2"
