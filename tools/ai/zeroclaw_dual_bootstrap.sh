#!/usr/bin/env bash
set -euo pipefail

ZEROCLAW_BIN="${ZEROCLAW_BIN:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/zeroclaw/target/release/zeroclaw}"
RTC_REPO="/Users/cils/Documents/Lelectron_rare/RTC_BL_PHONE"
ZACUS_REPO="/Users/cils/Documents/Lelectron_rare/le-mystere-professeur-zacus"
HARDWARE_ONLY=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--rtc <path>] [--zacus <path>] [--zeroclaw-bin <path>] [--hardware-only]

Bootstrap local ZeroClaw workspace profiles for both repos and run hardware discovery.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rtc)
      RTC_REPO="${2:-}"; shift 2 ;;
    --zacus)
      ZACUS_REPO="${2:-}"; shift 2 ;;
    --zeroclaw-bin)
      ZEROCLAW_BIN="${2:-}"; shift 2 ;;
    --hardware-only)
      HARDWARE_ONLY=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ ! -x "$ZEROCLAW_BIN" ]]; then
  if command -v zeroclaw >/dev/null 2>&1; then
    ZEROCLAW_BIN="$(command -v zeroclaw)"
  else
    echo "zeroclaw binary not found." >&2
    exit 1
  fi
fi

if [[ "$HARDWARE_ONLY" == "1" ]]; then
  "$ZEROCLAW_BIN" hardware discover
  exit 0
fi

write_repo_config() {
  local repo="$1"
  mkdir -p "$repo/.zeroclaw"
  mkdir -p "$repo/.zeroclaw/legacy"

  # If a previous run created a root ZeroClaw profile, archive it so
  # ZEROCLAW_WORKSPACE resolves to repo-local .zeroclaw/config.toml.
  if [[ -f "$repo/config.toml" ]] && rg -q '^default_provider =|^\[autonomy\]' "$repo/config.toml"; then
    mv "$repo/config.toml" "$repo/.zeroclaw/legacy/config.root.auto.toml"
  fi
  if [[ -d "$repo/workspace" && -d "$repo/workspace/memory" && -d "$repo/workspace/state" ]]; then
    mv "$repo/workspace" "$repo/.zeroclaw/legacy/workspace.root.auto"
  fi

  cat > "$repo/.zeroclaw/config.toml" <<'TOML'
default_provider = "openai-codex"
default_temperature = 0.2

[memory]
backend = "sqlite"
auto_save = true
embedding_provider = "none"

[autonomy]
level = "supervised"
workspace_only = true
allowed_commands = ["git", "gh", "ls", "cat", "rg", "sed", "awk", "find", "make", "python3", "bash", "sh", "pio"]
forbidden_paths = ["/etc", "/root", "/home", "/usr", "/bin", "/sbin", "/lib", "/opt", "/boot", "/dev", "/proc", "/sys", "/var", "/tmp", "~/.ssh", "~/.gnupg", "~/.aws", "~/.config"]
max_actions_per_hour = 40
max_cost_per_day_cents = 150
require_approval_for_medium_risk = true
block_high_risk_commands = true
TOML
}

write_repo_config "$RTC_REPO"
write_repo_config "$ZACUS_REPO"

ZEROCLAW_WORKSPACE="$RTC_REPO" "$ZEROCLAW_BIN" status >/dev/null
ZEROCLAW_WORKSPACE="$ZACUS_REPO" "$ZEROCLAW_BIN" status >/dev/null

"$ZEROCLAW_BIN" hardware discover
echo "Bootstrap complete."
echo "- RTC workspace: $RTC_REPO"
echo "- Zacus workspace: $ZACUS_REPO"
echo "Provider strategy:"
echo "1) export ZEROCLAW_PROVIDER=copilot (requires GitHub Copilot subscription)"
echo "2) zeroclaw auth login --provider openai-codex --device-code"
echo "3) export OPENROUTER_API_KEY=... and use ZEROCLAW_PROVIDER=openrouter"
