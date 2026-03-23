#!/usr/bin/env bash
# prepare_and_validate.sh — Préparation et validation datasets fine-tune
# Usage: ./prepare_and_validate.sh <config.yaml>
# Prérequis: mistral-finetune cloné dans $HOME/mistral-finetune
#
# T-MA-016 (KiCad):  ./prepare_and_validate.sh configs/kicad_small.yaml
# T-MA-017 (SPICE):  ./prepare_and_validate.sh configs/spice_codestral.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FINETUNE_DIR="${HOME}/mistral-finetune"
CONFIG="${1:?Usage: $0 <config.yaml>}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Mistral Fine-tune — Préparation ===${NC}"
echo "Config: ${CONFIG}"

# 1. Vérifier que mistral-finetune est cloné
if [ ! -d "${FINETUNE_DIR}" ]; then
    echo -e "${YELLOW}[1/5] Clonage mistral-finetune...${NC}"
    cd "${HOME}" && git clone --depth 1 https://github.com/mistralai/mistral-finetune.git
    cd "${FINETUNE_DIR}" && pip install -r requirements.txt
else
    echo -e "${GREEN}[1/5] mistral-finetune déjà présent${NC}"
fi

# 2. Extraire les chemins dataset depuis le YAML
TRAIN_DATA=$(python3 -c "
import yaml
with open('${SCRIPT_DIR}/${CONFIG}') as f:
    cfg = yaml.safe_load(f)
print(cfg['data']['instruct_data'])
")
EVAL_DATA=$(python3 -c "
import yaml
with open('${SCRIPT_DIR}/${CONFIG}') as f:
    cfg = yaml.safe_load(f)
print(cfg['data']['eval_instruct_data'])
")

echo -e "${YELLOW}[2/5] Vérification datasets...${NC}"
echo "  Train: ${TRAIN_DATA}"
echo "  Eval:  ${EVAL_DATA}"

for f in "${TRAIN_DATA}" "${EVAL_DATA}"; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}  ERREUR: Fichier manquant: $f${NC}"
        echo "  -> Lancez d'abord le pipeline: python mistral_dataset_pipeline.py"
        exit 1
    fi
done

# 3. Compter les samples
TRAIN_COUNT=$(wc -l < "${TRAIN_DATA}")
EVAL_COUNT=$(wc -l < "${EVAL_DATA}")
echo -e "${GREEN}  Train: ${TRAIN_COUNT} samples${NC}"
echo -e "${GREEN}  Eval:  ${EVAL_COUNT} samples${NC}"

# 4. Valider le format avec l'outil mistral-finetune
echo -e "${YELLOW}[3/5] Validation du format JSONL...${NC}"
cd "${FINETUNE_DIR}"
python -m utils.validate_data --train_yaml "${SCRIPT_DIR}/${CONFIG}" 2>&1 | tee /tmp/validate_output.txt

# 5. Vérifier les erreurs
ERROR_COUNT=$(grep -c "incorrectly formatted" /tmp/validate_output.txt 2>/dev/null || echo "0")
if [ "${ERROR_COUNT}" -gt 0 ]; then
    echo -e "${YELLOW}[4/5] ${ERROR_COUNT} erreurs détectées — tentative de correction...${NC}"
    python -m utils.reformat_data "${TRAIN_DATA}"
    python -m utils.reformat_data "${EVAL_DATA}"

    echo -e "${YELLOW}[5/5] Re-validation après correction...${NC}"
    python -m utils.validate_data --train_yaml "${SCRIPT_DIR}/${CONFIG}"
else
    echo -e "${GREEN}[4/5] Aucune erreur de format${NC}"
    echo -e "${GREEN}[5/5] Dataset prêt pour le fine-tune !${NC}"
fi

echo ""
echo -e "${GREEN}=== Préparation terminée ===${NC}"
echo "Pour lancer le fine-tune :"
echo "  cd ${FINETUNE_DIR}"
echo "  torchrun --nproc-per-node <N_GPU> --master_port \$RANDOM -m train ${SCRIPT_DIR}/${CONFIG}"
