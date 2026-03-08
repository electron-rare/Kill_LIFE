#!/usr/bin/env bash

# shellcheck shell=bash

kill_life_runtime_home_is_writable() {
  local target_dir="$1"
  local probe_dir="$target_dir"

  while [ ! -e "$probe_dir" ]; do
    probe_dir="$(dirname "$probe_dir")"
    if [ "$probe_dir" = "/" ]; then
      break
    fi
  done

  [ -w "$probe_dir" ]
}

kill_life_runtime_home_init() {
  local root_dir="$1"
  local runtime_name="$2"
  local base_dir="${3:-$root_dir/.runtime-home}"
  local fallback_base_dir="${KILL_LIFE_RUNTIME_BASE_DIR:-$root_dir/.cad-home/runtime-home}"
  local selected_base_dir="$base_dir"

  if [ -z "${KILL_LIFE_RUNTIME_HOME:-}" ] && ! kill_life_runtime_home_is_writable "$base_dir"; then
    selected_base_dir="$fallback_base_dir"
    if ! kill_life_runtime_home_is_writable "$selected_base_dir"; then
      selected_base_dir="${XDG_RUNTIME_DIR:-/tmp}/kill-life-runtime-home"
    fi
  fi

  RUNTIME_HOME="${KILL_LIFE_RUNTIME_HOME:-$selected_base_dir/$runtime_name}"
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$RUNTIME_HOME/.config}"
  XDG_CACHE_HOME="${XDG_CACHE_HOME:-$RUNTIME_HOME/.cache}"
  HOME="$RUNTIME_HOME"

  export RUNTIME_HOME HOME XDG_CONFIG_HOME XDG_CACHE_HOME
}

kill_life_runtime_home_ensure() {
  mkdir -p "$RUNTIME_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
}
