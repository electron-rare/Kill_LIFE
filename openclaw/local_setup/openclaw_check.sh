#!/bin/bash
# Script pour lancer openclaw doctor et openclaw help automatiquement
set -euo pipefail
~/.local/bin/openclaw doctor || true
~/.local/bin/openclaw help || true
