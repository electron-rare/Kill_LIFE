# TODO 24 — Intégration Mistral AI Studio Complète

> **Owner**: PM-Mesh + Architect + Forge
> **Date création**: 2026-03-21
> **Dernière MAJ**: 2026-03-22 (session 9 — Codestral FIM intégré sur la base active)
> **Statut global**: 🟢 Phase 0 en cours — Pipeline dataset prête — Docs reference compilée — Audit Studio complet — OpenAI Platform ready

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
- [ ] T-MS-002: Préparer dataset KiCad JSONL (format ChatML, >5k exemples) — [blocked: Mistral key expired]
  - [ ] Merger build_kicad_dataset.py outputs
  - [ ] Valider format avec `training/scripts/validate_dataset.py`
  - [ ] Upload via `mistral_studio_tui.sh --files-upload`
- [ ] T-MS-003: Préparer dataset SPICE+Embedded JSONL — [blocked: Mistral key expired]
  - [ ] Merger build_spice_dataset.py + build_embedded_dataset.py + build_stm32_dataset.py
  - [ ] Valider et upload
- [ ] T-MS-004: Upload docs commerciales pour Tower Document Library — [blocked: Mistral key expired]
  - [ ] Exporter docs Outline (formations, produits)
  - [ ] Upload via Files API
- [ ] T-MS-005: Upload 5 datasheets composants test pour IA Documentaire — [blocked: Mistral key expired]
  - [ ] Sélectionner datasheets PDF (STM32, ESP32, composants courants)
  - [ ] Tester OCR via `mistral_studio_tui.sh --ocr`

## P1 — Fine-tune

- [ ] T-MS-010: Lancer fine-tune KiCad sur `open-mistral-7b` — [blocked: Mistral key expired] + depends T-MS-002
  - [ ] Configurer hyperparamètres (100 steps, lr=1e-5)
  - [ ] Monitorer via `mistral_studio_tui.sh --finetune-list`
  - [ ] Valider modèle `ft:kicad-v1`
- [ ] T-MS-011: Lancer fine-tune SPICE+Embedded sur `codestral-latest` — [blocked: Mistral key expired] + depends T-MS-003
  - [ ] Upload dataset fusionné
  - [ ] Configurer et lancer job
  - [ ] Valider modèle `ft:spice-embedded-v1`
- [ ] T-MS-012: Batch benchmark 100 prompts métier — [blocked: Mistral key expired] + depends T-MS-010/011
  - [ ] Créer fichier JSONL 100 prompts (20 KiCad, 20 SPICE, 20 embedded, 20 IoT, 20 mixed)
  - [ ] Exécuter batch sur modèle base
  - [ ] Exécuter batch sur modèle fine-tuned
  - [ ] Comparer résultats (scoring automatique + review)
- [ ] T-MS-013: Configurer Document Library RAG Tower — [blocked: Mistral key expired] + depends T-MS-004
  - [ ] Associer docs uploadés à agent Tower
  - [ ] Tester queries de recherche
  - [ ] Valider scoring leads avec contexte RAG

## P2 — Intégrations Studio

- [ ] T-MS-020: Pipeline OCR datasheets via IA Documentaire — [blocked: Mistral key expired]
  - [ ] Script batch OCR (traitement dossier complet)
  - [ ] Extraction specs composants → JSON structuré
  - [ ] Intégrer dans knowledge base Sentinelle
- [ ] T-MS-021: Audio STT dans workflow ops — [blocked: Mistral key expired]
  - [ ] Script transcription réunions (offline batch)
  - [ ] Intégrer dans intelligence_tui.sh
  - [ ] Action items extraction post-transcription
- [ ] T-MS-022: Installer Vibe CLI sur VM photon-docker — [blocked: Mistral key expired]
  - [ ] `curl -LsSf https://mistral.ai/vibe/install.sh | bash`
  - [ ] `vibe --setup` avec clé API
  - [ ] Tester interactions Forge/Devstral
- [x] T-MS-023: Intégrer Codestral FIM dans Mascarade
  - [x] Pas de `codestral_fim.py` séparé ; extension du provider `codestral.py` existant
  - [x] Endpoint Mistral utilisé: `https://codestral.mistral.ai/v1/fim/completions`
  - [x] Exposition runtime: `/v1/api/providers/codestral/fim` + façade `/api/providers/codestral/fim`
  - [x] Tests ciblés de complétion code embarqué / complétion structurée

## P3 — Production

- [ ] T-MS-030: Déployer modèles fine-tuned dans Mascarade router — [blocked: Mistral key expired] + depends T-MS-010/011
  - [ ] Ajouter `ft:kicad-v1` et `ft:spice-embedded-v1` comme providers
  - [ ] Configurer routing par domaine
- [ ] T-MS-031: Tests E2E Studio→Mascarade→Agent — [blocked: Mistral key expired] + depends T-MS-030
  - [ ] Scénario 1: Upload datasheet → OCR → Sentinelle analyse
  - [ ] Scénario 2: Prompt KiCad → Router → ft:kicad-v1 → réponse
  - [ ] Scénario 3: Audio meeting → STT → action items → Tower email
- [ ] T-MS-032: Documentation Outline wiki — **actionable offline (partial)**
  - [ ] Page: Mistral Studio Overview — can draft from existing analysis docs
  - [ ] Page: Fine-tune Pipeline Guide — can draft from pipeline docstrings
  - [ ] Page: IA Documentaire Usage — skeleton only [blocked: needs OCR test results]
  - [ ] Page: Audio Integration — skeleton only [blocked: needs STT test results]
- [ ] T-MS-033: Cron audit qualité modèles (weekly via Sentinelle) — [blocked: Mistral key expired] + depends T-MS-030
  - [ ] 10 prompts test par modèle
  - [ ] Scoring automatique
  - [ ] Alerte si dégradation >5%

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
- All blocked tasks annotated with `[blocked: Mistral key expired]` in this TODO
- T-MS-032 marked as partially actionable (2 pages draftable offline, 2 skeleton only)
- Status report created: `docs/MISTRAL_STUDIO_STATUS_2026-03-25.md`
  - Full inventory of tooling, conventions, and next actions when keys are renewed
  - Priority execution order documented

Impact:
- No further progress possible on Plan 24 until Mistral API key is renewed
- When key is renewed, start with `dataset_audit_tui.sh` preflight then T-MS-002/003
