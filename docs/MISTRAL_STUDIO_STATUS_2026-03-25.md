# Mistral Studio Integration — Status 2026-03-25

> Plan 24 — `docs/plans/24_todo_integration_mistral_studio.md`

---

## Completed (2/34 tasks)

| Task | Description | Date |
|------|-------------|------|
| T-MS-001 | `mistral_studio_tui.sh` cockpit (14 actions) | 2026-03-21 |
| T-MS-023 | Codestral FIM dans Mascarade router | 2026-03-22 |

## Ready (tooling in place, awaiting runtime)

| Task | Description | Blocker |
|------|-------------|---------|
| T-MS-002 | Dataset KiCad JSONL merge+validate+upload | [blocked: Mistral key expired] + VM virtiofs deadlock |
| T-MS-003 | Dataset SPICE+Embedded JSONL merge+validate+upload | [blocked: Mistral key expired] + VM virtiofs deadlock |
| T-MS-004 | Upload docs commerciales Tower Document Library | [blocked: Mistral key expired] |
| T-MS-005 | Upload datasheets test pour IA Documentaire | [blocked: Mistral key expired] |

## Blocked — API key required

All tasks below are directly blocked by the expired Mistral API key. No local workaround exists.

### P1 — Fine-tune (all blocked)
| Task | Description | Depends on |
|------|-------------|------------|
| T-MS-010 | Fine-tune KiCad sur open-mistral-7b | [blocked: Mistral key expired] + T-MS-002 |
| T-MS-011 | Fine-tune SPICE+Embedded sur codestral-latest | [blocked: Mistral key expired] + T-MS-003 |
| T-MS-012 | Batch benchmark 100 prompts | [blocked: Mistral key expired] + T-MS-010/011 |
| T-MS-013 | Document Library RAG Tower | [blocked: Mistral key expired] + T-MS-004 |

### P2 — Integrations Studio (all blocked)
| Task | Description | Depends on |
|------|-------------|------------|
| T-MS-020 | Pipeline OCR datasheets | [blocked: Mistral key expired] |
| T-MS-021 | Audio STT dans workflow ops | [blocked: Mistral key expired] |
| T-MS-022 | Installer Vibe CLI sur VM | [blocked: Mistral key expired] |

### P3 — Production (all blocked)
| Task | Description | Depends on |
|------|-------------|------------|
| T-MS-030 | Deploy fine-tuned models in Mascarade | [blocked: Mistral key expired] + T-MS-010/011 |
| T-MS-031 | Tests E2E Studio->Mascarade->Agent | [blocked: Mistral key expired] + T-MS-030 |
| T-MS-032 | Documentation Outline wiki | Can be started offline (see below) |
| T-MS-033 | Cron audit qualite modeles | [blocked: Mistral key expired] + T-MS-030 |

## Actionable now (no API key needed)

### T-MS-032 — Documentation Outline wiki (partial)
The four wiki pages can be drafted offline as templates:
- Page: Mistral Studio Overview — can be written from existing `ANALYSE_EXHAUSTIVE_ECOSYSTEME_2026-03-21.md` and `MISTRAL_DOCS_REFERENCE_2026-03-21.md`
- Page: Fine-tune Pipeline Guide — can be written from `mistral_dataset_pipeline.py` docstrings
- Page: IA Documentaire Usage — skeleton only (needs OCR test results)
- Page: Audio Integration — skeleton only (needs STT test results)

---

## Tooling inventory (all present)

| Tool | Location | Status |
|------|----------|--------|
| `mistral_studio_tui.sh` | `tools/cockpit/` | Ready, 14 actions |
| `mistral_dataset_pipeline.py` | mascarade/finetune/ | Ready, needs VM runtime |
| `mistral_agents_beta_api.py` | mascarade/agents/ | Ready, needs valid key |
| `dataset_audit_tui.sh` | `tools/cockpit/` | Gate locale avant upload |
| `mistral_workspace_guard.sh` | `tools/cockpit/` | Garde-fou operateur |
| `mascarade_mesh_env_sync.sh` | `tools/cockpit/` | Racines machines figees |
| `load_mistral_governance_env.sh` | `tools/cockpit/` | Charge MISTRAL_GOVERNANCE_API_KEY |

## Key conventions locked

- Mascarade runtime uses `MISTRAL_API_KEY` only
- Kill_LIFE governance uses `MISTRAL_GOVERNANCE_API_KEY`
- Active Mascarade code: `/Users/electron/Documents/Projets/mascarade`
- Kill_LIFE tracking: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`
- `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main` is forbidden for this lot

---

## Next actions when keys are renewed

Priority order:
1. Run `dataset_audit_tui.sh` preflight — confirm datasets accessible
2. Execute `mistral_dataset_pipeline.py full --domain kicad` then `--domain spice-embedded` (T-MS-002/003)
3. Upload commercial docs (T-MS-004) and test datasheets (T-MS-005)
4. Launch fine-tune jobs (T-MS-010/011)
5. Run batch benchmark (T-MS-012)
6. Configure Document Library RAG (T-MS-013)
7. Deploy fine-tuned models in router (T-MS-030)

Estimated time to complete all P0+P1 once unblocked: 2-3 sessions.
