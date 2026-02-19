#!/bin/bash
# Script pour installer les paquets requis dans la VM Ubuntu Minimal
set -euo pipefail
sudo apt update && sudo apt install -y curl git nodejs npm build-essential
