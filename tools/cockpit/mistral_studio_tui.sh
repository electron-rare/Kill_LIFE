#!/bin/bash
# ============================================================================
# mistral_studio_tui.sh — Interface TUI pour Mistral AI Studio (toutes options)
# Contrat: cockpit-v1
# Lot: 24 — Intégration Mistral Studio Complète
# Date: 2026-03-21
#
# Couvre: Agents (Beta Conversations API), Batches, IA Documentaire, Audio,
#         Fine-tune, Fichiers, Libraries (Document Library RAG), Vibe CLI, Codestral
# MAJ: 2026-03-22 — Migration Beta API + Libraries + Small 4
# ============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; MAGENTA='\033[0;35m'; NC='\033[0m'

MISTRAL_API_KEY="${MISTRAL_API_KEY:-}"
MISTRAL_BASE="https://api.mistral.ai/v1"
CODESTRAL_BASE="https://codestral.mistral.ai/v1"
LOG_DIR="${LOG_DIR:-/tmp/mistral_studio_logs}"
LOG_FILE="${LOG_DIR}/studio_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR" 2>/dev/null || true

# Agents
declare -A AGENTS=(
  ["sentinelle"]="ag_019d124c302375a8bf06f9ff8a99fb5f:mistral-medium-latest:ops-monitoring"
  ["tower"]="ag_019d124e760877359ad3ff5031179ebc:magistral-medium-latest:commercial-crm"
  ["forge"]="ag_019d1251023f73258b80ac73f90458f6:codestral-latest:finetune-pipeline"
  ["devstral"]="ag_019d125348eb77e880df33acbd395efa:devstral-latest:code-workflow"
)

# --- Logging ---
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
  echo -e "$msg"
}

log_json() {
  local component="$1" action="$2" status="$3"
  shift 3
  local extra="${*:-}"
  cat <<EOF
{
  "contract_version": "cockpit-v1",
  "component": "mistral-studio-tui",
  "sub_component": "$component",
  "action": "$action",
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "log_file": "$LOG_FILE"${extra:+,
  $extra}
}
EOF
}

check_api_key() {
  if [ -z "$MISTRAL_API_KEY" ]; then
    echo -e "${RED}✗ MISTRAL_API_KEY non définie${NC}"
    return 1
  fi
}

api_call() {
  local method="$1" endpoint="$2" data="${3:-}"
  local base="${4:-$MISTRAL_BASE}"

  local args=(-s -w "\n%{http_code}" --max-time 30
    -H "Authorization: Bearer $MISTRAL_API_KEY"
    -H "Content-Type: application/json")

  if [ "$method" = "POST" ] && [ -n "$data" ]; then
    args+=(-X POST -d "$data")
  elif [ "$method" = "DELETE" ]; then
    args+=(-X DELETE)
  fi

  curl "${args[@]}" "${base}${endpoint}" 2>/dev/null
}

# ============================================================================
# 1. AGENTS
# ============================================================================

# API mode: "beta" uses /conversations/completions, "deprecated" uses /agents/completions
API_MODE="${API_MODE:-beta}"

# Helper: call agent with beta fallback
call_agent_api() {
  local agent_id="$1" payload="$2"
  local response http_code

  if [ "$API_MODE" = "beta" ]; then
    # Try Beta Conversations API first
    response=$(api_call POST "/conversations/completions" \
      "$(echo "$payload" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['agent_id'] = '${agent_id}'
print(json.dumps(d))
" 2>/dev/null)")
    http_code=$(echo "$response" | tail -1)
    if [ "$http_code" = "200" ]; then
      echo "$response"
      return 0
    fi
    # Fallback to deprecated
    log "WARN: Beta API failed (HTTP $http_code), falling back to deprecated"
  fi

  # Deprecated API
  response=$(api_call POST "/agents/completions" \
    "$(echo "$payload" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['agent_id'] = '${agent_id}'
print(json.dumps(d))
" 2>/dev/null)")
  echo "$response"
}

action_agents_status() {
  echo -e "\n${BOLD}${CYAN}[Agents — Status (API: $API_MODE)]${NC}"
  check_api_key || return 1

  for name in sentinelle tower forge devstral; do
    IFS=':' read -r id model role <<< "${AGENTS[$name]}"
    echo -e "  ${BOLD}$name${NC} ($role)"
    echo -e "    Model: ${MAGENTA}$model${NC}"
    echo -e "    ID: $id"

    local response
    response=$(call_agent_api "$id" '{"messages":[{"role":"user","content":"ping"}],"max_tokens":5}')
    local http_code
    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "200" ]; then
      echo -e "    Status: ${GREEN}✓ ONLINE${NC}"
    else
      echo -e "    Status: ${RED}✗ HTTP $http_code${NC}"
    fi
  done
  log "agents_status completed (api=$API_MODE)"
}

action_agents_chat() {
  local agent="${1:-sentinelle}"
  echo -e "\n${BOLD}${CYAN}[Agent Chat — $agent (API: $API_MODE)]${NC}"
  check_api_key || return 1

  IFS=':' read -r id model role <<< "${AGENTS[$agent]}"
  echo -e "  Agent: $agent ($model, $role)"
  echo -e "  Tapez 'quit' pour quitter\n"

  local conv_id=""

  while true; do
    echo -ne "${GREEN}> ${NC}"
    read -r user_input
    [ "$user_input" = "quit" ] && break

    local payload
    payload=$(python3 -c "
import json
d = {'messages': [{'role': 'user', 'content': '''$user_input'''}], 'max_tokens': 500}
conv_id = '''$conv_id'''
if conv_id:
    d['conversation_id'] = conv_id
print(json.dumps(d))
" 2>/dev/null)

    local response
    response=$(call_agent_api "$id" "$payload")
    local http_code body
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [ "$http_code" = "200" ]; then
      local content
      content=$(echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Capture conversation_id for stateful Beta API
cid = d.get('conversation_id', '')
if cid:
    print('CONV_ID:' + cid, file=sys.stderr)
print(d.get('choices',[{}])[0].get('message',{}).get('content','no response'))
" 2>/dev/null 2> >(grep 'CONV_ID:' | head -1 | sed 's/CONV_ID://'))
      # Capture conversation_id from stderr for stateful chat
      local new_conv_id
      new_conv_id=$(echo "$body" | python3 -c "import sys,json;print(json.load(sys.stdin).get('conversation_id',''))" 2>/dev/null || echo "")
      [ -n "$new_conv_id" ] && conv_id="$new_conv_id"
      echo -e "\n${CYAN}$agent${NC}: $content\n"
    else
      echo -e "\n${RED}Error HTTP $http_code${NC}\n"
    fi
    log "chat:$agent user='$user_input' http=$http_code conv=$conv_id"
  done
}

# ============================================================================
# 2. FICHIERS
# ============================================================================

action_files_list() {
  echo -e "\n${BOLD}${CYAN}[Fichiers — Liste]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/files")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads('''$body''')
files = d.get('data', [])
if not files:
    print('  (aucun fichier)')
else:
    for f in files:
        print(f'  {f[\"id\"]:30} {f.get(\"filename\",\"?\"):40} {f.get(\"bytes\",0):>10} bytes  {f.get(\"purpose\",\"?\")}')
print(f'\n  Total: {len(files)} fichiers')
" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC}"
  fi
  log "files_list http=$http_code"
}

action_files_upload() {
  local filepath="$1" purpose="${2:-fine-tune}"
  echo -e "\n${BOLD}${CYAN}[Fichiers — Upload]${NC}"
  check_api_key || return 1

  if [ ! -f "$filepath" ]; then
    echo -e "  ${RED}Fichier non trouvé: $filepath${NC}"
    return 1
  fi

  echo -e "  Uploading: $(basename "$filepath") (purpose: $purpose)"

  local response
  response=$(curl -s -w "\n%{http_code}" --max-time 120 \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -F "file=@$filepath" \
    -F "purpose=$purpose" \
    "${MISTRAL_BASE}/files" 2>/dev/null)

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    local file_id
    file_id=$(echo "$body" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
    echo -e "  ${GREEN}✓ Upload OK${NC} — ID: $file_id"
    log_json "files" "upload" "success" "\"file_id\": \"$file_id\", \"filename\": \"$(basename "$filepath")\""
  else
    echo -e "  ${RED}✗ Upload failed HTTP $http_code${NC}"
    echo "  $body"
  fi
  log "files_upload file=$(basename "$filepath") purpose=$purpose http=$http_code"
}

# ============================================================================
# 3. FINE-TUNE
# ============================================================================

action_finetune_list() {
  echo -e "\n${BOLD}${CYAN}[Fine-tune — Jobs]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/fine_tuning/jobs")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads('''$body''')
jobs = d.get('data', [])
if not jobs:
    print('  (aucun job)')
else:
    for j in jobs:
        status = j.get('status','?')
        color = '32' if status == 'SUCCEEDED' else '33' if status == 'RUNNING' else '31'
        print(f'  \033[{color}m●\033[0m {j.get(\"id\",\"?\"):30} {j.get(\"fine_tuned_model\",\"?\"):30} {status}')
print(f'\n  Total: {len(jobs)} jobs')
" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC}"
  fi
  log "finetune_list http=$http_code"
}

action_finetune_create() {
  local model="$1" training_file="$2"
  local suffix="${3:-v1}"
  echo -e "\n${BOLD}${CYAN}[Fine-tune — Create Job]${NC}"
  check_api_key || return 1

  echo -e "  Model: $model"
  echo -e "  Training file: $training_file"
  echo -e "  Suffix: $suffix"

  local payload="{
    \"model\": \"$model\",
    \"training_files\": [\"$training_file\"],
    \"suffix\": \"$suffix\",
    \"hyperparameters\": {
      \"training_steps\": 100,
      \"learning_rate\": 1e-5
    }
  }"

  local response
  response=$(api_call POST "/fine_tuning/jobs" "$payload")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    local job_id
    job_id=$(echo "$body" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
    echo -e "  ${GREEN}✓ Job créé${NC} — ID: $job_id"
    log_json "finetune" "create" "success" "\"job_id\": \"$job_id\""
  else
    echo -e "  ${RED}✗ Création failed HTTP $http_code${NC}"
    echo "  $body"
  fi
  log "finetune_create model=$model file=$training_file http=$http_code"
}

action_finetune_models() {
  echo -e "\n${BOLD}${CYAN}[Fine-tune — Modèles personnalisés]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/models")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
models = [m for m in d.get('data', []) if m.get('id','').startswith('ft:')]
if not models:
    print('  (aucun modèle fine-tuné)')
else:
    for m in models:
        print(f'  {m[\"id\"]:40} owner={m.get(\"owned_by\",\"?\")}')
print(f'\n  Fine-tuned: {len(models)}')
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC}"
  fi
  log "finetune_models http=$http_code"
}

# ============================================================================
# 4. BATCHES
# ============================================================================

action_batches_list() {
  echo -e "\n${BOLD}${CYAN}[Batches — Liste]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/batches")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads('''$body''')
batches = d.get('data', [])
if not batches:
    print('  (aucun batch)')
else:
    for b in batches:
        print(f'  {b.get(\"id\",\"?\"):30} {b.get(\"status\",\"?\"):15} {b.get(\"model\",\"?\")}')
print(f'\n  Total: {len(batches)} batches')
" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC}"
  fi
  log "batches_list http=$http_code"
}

# ============================================================================
# 5. IA DOCUMENTAIRE (OCR)
# ============================================================================

action_docai_ocr() {
  local filepath="$1"
  echo -e "\n${BOLD}${CYAN}[IA Documentaire — OCR]${NC}"
  check_api_key || return 1

  if [ ! -f "$filepath" ]; then
    echo -e "  ${RED}Fichier non trouvé: $filepath${NC}"
    return 1
  fi

  echo -e "  Processing: $(basename "$filepath")"

  # Upload file first, then use document AI
  local mime_type="application/pdf"
  [[ "$filepath" == *.png ]] && mime_type="image/png"
  [[ "$filepath" == *.jpg ]] && mime_type="image/jpeg"

  local response
  response=$(curl -s -w "\n%{http_code}" --max-time 120 \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"mistral-ocr-latest\",
      \"document\": {
        \"type\": \"document_url\",
        \"document_url\": \"data:${mime_type};base64,$(base64 -w0 "$filepath")\"
      }
    }" \
    "${MISTRAL_BASE}/ocr" 2>/dev/null)

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ OCR OK${NC}"
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
pages = d.get('pages', [])
for p in pages:
    print(f'  --- Page {p.get(\"index\",\"?\")} ---')
    text = p.get('markdown', p.get('text', ''))
    print(text[:500])
    if len(text) > 500:
        print('  ...[truncated]')
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}✗ OCR failed HTTP $http_code${NC}"
  fi
  log "docai_ocr file=$(basename "$filepath") http=$http_code"
}

# ============================================================================
# 6. AUDIO (STT)
# ============================================================================

action_audio_transcribe() {
  local filepath="$1"
  echo -e "\n${BOLD}${CYAN}[Audio — Transcription]${NC}"
  check_api_key || return 1

  if [ ! -f "$filepath" ]; then
    echo -e "  ${RED}Fichier non trouvé: $filepath${NC}"
    return 1
  fi

  echo -e "  Transcribing: $(basename "$filepath")"

  local response
  response=$(curl -s -w "\n%{http_code}" --max-time 300 \
    -H "Authorization: Bearer $MISTRAL_API_KEY" \
    -F "file=@$filepath" \
    -F "model=mistral-stt-latest" \
    "${MISTRAL_BASE}/audio/transcriptions" 2>/dev/null)

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ Transcription OK${NC}"
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(d.get('text', 'no text'))
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}✗ Transcription failed HTTP $http_code${NC}"
  fi
  log "audio_transcribe file=$(basename "$filepath") http=$http_code"
}

# ============================================================================
# 7. CODESTRAL
# ============================================================================

action_codestral_complete() {
  local prompt="$1"
  local suffix="${2:-}"
  echo -e "\n${BOLD}${CYAN}[Codestral — FIM Completion]${NC}"

  local codestral_key="${CODESTRAL_API_KEY:-$MISTRAL_API_KEY}"

  local payload="{\"model\":\"codestral-latest\",\"prompt\":\"$prompt\",\"suffix\":\"$suffix\",\"max_tokens\":200}"

  local response
  response=$(curl -s -w "\n%{http_code}" --max-time 30 \
    -H "Authorization: Bearer $codestral_key" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${CODESTRAL_BASE}/fim/completions" 2>/dev/null)

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ Completion OK${NC}"
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
choices = d.get('choices', [])
if choices:
    print(choices[0].get('message',{}).get('content', choices[0].get('text','')))
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}✗ Codestral failed HTTP $http_code${NC}"
  fi
  log "codestral_complete http=$http_code"
}

# ============================================================================
# 8. CONVERSATIONS (Beta API)
# ============================================================================

action_conversations_list() {
  echo -e "\n${BOLD}${CYAN}[Conversations — Liste (Beta)]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/conversations")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
convs = d.get('data', [])
if not convs:
    print('  (aucune conversation)')
else:
    for c in convs:
        print(f'  {c.get(\"id\",\"?\"):36} agent={c.get(\"agent_id\",\"?\"):36} created={c.get(\"created_at\",\"?\")}')
print(f'\n  Total: {len(convs)} conversations')
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC} (Beta API may not be available yet)"
  fi
  log "conversations_list http=$http_code"
}

action_conversations_create() {
  local agent="${1:-sentinelle}"
  echo -e "\n${BOLD}${CYAN}[Conversations — Créer (Beta)]${NC}"
  check_api_key || return 1

  IFS=':' read -r id model role <<< "${AGENTS[$agent]}"
  echo -e "  Agent: $agent ($id)"

  local response
  response=$(api_call POST "/conversations" "{\"agent_id\":\"$id\"}")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    local conv_id
    conv_id=$(echo "$body" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
    echo -e "  ${GREEN}✓ Conversation créée${NC} — ID: $conv_id"
    log_json "conversations" "create" "success" "\"conversation_id\": \"$conv_id\", \"agent\": \"$agent\""
  else
    echo -e "  ${RED}✗ Création failed HTTP $http_code${NC} (Beta API may not be available yet)"
  fi
  log "conversations_create agent=$agent http=$http_code"
}

# ============================================================================
# 9. LIBRARIES (Document Library RAG — Beta)
# ============================================================================

action_libraries_list() {
  echo -e "\n${BOLD}${CYAN}[Libraries — Liste (Beta)]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/libraries")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
libs = d.get('data', [])
if not libs:
    print('  (aucune library)')
else:
    for l in libs:
        print(f'  {l.get(\"id\",\"?\"):36} {l.get(\"name\",\"?\"):30} docs={l.get(\"document_count\",0)}')
print(f'\n  Total: {len(libs)} libraries')
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC} (Beta API may not be available yet)"
  fi
  log "libraries_list http=$http_code"
}

action_libraries_create() {
  local name="$1" description="${2:-}"
  echo -e "\n${BOLD}${CYAN}[Libraries — Créer (Beta)]${NC}"
  check_api_key || return 1

  echo -e "  Name: $name"
  [ -n "$description" ] && echo -e "  Description: $description"

  local payload
  payload=$(python3 -c "
import json
d = {'name': '''$name'''}
desc = '''$description'''
if desc:
    d['description'] = desc
print(json.dumps(d))
" 2>/dev/null)

  local response
  response=$(api_call POST "/libraries" "$payload")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    local lib_id
    lib_id=$(echo "$body" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
    echo -e "  ${GREEN}✓ Library créée${NC} — ID: $lib_id"
    log_json "libraries" "create" "success" "\"library_id\": \"$lib_id\", \"name\": \"$name\""
  else
    echo -e "  ${RED}✗ Création failed HTTP $http_code${NC}"
  fi
  log "libraries_create name=$name http=$http_code"
}

action_libraries_add_doc() {
  local library_id="$1" file_id="$2"
  echo -e "\n${BOLD}${CYAN}[Libraries — Ajouter Document]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call POST "/libraries/$library_id/documents" "{\"file_id\":\"$file_id\"}")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ Document ajouté${NC}"
    log_json "libraries" "add_document" "success" "\"library_id\": \"$library_id\", \"file_id\": \"$file_id\""
  else
    echo -e "  ${RED}✗ Ajout failed HTTP $http_code${NC}"
  fi
  log "libraries_add_doc lib=$library_id file=$file_id http=$http_code"
}

# ============================================================================
# 10. MODELS CATALOG
# ============================================================================

action_models_list() {
  echo -e "\n${BOLD}${CYAN}[Modèles — Catalogue]${NC}"
  check_api_key || return 1

  local response
  response=$(api_call GET "/models")
  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [ "$http_code" = "200" ]; then
    python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
models = sorted(d.get('data', []), key=lambda m: m.get('id', ''))
ft_models = [m for m in models if m.get('id','').startswith('ft:')]
base_models = [m for m in models if not m.get('id','').startswith('ft:')]

print('  === Base Models ===')
for m in base_models:
    print(f'  {m[\"id\"]:45} owner={m.get(\"owned_by\",\"?\")}')
print(f'  Total: {len(base_models)} base models')

if ft_models:
    print('\n  === Fine-tuned Models ===')
    for m in ft_models:
        print(f'  {m[\"id\"]:45} owner={m.get(\"owned_by\",\"?\")}')
    print(f'  Total: {len(ft_models)} fine-tuned')
" <<< "$body" 2>/dev/null
  else
    echo -e "  ${RED}Erreur HTTP $http_code${NC}"
  fi
  log "models_list http=$http_code"
}

# ============================================================================
# 11. LOGS
# ============================================================================

action_logs_view() {
  echo -e "\n${BOLD}${CYAN}[Logs — Derniers]${NC}"
  if [ -f "$LOG_FILE" ]; then
    tail -20 "$LOG_FILE"
  else
    echo "  (aucun log)"
  fi
  echo -e "\n  Log dir: $LOG_DIR"
  echo -e "  Fichiers: $(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l) logs"
}

action_logs_purge() {
  echo -e "\n${BOLD}${CYAN}[Logs — Purge]${NC}"
  local count
  count=$(find "$LOG_DIR" -name "*.log" -mtime +7 2>/dev/null | wc -l)
  find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
  echo -e "  ${GREEN}✓ $count logs supprimés (>7 jours)${NC}"
  log "logs_purge deleted=$count"
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

show_menu() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║   Mistral AI Studio — TUI Cockpit (Lot 24)              ║${NC}"
  echo -e "${BOLD}${CYAN}║   $(date '+%Y-%m-%d %H:%M')  API: $API_MODE                              ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}  Agents${NC}"
  echo "  1) Agents — status          2) Agents — chat"
  echo ""
  echo -e "${BOLD}  Conversations (Beta)${NC}"
  echo "  3) Conversations — lister   4) Conversation — créer"
  echo ""
  echo -e "${BOLD}  Fichiers & Libraries${NC}"
  echo "  5) Fichiers — lister        6) Fichiers — uploader"
  echo "  7) Libraries — lister       8) Library — créer"
  echo "  9) Library — ajouter doc"
  echo ""
  echo -e "${BOLD}  Fine-tune${NC}"
  echo "  10) Jobs — lister           11) Job — créer"
  echo "  12) Modèles personnalisés   13) Catalogue complet"
  echo ""
  echo -e "${BOLD}  Batches${NC}"
  echo "  14) Batches — lister"
  echo ""
  echo -e "${BOLD}  IA${NC}"
  echo "  15) IA Documentaire — OCR   16) Audio — transcrire"
  echo "  17) Codestral — complétion"
  echo ""
  echo -e "${BOLD}  Maintenance${NC}"
  echo "  18) Logs — voir             19) Logs — purger"
  echo "  20) Health check complet"
  echo ""
  echo "  q) Quitter"
  echo ""
}

action_health_full() {
  echo -e "\n${BOLD}${CYAN}[Health Check Complet — Mistral Studio (API: $API_MODE)]${NC}"
  check_api_key || return 1

  action_agents_status
  action_files_list
  action_finetune_list
  action_finetune_models
  action_batches_list
  action_libraries_list
  action_conversations_list

  echo ""
  log_json "studio" "full-health" "completed" "\"api_mode\": \"$API_MODE\""
}

# ============================================================================
# MAIN
# ============================================================================

# CLI mode
case "${1:-}" in
  --agents-status) action_agents_status ;;
  --agents-chat) action_agents_chat "${2:-sentinelle}" ;;
  --conversations-list) action_conversations_list ;;
  --conversations-create) action_conversations_create "${2:-sentinelle}" ;;
  --files-list) action_files_list ;;
  --files-upload) action_files_upload "${2:?filepath required}" "${3:-fine-tune}" ;;
  --libraries-list) action_libraries_list ;;
  --libraries-create) action_libraries_create "${2:?name required}" "${3:-}" ;;
  --libraries-add-doc) action_libraries_add_doc "${2:?library_id required}" "${3:?file_id required}" ;;
  --finetune-list) action_finetune_list ;;
  --finetune-create) action_finetune_create "${2:?model}" "${3:?training_file}" "${4:-v1}" ;;
  --finetune-models) action_finetune_models ;;
  --models-list) action_models_list ;;
  --batches-list) action_batches_list ;;
  --ocr) action_docai_ocr "${2:?filepath required}" ;;
  --transcribe) action_audio_transcribe "${2:?filepath required}" ;;
  --codestral) action_codestral_complete "${2:?prompt}" "${3:-}" ;;
  --health) action_health_full ;;
  --logs) action_logs_view ;;
  --purge-logs) action_logs_purge ;;
  --json) action_health_full 2>/dev/null | grep -A 999 '{' ;;
  --api-mode) API_MODE="${2:-beta}"; shift ;;&
  --help|-h)
    echo "Usage: $0 [action] [args]"
    echo ""
    echo "  Agents:"
    echo "  --agents-status                 Status de tous les agents"
    echo "  --agents-chat [name]            Chat interactif avec un agent"
    echo ""
    echo "  Conversations (Beta API):"
    echo "  --conversations-list            Lister les conversations"
    echo "  --conversations-create [agent]  Créer une conversation"
    echo ""
    echo "  Fichiers:"
    echo "  --files-list                    Lister les fichiers"
    echo "  --files-upload FILE [purpose]   Uploader un fichier"
    echo ""
    echo "  Libraries (Beta — Document RAG):"
    echo "  --libraries-list                Lister les document libraries"
    echo "  --libraries-create NAME [desc]  Créer une library"
    echo "  --libraries-add-doc LIB FILE    Ajouter un document à une library"
    echo ""
    echo "  Fine-tune:"
    echo "  --finetune-list                 Lister les jobs fine-tune"
    echo "  --finetune-create MODEL FILE    Créer un job fine-tune"
    echo "  --finetune-models               Lister les modèles fine-tunés"
    echo "  --models-list                   Catalogue complet des modèles"
    echo ""
    echo "  Batches / IA:"
    echo "  --batches-list                  Lister les batches"
    echo "  --ocr FILE                      OCR d'un document"
    echo "  --transcribe FILE               Transcrire un audio"
    echo "  --codestral PROMPT              Complétion Codestral"
    echo ""
    echo "  Maintenance:"
    echo "  --health                        Health check complet"
    echo "  --logs                          Voir les logs"
    echo "  --purge-logs                    Purger logs >7j"
    echo ""
    echo "  Options globales:"
    echo "  --api-mode beta|deprecated      Mode API (défaut: beta)"
    echo ""
    ;;
  "")
    # Mode interactif
    while true; do
      show_menu
      echo -ne "${GREEN}Choix> ${NC}"
      read -r choice
      case "$choice" in
        1) action_agents_status ;;
        2) echo -ne "Agent (sentinelle/tower/forge/devstral): "; read -r a; action_agents_chat "$a" ;;
        3) action_conversations_list ;;
        4) echo -ne "Agent (sentinelle/tower/forge/devstral): "; read -r a; action_conversations_create "$a" ;;
        5) action_files_list ;;
        6) echo -ne "Chemin fichier: "; read -r f; echo -ne "Purpose (fine-tune/batch/ocr): "; read -r p; action_files_upload "$f" "${p:-fine-tune}" ;;
        7) action_libraries_list ;;
        8) echo -ne "Nom library: "; read -r n; echo -ne "Description: "; read -r d; action_libraries_create "$n" "$d" ;;
        9) echo -ne "Library ID: "; read -r lid; echo -ne "File ID: "; read -r fid; action_libraries_add_doc "$lid" "$fid" ;;
        10) action_finetune_list ;;
        11) echo -ne "Modèle (open-mistral-7b/mistral-small-latest): "; read -r m; echo -ne "Training file ID: "; read -r tf; action_finetune_create "$m" "$tf" ;;
        12) action_finetune_models ;;
        13) action_models_list ;;
        14) action_batches_list ;;
        15) echo -ne "Chemin document: "; read -r f; action_docai_ocr "$f" ;;
        16) echo -ne "Chemin audio: "; read -r f; action_audio_transcribe "$f" ;;
        17) echo -ne "Prompt code: "; read -r p; action_codestral_complete "$p" ;;
        18) action_logs_view ;;
        19) action_logs_purge ;;
        20) action_health_full ;;
        q|Q) echo "Au revoir."; exit 0 ;;
        *) echo -e "${RED}Choix invalide${NC}" ;;
      esac
    done
    ;;
  *)
    echo "Action inconnue: $1 — utiliser --help"
    exit 1
    ;;
esac
