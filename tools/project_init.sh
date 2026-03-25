#!/usr/bin/env bash
# project_init.sh — Initialize a client repo with the Kill_LIFE project template
#
# Usage:
#   ./tools/project_init.sh <github_repo_url> <project_name> [client_name]
#
# Example:
#   ./tools/project_init.sh git@github.com:electron-rare/hypnoled.git hypnoled "Hypnoled SAS"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KILL_LIFE_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$KILL_LIFE_ROOT/templates/kill-life-project"
WORK_DIR="${KILL_LIFE_WORK_DIR:-/tmp/kill-life-init}"

# --- Args ---
if [ $# -lt 2 ]; then
    echo "Usage: $0 <github_repo_url> <project_name> [client_name]"
    echo ""
    echo "  github_repo_url  Git clone URL of the target repo"
    echo "  project_name     Short name (used in .kill-life.yaml and directory)"
    echo "  client_name      Optional client/org name (defaults to project_name)"
    exit 1
fi

REPO_URL="$1"
PROJECT_NAME="$2"
CLIENT_NAME="${3:-$PROJECT_NAME}"

CLONE_DIR="$WORK_DIR/$PROJECT_NAME"

echo "=== Kill_LIFE Project Init ==="
echo "Repo:    $REPO_URL"
echo "Project: $PROJECT_NAME"
echo "Client:  $CLIENT_NAME"
echo "WorkDir: $CLONE_DIR"
echo ""

# --- Clone ---
if [ -d "$CLONE_DIR" ]; then
    echo "Directory $CLONE_DIR already exists. Pulling latest..."
    git -C "$CLONE_DIR" pull --ff-only
else
    mkdir -p "$WORK_DIR"
    echo "Cloning $REPO_URL..."
    git clone "$REPO_URL" "$CLONE_DIR"
fi

# --- Apply template structure ---
echo "Applying Kill_LIFE template structure..."

DIRS=(
    hardware/pcb
    hardware/simulation
    hardware/bom
    firmware/src
    docs/reviews
    docs/specs
    docs/client
    fabrication
    .github/workflows
)

for dir in "${DIRS[@]}"; do
    mkdir -p "$CLONE_DIR/$dir"
done

# Copy template files (don't overwrite existing)
copy_if_missing() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        echo "  + $dst"
    else
        echo "  . $dst (already exists, skipped)"
    fi
}

# README files for each directory
for dir in "${DIRS[@]}"; do
    if [ -f "$TEMPLATE_DIR/$dir/README.md" ]; then
        copy_if_missing "$TEMPLATE_DIR/$dir/README.md" "$CLONE_DIR/$dir/README.md"
    fi
done

# Top-level files
copy_if_missing "$TEMPLATE_DIR/Makefile" "$CLONE_DIR/Makefile"
copy_if_missing "$TEMPLATE_DIR/firmware/platformio.ini" "$CLONE_DIR/firmware/platformio.ini"
copy_if_missing "$TEMPLATE_DIR/.github/workflows/kill-life-ci.yml" "$CLONE_DIR/.github/workflows/kill-life-ci.yml"
copy_if_missing "$TEMPLATE_DIR/fabrication/README.md" "$CLONE_DIR/fabrication/README.md"

# --- Generate .kill-life.yaml with substituted values ---
echo "Generating .kill-life.yaml..."
sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{CLIENT_NAME}}/$CLIENT_NAME/g" \
    "$TEMPLATE_DIR/.kill-life.yaml" > "$CLONE_DIR/.kill-life.yaml"
echo "  + .kill-life.yaml"

# --- Generate README if missing ---
if [ ! -f "$CLONE_DIR/README.md" ]; then
    sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        "$TEMPLATE_DIR/README.md" > "$CLONE_DIR/README.md"
    echo "  + README.md"
fi

# --- Commit ---
echo ""
echo "Committing changes..."
cd "$CLONE_DIR"
git add -A
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "feat: apply Kill_LIFE project template

Adds standard directory structure for hardware, firmware, docs, and fabrication.
Configures CI workflow for ERC/DRC checks and firmware builds.
Links project to Kill_LIFE orchestrator via .kill-life.yaml."
    echo ""
    echo "Changes committed. Push with:"
    echo "  cd $CLONE_DIR && git push"
fi

echo ""
echo "=== Done ==="
echo "Project initialized at: $CLONE_DIR"
