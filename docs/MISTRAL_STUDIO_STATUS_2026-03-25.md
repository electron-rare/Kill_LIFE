# Mistral Studio Integration --- Status 2026-03-25

> Plan 24 --- `docs/plans/24_todo_integration_mistral_studio.md`
> Last updated: 2026-03-25 session 10

---

## Key Status: ACTIVE

- Mistral API key tested with `codestral-latest` on Tower --- confirmed working
- All `[blocked: Mistral key expired]` annotations replaced with `[ready: Mistral key active]`
- Plan 24 is now **unblocked** for API credit spend

## Dataset Builders: READY

- `build_datasets.py` being created by another agent --- status: in progress
- `mistral_dataset_pipeline.py` in mascarade/finetune/ --- ready for merge/validate/upload/finetune
- `dataset_audit_tui.sh` gate --- ready for preflight checks
- 12 JSONL datasets (~176 MB) in mascarade-datasets/ awaiting VM access

## Completed (2/34 tasks + prep sub-tasks)

| Task | Description | Date |
|------|-------------|------|
| T-MS-001 | `mistral_studio_tui.sh` cockpit (14 actions) | 2026-03-21 |
| T-MS-023 | Codestral FIM dans Mascarade router | 2026-03-22 |
| T-MS-004 (sub) | Exporter docs commerciales --- 4 docs in `docs/commercial/` | 2026-03-25 |
| T-MS-005 (sub) | Selectionner 5 datasheets test --- list in `docs/MISTRAL_DATASHEET_TEST_LIST.md` | 2026-03-25 |
| T-MS-032 (sub) | Mistral Studio Overview + Fine-tune Pipeline Guide --- source material identified | 2026-03-25 |

## Next Actions: Upload Datasets -> Fine-tune -> Evaluate

When ready to spend API credits, execute in this order:

### Phase 1 --- Upload (estimated: 1 session)

1. Run `dataset_audit_tui.sh` preflight --- confirm datasets accessible on VM
2. `mistral_dataset_pipeline.py full --domain kicad` (T-MS-002)
3. `mistral_dataset_pipeline.py full --domain spice-embedded` (T-MS-003)
4. Upload 4 commercial docs via Files API (T-MS-004)
5. Download + upload 5 test datasheets, run OCR test (T-MS-005)

### Phase 2 --- Fine-tune (estimated: 1-2 sessions, includes training time)

6. Launch fine-tune KiCad on `open-mistral-7b` (T-MS-010) --- 100 steps, lr=1e-5
7. Launch fine-tune SPICE+Embedded on `codestral-latest` (T-MS-011)
8. Configure Document Library RAG for Tower (T-MS-013)

### Phase 3 --- Evaluate (estimated: 1 session)

9. Run batch benchmark 100 prompts: base vs fine-tuned (T-MS-012)
10. Pipeline OCR datasheets batch (T-MS-020)
11. Audio STT test (T-MS-021)

### Phase 4 --- Production (estimated: 1-2 sessions)

12. Deploy `ft:kicad-v1` and `ft:spice-embedded-v1` in Mascarade router (T-MS-030)
13. E2E tests: datasheet->OCR->Sentinelle, prompt->router->ft-model, audio->STT->actions (T-MS-031)
14. Cron audit qualite modeles weekly (T-MS-033)
15. Install Vibe CLI on VM (T-MS-022)

## Estimated total: 4-6 sessions once API credits are committed

---

## Tooling Inventory (all present)

| Tool | Location | Status |
|------|----------|--------|
| `mistral_studio_tui.sh` | `tools/cockpit/` | Ready, 14 actions |
| `mistral_dataset_pipeline.py` | mascarade/finetune/ | Ready, needs VM runtime |
| `mistral_agents_beta_api.py` | mascarade/agents/ | Ready, key active |
| `dataset_audit_tui.sh` | `tools/cockpit/` | Gate locale avant upload |
| `mistral_workspace_guard.sh` | `tools/cockpit/` | Garde-fou operateur |
| `mascarade_mesh_env_sync.sh` | `tools/cockpit/` | Racines machines figees |
| `load_mistral_governance_env.sh` | `tools/cockpit/` | Charge MISTRAL_GOVERNANCE_API_KEY |
| `build_datasets.py` | (being created by another agent) | In progress |

## Key Conventions (locked)

- Mascarade runtime uses `MISTRAL_API_KEY` only
- Kill_LIFE governance uses `MISTRAL_GOVERNANCE_API_KEY`
- Active Mascarade code: `/Users/electron/Documents/Projets/mascarade`
- Kill_LIFE tracking: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`
- `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main` is forbidden for this lot
