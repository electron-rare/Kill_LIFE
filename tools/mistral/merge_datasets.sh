#!/usr/bin/env bash
# merge_datasets.sh — Merge domain JSONL datasets for Mistral fine-tuning
#
# Produces two merged files:
#   - datasets/kicad_merged.jsonl          (KiCad domain)
#   - datasets/spice_embedded_merged.jsonl (SPICE + Embedded + STM32 domains)
#
# Then validates both with validate_dataset.py.
#
# Usage:
#   ./merge_datasets.sh
#   ./merge_datasets.sh --dry-run
#
# Supports T-MS-002 (KiCad dataset prep) and T-MS-003 (SPICE+Embedded dataset prep)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATASETS_DIR="${SCRIPT_DIR}/datasets"
VALIDATE="${SCRIPT_DIR}/validate_dataset.py"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] No files will be written."
fi

# ── Colors ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; }

# ── Merge KiCad ─────────────────────────────────────────────────────
KICAD_OUT="${DATASETS_DIR}/kicad_merged.jsonl"
KICAD_SOURCES=()

for f in "${DATASETS_DIR}"/kicad/train.jsonl; do
    [[ -f "$f" ]] && KICAD_SOURCES+=("$f")
done

echo ""
echo "=== T-MS-002: KiCad dataset merge ==="
echo "Sources found: ${#KICAD_SOURCES[@]}"

if [[ ${#KICAD_SOURCES[@]} -eq 0 ]]; then
    err "No KiCad train.jsonl found in ${DATASETS_DIR}/kicad/"
    exit 1
fi

if [[ "$DRY_RUN" == false ]]; then
    cat "${KICAD_SOURCES[@]}" | sort -u > "$KICAD_OUT"
    KICAD_LINES=$(wc -l < "$KICAD_OUT" | tr -d ' ')
    ok "kicad_merged.jsonl created — ${KICAD_LINES} examples"
else
    KICAD_LINES=0
    for f in "${KICAD_SOURCES[@]}"; do
        n=$(wc -l < "$f" | tr -d ' ')
        KICAD_LINES=$((KICAD_LINES + n))
        echo "  would merge: $f ($n lines)"
    done
    ok "[dry-run] would produce ~${KICAD_LINES} lines (before dedup)"
fi

# ── Merge SPICE + Embedded + STM32 ──────────────────────────────────
SPICE_EMB_OUT="${DATASETS_DIR}/spice_embedded_merged.jsonl"
SPICE_EMB_SOURCES=()

for domain in spice embedded stm32; do
    f="${DATASETS_DIR}/${domain}/train.jsonl"
    [[ -f "$f" ]] && SPICE_EMB_SOURCES+=("$f")
done

echo ""
echo "=== T-MS-003: SPICE+Embedded dataset merge ==="
echo "Sources found: ${#SPICE_EMB_SOURCES[@]}"

if [[ ${#SPICE_EMB_SOURCES[@]} -eq 0 ]]; then
    err "No SPICE/Embedded/STM32 train.jsonl found"
    exit 1
fi

if [[ "$DRY_RUN" == false ]]; then
    cat "${SPICE_EMB_SOURCES[@]}" | sort -u > "$SPICE_EMB_OUT"
    SPICE_LINES=$(wc -l < "$SPICE_EMB_OUT" | tr -d ' ')
    ok "spice_embedded_merged.jsonl created — ${SPICE_LINES} examples"
else
    SPICE_LINES=0
    for f in "${SPICE_EMB_SOURCES[@]}"; do
        n=$(wc -l < "$f" | tr -d ' ')
        SPICE_LINES=$((SPICE_LINES + n))
        echo "  would merge: $f ($n lines)"
    done
    ok "[dry-run] would produce ~${SPICE_LINES} lines (before dedup)"
fi

# ── Validate ─────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
    echo ""
    echo "=== Validation ==="

    ERRORS=0

    if [[ -f "$VALIDATE" ]]; then
        echo "Validating kicad_merged.jsonl..."
        if python3 "$VALIDATE" "$KICAD_OUT"; then
            ok "kicad_merged.jsonl valid"
        else
            warn "kicad_merged.jsonl has validation warnings (see above)"
            ERRORS=$((ERRORS + 1))
        fi

        echo ""
        echo "Validating spice_embedded_merged.jsonl..."
        if python3 "$VALIDATE" "$SPICE_EMB_OUT"; then
            ok "spice_embedded_merged.jsonl valid"
        else
            warn "spice_embedded_merged.jsonl has validation warnings (see above)"
            ERRORS=$((ERRORS + 1))
        fi
    else
        warn "validate_dataset.py not found at ${VALIDATE} — skipping validation"
    fi

    echo ""
    echo "=== Summary ==="
    ok "KiCad merged:          ${KICAD_OUT} (${KICAD_LINES} examples)"
    ok "SPICE+Embedded merged: ${SPICE_EMB_OUT} (${SPICE_LINES} examples)"

    if [[ $ERRORS -gt 0 ]]; then
        warn "${ERRORS} validation warning(s) — review output above"
    else
        ok "All datasets valid — ready for Mistral upload (T-MS-002/003)"
    fi
fi

echo ""
echo "Done."
