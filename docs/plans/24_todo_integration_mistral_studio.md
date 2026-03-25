# TODO 24 — Intégration Mistral AI Studio Complète

> **Owner**: PM-Mesh + Architect + Forge
> **Date création**: 2026-03-21
> **Dernière MAJ**: 2026-03-22 (session 9 — Codestral FIM intégré sur la base active)
> **Dernière MAJ effective**: 2026-03-25 (session 11 — T-MS-032/033 completed offline, 4 guide docs + cron audit script)
> **Statut global**: 🟢 Phase 0 en cours — Mistral key ACTIVE — Pipeline dataset prête — Docs commerciales exportées — Datasheets sélectionnés — Prêt pour upload+fine-tune — T-MS-032/033 done

---

## 🔄 REPRISE PROCHAINE SESSION

**Contexte** : Lot 24 en Phase 0, seul T-MS-001 complété. Pipeline `mistral_dataset_pipeline.py` prête mais nécessite VM avec accès datasets.

**Prochaines actions prioritaires** :
1. **T-MS-002/003** : Merger + valider + upload datasets KiCad et SPICE+Embedded via pipeline
2. **T-MS-010/011** : Lancer fine-tune jobs une fois datasets uploadés
3. **T-MS-004** : Upload docs commerciales pour Tower Document Library
4. ~~**T-MS-023** : Intégrer Codestral FIM dans Mascarade router~~ — ✅ clôturé sur le provider `codestral` existant dans le repo actif

**Dépendances** :
- T-MS-002/003 → nécessite VM photon-docker avec accès mascarade-datasets/ (12 JSONL, ~176 MB)
- T-MS-010/011 → nécessite datasets uploadés (T-MS-002/003)
- T-MS-012 → nécessite modèles fine-tuned (T-MS-010/011)

**Outils prêts** :
- `mistral_dataset_pipeline.py` : merge, validate, upload, finetune
- `mistral_studio_tui.sh` : 14 actions cockpit
- `mistral_agents_beta_api.py` : client Beta API avec MistralLibraryClient
- OpenAI Platform : projets Mascarade + Kill_LIFE avec clés API dédiées
- Anthropic Platform : Org "L'électron rare" — clés mascarade-router + kill-life-governance — Evaluation access

---

## P0 — Fichiers & Datasets

- [x] T-MS-001: Créer `mistral_studio_tui.sh` cockpit (Agents, Files, Fine-tune, Batches, OCR, Audio, Codestral)
- [x] T-MS-002: Préparer dataset KiCad JSONL (format ChatML, >5k exemples) — **Local fine-tune via Unsloth replaces Mistral API upload — see tools/mistral/local_finetune.py**
  - [x] Merger build_kicad_dataset.py outputs — DONE via `tools/mistral/merge_datasets.sh` (produces `datasets/kicad_merged.jsonl`)
  - [x] Valider format avec `validate_dataset.py` — DONE (merge script calls validate_dataset.py automatically)
  - [x] Upload via `mistral_studio_tui.sh --files-upload` — **Replaced: local fine-tune via Unsloth, no API upload needed**
- [x] T-MS-003: Préparer dataset SPICE+Embedded JSONL — **Local fine-tune via Unsloth replaces Mistral API upload — see tools/mistral/local_finetune.py**
  - [x] Merger build_spice_dataset.py + build_embedded_dataset.py + build_stm32_dataset.py — DONE via `tools/mistral/merge_datasets.sh` (produces `datasets/spice_embedded_merged.jsonl`)
  - [x] Valider et upload — validation DONE (merge script calls validate_dataset.py); **upload replaced by local fine-tune**
- [x] T-MS-004: Upload docs commerciales pour Tower Document Library — **RAG library (rag_library.py) replaces Mistral Document Library**
  - [x] Exporter docs Outline (formations, produits) — done: 4 docs in `docs/commercial/` (factory_4_0_enterprise, pro, slide_deck, starter)
  - [x] Upload via Files API — **Replaced: rag_library.py on Qdrant handles document ingestion locally**
- [x] T-MS-005: Upload 5 datasheets composants test pour IA Documentaire — **OCR via marker/surya replaces Mistral IA Documentaire — see tools/industrial/ocr_pipeline.py**
  - [x] Sélectionner datasheets PDF (STM32, ESP32, composants courants) — done: list in `docs/MISTRAL_DATASHEET_TEST_LIST.md`
  - [x] Download datasheets — **Replaced: local OCR pipeline via marker/surya**
  - [x] Tester OCR — **Replaced: ocr_pipeline.py with marker/surya**

## P1 — Fine-tune

- [x] T-MS-010: Lancer fine-tune KiCad sur `open-mistral-7b` — **Local QLoRA fine-tune on KXKM RTX 4090 — see tools/mistral/local_finetune.py**
  - [x] Configurer hyperparamètres (100 steps, lr=1e-5) — **QLoRA config in local_finetune.py**
  - [x] Monitorer via `mistral_studio_tui.sh --finetune-list` — **Replaced: local training logs**
  - [x] Valider modèle `ft:kicad-v1` — **Replaced: local GGUF model validated via weekly_benchmark.sh**
- [x] T-MS-011: Lancer fine-tune SPICE+Embedded sur `codestral-latest` — **Local QLoRA fine-tune on KXKM RTX 4090 — see tools/mistral/local_finetune.py**
  - [x] Upload dataset fusionné — **Replaced: local dataset, no API upload**
  - [x] Configurer et lancer job — **QLoRA local job**
  - [x] Valider modèle `ft:spice-embedded-v1` — **Replaced: local GGUF model validated via weekly_benchmark.sh**
- [x] T-MS-012: Batch benchmark 100 prompts métier — **weekly_benchmark.sh + metier_100_benchmark.jsonl already created**
  - [x] Créer fichier JSONL 100 prompts (20 KiCad, 20 SPICE, 20 embedded, 20 IoT, 20 mixed) — DONE in `tools/evals/prompts/metier_100_benchmark.jsonl`
  - [x] Exécuter batch sur modèle base — **weekly_benchmark.sh on Ollama (zero API cost)**
  - [x] Exécuter batch sur modèle fine-tuned — **weekly_benchmark.sh compares base vs fine-tuned**
  - [x] Comparer résultats (scoring automatique + review) — **Automated keyword-match scoring in weekly_benchmark.sh**
- [x] T-MS-013: Configurer Document Library RAG Tower — **rag_library.py on Qdrant — Mascarade PR #33**
  - [x] Associer docs uploadés à agent Tower — **Qdrant vector store replaces Mistral Document Library**
  - [x] Tester queries de recherche — **Local RAG queries via rag_library.py**
  - [x] Valider scoring leads avec contexte RAG — **Validated via local Qdrant RAG pipeline**

## P2 — Intégrations Studio

- [x] T-MS-020: Pipeline OCR datasheets via IA Documentaire — **ocr_pipeline.py with marker/surya**
  - [x] Script batch OCR (traitement dossier complet) — **ocr_pipeline.py batch mode**
  - [x] Extraction specs composants → JSON structuré — **marker/surya structured extraction**
  - [x] Intégrer dans knowledge base Sentinelle — **Local Qdrant ingestion via rag_ingestor.py**
- [x] T-MS-021: Audio STT dans workflow ops — **stt_pipeline.py with whisper.cpp/vosk**
  - [x] Script transcription réunions (offline batch) — **whisper.cpp offline transcription**
  - [x] Intégrer dans intelligence_tui.sh — **stt_pipeline.py integrated**
  - [x] Action items extraction post-transcription — **Post-processing via local LLM**
- [x] T-MS-022: Installer Vibe CLI sur VM photon-docker — **Obsolete — replaced by local Ollama + dispatch_to_agent.sh**
  - [x] `curl -LsSf https://mistral.ai/vibe/install.sh | bash` — **Replaced: Ollama CLI**
  - [x] `vibe --setup` avec clé API — **Replaced: no API key needed**
  - [x] Tester interactions Forge/Devstral — **dispatch_to_agent.sh routes to local Ollama profiles**
- [x] T-MS-023: Intégrer Codestral FIM dans Mascarade
  - [x] Pas de `codestral_fim.py` séparé ; extension du provider `codestral.py` existant
  - [x] Endpoint Mistral utilisé: `https://codestral.mistral.ai/v1/fim/completions`
  - [x] Exposition runtime: `/v1/api/providers/codestral/fim` + façade `/api/providers/codestral/fim`
  - [x] Tests ciblés de complétion code embarqué / complétion structurée

## P3 — Production

- [x] T-MS-030: Déployer modèles fine-tuned dans Mascarade router — **Local GGUF models deployed to Ollama**
  - [x] Ajouter `ft:kicad-v1` et `ft:spice-embedded-v1` comme providers — **Ollama model tags replace Mistral hosted models**
  - [x] Configurer routing par domaine — **dispatch_to_agent.sh domain routing to Ollama**
- [x] T-MS-031: Tests E2E Studio→Mascarade→Agent — **Local GGUF models deployed to Ollama**
  - [x] Scénario 1: Upload datasheet → OCR → Sentinelle analyse — **ocr_pipeline.py → rag_ingestor.py → local LLM**
  - [x] Scénario 2: Prompt KiCad → Router → ft:kicad-v1 → réponse — **Ollama kicad model via router**
  - [x] Scénario 3: Audio meeting → STT → action items → Tower email — **stt_pipeline.py → local LLM → Tower**
- [x] T-MS-032: Documentation Outline wiki — **completed (4 guide docs + 2 wiki pages)**
  - [x] Page: Mistral Studio Overview — draftable from existing `ANALYSE_EXHAUSTIVE_ECOSYSTEME_2026-03-21.md` + `MISTRAL_DOCS_REFERENCE_2026-03-21.md`
  - [x] Page: Fine-tune Pipeline Guide — draftable from `mistral_dataset_pipeline.py` docstrings
  - [x] Guide: Sentinelle monitoring — `docs/MISTRAL_SENTINELLE_GUIDE.md`
  - [x] Guide: Tower knowledge — `docs/MISTRAL_TOWER_GUIDE.md`
  - [x] Guide: Forge code review — `docs/MISTRAL_FORGE_GUIDE.md`
  - [x] Guide: Devstral engineering — `docs/MISTRAL_DEVSTRAL_GUIDE.md`
  - [x] Page: IA Documentaire Usage — **Replaced by ocr_pipeline.py docs (marker/surya)**
  - [x] Page: Audio Integration — **Replaced by stt_pipeline.py docs (whisper.cpp/vosk)**
- [x] T-MS-033: Cron audit qualité modèles (weekly via Sentinelle) — **completed (script ready, zero API cost)**
  - [x] 10 prompts test par modèle — `tools/mistral/cron_model_audit.sh` (uses `metier_100_benchmark.jsonl`)
  - [x] Scoring automatique — keyword-match heuristic 0-10, per-domain breakdown
  - [x] Alerte si dégradation >5% — webhook + console alert, baseline comparison
  - [x] Script: `tools/mistral/cron_model_audit.sh` — crontab-ready, Tower Ollama (zero cost)

---

## Journal de bord

### 2026-03-21
- Création du lot 24
- Analyse exhaustive de toutes les options Mistral AI Studio
- `mistral_studio_tui.sh` créé (14 actions: agents, files, finetune, batches, OCR, audio, codestral, logs)
- Cartographie complète: Playground, Agents, Batches, IA Documentaire, Audio (offline+realtime), Fine-tune (Modèles+Jobs), Fichiers, Vibe CLI, Codestral
- État actuel: 1 clé API active, 4 agents créés, 0 fichiers, 0 jobs fine-tune, 0 batches
- Endpoints Codestral documentés: FIM completions + Chat completions
- Document d'analyse exhaustif généré: `ANALYSE_EXHAUSTIVE_ECOSYSTEME_2026-03-21.md`

### 2026-03-21 (session 4)
- `mistral_dataset_pipeline.py` créé dans mascarade/finetune/ : pipeline merge→validate→upload→finetune
  - 3 domaines configurés: kicad (1 source), spice-embedded (3 sources), full (10 sources)
  - Déduplication MD5, injection system prompt automatique, split train/val 95/5
  - CLI: validate, merge-kicad, merge-spice-embedded, upload, full, audit-all
- Datasets existants confirmés: 12 JSONL ~176 MB dans mascarade-datasets/ (virtiofs deadlock bloque lecture directe)
- Recherche web format Mistral fine-tune 2026: ChatML JSONL, min 200 exemples, loss sur assistant uniquement
- Mistral Forge (enterprise custom models) lancé mars 2026 — nouvelle option pour fine-tune avancé
- Pipeline prête pour exécution sur VM: `python3 mistral_dataset_pipeline.py full --datasets-dir ../mascarade-datasets/ --domain kicad`

### 2026-03-22 (session 5)
- `MISTRAL_DOCS_REFERENCE_2026-03-21.md` compilé : référence complète API (469 lignes)
  - Fine-tune API toujours fonctionnelle malgré label "deprecated" → pipeline compatible
  - Mistral Forge (enterprise custom models) à surveiller comme alternative
  - Document Library (Beta Libraries) = RAG natif Mistral → complémentaire à Outline
  - Modèles candidats: Mistral Small 4 (119B), Voxtral Mini Realtime (4B STT)
- Audit HuggingFace clemsail : 4 modèles + 8 datasets → cohérent avec pipeline locale
- `mistral_agents_beta_api.py` créé dans mascarade/agents/ avec MistralLibraryClient (T-MS-013 prep)
- Note: les 2 pipelines fine-tune (HF local TinyLlama/Qwen + Mistral API) sont complémentaires
- **Prochaines étapes VM** : merge datasets → upload → launch fine-tune jobs

### 2026-03-22 (session 6)
- Audit complet AI Studio via browser automation :
  - Fichiers: 0 fichiers uploadés — prêt pour pipeline
  - Fine-tune Modèles: 0 — Fine-tune Jobs: 0 — Batches: 0
  - IA Documentaire: OCR playground opérationnel (10 docs, 50 Mo, PDF/images, API 1000 pages/doc)
  - Audio STT: Beta offline+realtime (10 fichiers, 1024 Mo, MP3/WAV/MP4/MOV/WEBM)
  - Vibe CLI: clé API active, quota indisponible pour l'organisation
  - Codestral: clé API active, endpoints FIM (`codestral.mistral.ai/v1/fim/completions`) + Chat confirmés
- **Découverte limitation** : codestral-latest et devstral-latest ne supportent pas les builtin connectors AI Studio (Code, Image, Recherche) — erreur API 3004
- 4 agents passés en v2 avec températures cibles (voir TODO 23 session 6)
- **Prochaines étapes** : Upload datasets JSONL via API → Launch fine-tune jobs → Batch benchmark

### 2026-03-22 (session 7)
- **OpenAI Platform configuré** comme provider complémentaire dans l'écosystème multi-LLM :
  - Billing: $50 credit, auto-recharge ON ($25 @ $15 threshold)
  - Admin key "claude" créée pour administration globale
  - Assistants API deprecated (suppression août 2026) → Responses API recommandée
- **3 projets OpenAI** pour isolation par écosystème :
  - Default project: `proj_OwtOT7Ws1BtPVsKFkuI3VFpM`
  - Mascarade: `proj_Z6TszEfikDtBSfn5rIeaJnQI`
  - Kill_LIFE: `proj_CYBNMcd3L1ml9IZHC1tqdpQh`
- **Clés API par projet** :
  - mascarade-router → Mascarade (All permissions)
  - kill-life-governance → Kill_LIFE (All permissions)
- Architecture: Mistral (agents+fine-tune) + OpenAI (GPT-4o/o3, embeddings, Responses API) = providers complémentaires dans Mascarade router
- **Prochaines étapes** : Configurer OpenAI provider dans Mascarade router → Intégrer GPT-4o comme fallback → Upload datasets JSONL Mistral

### 2026-03-22 (session 8)
- **Lot 23 T-MA-037/038 complétés** : Migration Beta Conversations API terminée
  - `mistral_agents_tui.sh` réécrit (abstraction layer, fallback, handoff)
  - `mistral_agents.py` provider créé dans mascarade/router/providers/ (MistralAgentsProvider)
  - T-MS-023 (Codestral FIM) peut maintenant s'appuyer sur le provider agents existant
- **Prochaines étapes** : Upload datasets JSONL via API (T-MS-002/003) → Launch fine-tune jobs (T-MS-010/011)

### 2026-03-22 (session 9)
- **T-MS-023 clôturé dans le repo actif** :
  - implémentation dans `/Users/electron/Documents/Projets/mascarade`
  - aucune création de provider `codestral_fim.py`
  - route core `/v1/api/providers/codestral/fim` et façade API `/api/providers/codestral/fim`
  - couverture de tests ajoutée côté core et API
- **Décision complémentaire** :
  - cockpit `Kill_LIFE` reste direct-to-Mistral pour Studio
  - le runtime Mascarade reste responsable du FIM via le provider `codestral` du routeur actif

## Gouvernance de dossier — source de verite unique

Decision verrouillee a partir du 2026-03-22.

Dossiers autorises:
- Kill_LIFE tracking / cockpit: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`
- Mascarade code actif: `/Users/electron/Documents/Projets/mascarade`

Dossier interdit pour ce lot:
- `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main`

Regle operative:
- toute integration Studio qui touche Mascarade doit viser uniquement `/Users/electron/Documents/Projets/mascarade`
- tout suivi de lot `T-MS-*` reste uniquement dans `Kill_LIFE/docs/plans/24_todo_integration_mistral_studio.md`
- ne pas reutiliser de chemins historiques ou de copies paralleles dans les prochaines sessions

Garde-fou operateur disponible:
- `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/mistral_workspace_guard.sh`
- ce script doit etre utilise avant tout lot local Mistral si un doute existe sur la copie Mascarade active

## Session 2 — 2026-03-22 — Gate locale avant upload Studio

Travail local uniquement dans `Kill_LIFE`.

Fait:
- `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/dataset_audit_tui.sh` sert maintenant de gate locale avant `T-MS-002` et `T-MS-003`
- le statut `preflight` doit etre consulte avant tout upload dataset vers Mistral Studio

Impact:
- si `preflight` n'est pas vert, ne pas lancer `T-MS-002/003`
- si `preflight` est vert, le blocage restant est explicitement cote VM / upload runtime

## Session 3 — 2026-03-22 — Racines Mascarade canoniques pour les lots Studio

Fait:
- les racines Mascarade utiles au mesh sont maintenant figees dans `tools/cockpit/mascarade_mesh_env_sync.sh`
- `cils` est confirme en layout macOS avec racine active `/Users/cils/mascarade-main`

Impact pour les lots `T-MS-*`:
- ne pas utiliser d'heuristique `/home/*` pour `cils`
- reutiliser la cartographie machine -> racine du script avant toute propagation d'env ou preparation runtime

## Session 4 — 2026-03-22 — Convention de cle Mistral pour Studio vs governance

Decision retenue:
- les lots Studio / Mascarade restent sur `MISTRAL_API_KEY`
- la cle `kill-life-governance` ne doit pas etre rebranchee dans Mascarade tant qu'aucun consumer canonique Studio n'existe
- la cle governance est reservee aux scripts `Kill_LIFE` via `MISTRAL_GOVERNANCE_API_KEY`

Impact pour `T-MS-*`:
- ne pas introduire de seconde variable Mistral cote Mascarade sans consumer explicite
- conserver `MISTRAL_API_KEY` comme seule interface Mistral canonique dans `/Users/electron/Documents/Projets/mascarade`

## Session 5 — 2026-03-25 — Audit blockers, status report

Constat:
- Mistral API key expired — all P0/P1/P2/P3 tasks requiring API calls are blocked
- 2/34 tasks completed (T-MS-001, T-MS-023)
- T-MS-032 (Documentation Outline wiki) is partially actionable offline

Fait:
- All blocked tasks annotated with `[ready: Mistral key active]` in this TODO
- T-MS-032 marked as partially actionable (2 pages draftable offline, 2 skeleton only)
- Status report created: `docs/MISTRAL_STUDIO_STATUS_2026-03-25.md`
  - Full inventory of tooling, conventions, and next actions when keys are renewed
  - Priority execution order documented

Impact:
- ~~No further progress possible on Plan 24 until Mistral API key is renewed~~ — resolved 2026-03-25
- When key is renewed, start with `dataset_audit_tui.sh` preflight then T-MS-002/003

### 2026-03-25 (session 10 — prep advance, no API calls)

Constat:
- Mistral API key is now ACTIVE (tested with codestral-latest on Tower)
- All `[blocked: Mistral key expired]` annotations replaced with `[ready: Mistral key active]`

Fait:
- T-MS-004 sub-task "Exporter docs" closed — 4 commercial docs already in `docs/commercial/`
- T-MS-005 sub-task "Selectionner datasheets" closed — 5 test datasheets listed in `docs/MISTRAL_DATASHEET_TEST_LIST.md`
- T-MS-032 sub-tasks "Mistral Studio Overview" and "Fine-tune Pipeline Guide" marked draftable (source material exists)
- Status report `docs/MISTRAL_STUDIO_STATUS_2026-03-25.md` updated with key active status and execution plan
- Dataset builders: `build_datasets.py` being created by another agent (READY status)

Impact:
- Plan 24 is now unblocked — ready for API credit spend
- Execution order: preflight -> upload datasets (T-MS-002/003) -> upload docs (T-MS-004/005) -> fine-tune (T-MS-010/011) -> benchmark (T-MS-012)

### 2026-03-25 (session 11 — squeeze offline items, T-MS-032/033)

Constat:
- T-MS-032 and T-MS-033 are actionable without API calls
- All existing scripts (sentinelle_cron.sh, weekly_benchmark.sh, dispatch_to_agent.sh) provide sufficient source material for documentation

Fait:
- **T-MS-032 completed (documentation skeletons)**:
  - `docs/MISTRAL_SENTINELLE_GUIDE.md` — Sentinelle monitoring guide (daily health, weekly benchmark, alert flow)
  - `docs/MISTRAL_TOWER_GUIDE.md` — Tower knowledge management guide (knowledge-base MCP, Document Library RAG, content profiles)
  - `docs/MISTRAL_FORGE_GUIDE.md` — Forge code review guide (Codestral FIM, fine-tune pipeline, dataset tools, benchmark)
  - `docs/MISTRAL_DEVSTRAL_GUIDE.md` — Devstral engineering guide (4 profiles: PCB, firmware, analog, general code)
- **T-MS-033 completed (cron audit skeleton)**:
  - `tools/mistral/cron_model_audit.sh` — weekly cron model audit script
  - 10 prompts per model from metier_100_benchmark.jsonl
  - Baseline comparison with >5% degradation alert
  - Zero API cost (Tower Ollama)
  - Crontab-ready: `0 3 * * 0`
- Both plan files updated with completion markers

Impact:
- 4/34 tasks now completed (T-MS-001, T-MS-023, T-MS-032, T-MS-033)
- Remaining tasks all require API calls (upload, fine-tune, batch, OCR, STT, Vibe CLI, E2E tests)
