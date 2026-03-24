#!/usr/bin/env bash
# MCP server for Mascarade LLM Router
# Exposes: list_models, chat, health, list_providers
set -euo pipefail

MASCARADE_URL="${MASCARADE_URL:-http://localhost:8100}"

exec python3 -u "$(dirname "$0")/mascarade_mcp_server.py" "$MASCARADE_URL"
