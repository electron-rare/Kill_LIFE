#!/usr/bin/env bash

# shellcheck shell=bash

kill_life_runtime_home_init() {
  local root_dir="$1"
  local runtime_name="$2"
  local base_dir="${3:-$root_dir/.runtime-home}"

  RUNTIME_HOME="${KILL_LIFE_RUNTIME_HOME:-$base_dir/$runtime_name}"
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$RUNTIME_HOME/.config}"
  XDG_CACHE_HOME="${XDG_CACHE_HOME:-$RUNTIME_HOME/.cache}"
  HOME="$RUNTIME_HOME"

  export RUNTIME_HOME HOME XDG_CONFIG_HOME XDG_CACHE_HOME
}

kill_life_runtime_home_ensure() {
  mkdir -p "$RUNTIME_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
}
