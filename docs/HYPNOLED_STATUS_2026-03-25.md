# Hypnoled Pilot Project — Status 2026-03-25

> Plan 25 — `docs/plans/25_todo_hypnoled_pilote.md`

---

## Completed (5/14 tasks)

### Phase 0 — Structuration (DONE)
- [x] T-HP-001: Fiche client Garnier
- [x] T-HP-002: Structure projet Hypnoled
- [x] T-HP-003: Migration fichiers
- [x] T-HP-004: Index fichiers KiCad (4 projets, 7 sous-schemas)
- [x] T-HP-005: Test connectivite Forge/Codestral (200 OK)

### Phase 1 — Agents Kill_LIFE (3/4 done)
- [x] T-HP-010: Forge review PCB — 6/6 sous-schemas, 8 critiques, 7 avertissements, 18 recommandations
- [x] T-HP-011: Sentinelle monitoring — 9 067 tokens, 100% success
- [x] T-HP-012: Tower documentation — PDF + Markdown rapports
- [ ] T-HP-013: BOM analysis — **tooling created** (`tools/industrial/bom_analyzer.py`), awaiting BOM CSV assets

## Blocked — Missing assets in checkout

The Hypnoled hardware assets (KiCad projects, BOMs, simulations) are not present in the current Kill_LIFE checkout. All remaining tasks are blocked until assets are materialized.

### Blocked tasks

| Task | Description | Blocker |
|------|-------------|---------|
| T-HP-013 | BOM analysis | [blocked: BOM CSVs not in checkout] — tooling ready |
| T-HP-020 | Forge SPICE review | [blocked: hypnoled.asc not in checkout] + [blocked: Mistral key expired] |
| T-HP-021 | Forge firmware skeleton | [blocked: Mistral key expired] |
| T-HP-022 | Benchmark Hypnoled prompts | [blocked: Mistral key expired] |
| T-HP-030 | Dataset KiCad extraction | [blocked: KiCad files not in checkout] |
| T-HP-031 | Dataset SPICE extraction | [blocked: simulation files not in checkout] |
| T-HP-032 | Evaluation post fine-tune | [blocked: depends on Plan 24 fine-tune] |
| T-HP-033 | Quilter canary route | [blocked: KiCad files not in checkout] |
| T-HP-034 | PCB Designer AI fast-fab | [blocked: KiCad files not in checkout] |
| T-HP-035 | kicad-happy playbook parity | [blocked: KiCad files not in checkout] |

## Tooling ready

| Tool | Location | Purpose |
|------|----------|---------|
| `bom_analyzer.py` | `tools/industrial/` | Generic BOM parser, normalizer, LCSC/JLCPCB alternative suggester |
| `pcb_ai_fab_tui.sh` | `tools/cockpit/` | PCB fabrication TUI |
| `fab_package_tui.sh` | `tools/cockpit/` | Fab package builder |

---

## Execution order when assets are available

1. **Copy/symlink Hypnoled assets** into Kill_LIFE or ensure path references work
2. **T-HP-013** — Run `bom_analyzer.py` on `Audio2LED_PCB/BOM.csv` and `PCB_legacy/BOM.csv`
   - Output: normalized BOM, LCSC alternatives, assembly-ready status
3. **T-HP-033** — Quilter canary route (KiCad -> Quilter -> fab package)
4. **T-HP-035** — kicad-happy playbook parity
5. **T-HP-034** — PCB Designer AI evaluation
6. **T-HP-020** — Forge SPICE review (needs Mistral key)
7. **T-HP-021** — Forge firmware skeleton (needs Mistral key)
8. **T-HP-030/031** — Dataset extraction for fine-tune pipeline
9. **T-HP-022** — Benchmark after fine-tune
10. **T-HP-032** — Post fine-tune evaluation

## Key findings from Phase 1 reviews

From the Forge review of 6 DALI PCB sub-schematics:
- **8 critical issues** identified (Zener protection, double ESP32, PCM5122 power, IRF3415 overdim, MCP power chain, MPR121 I2C addr)
- **Cost**: ~0.009 EUR for 9 067 tokens — validates the multi-LLM approach for hardware review
- **Next step**: BOM analysis (T-HP-013) will cross-reference these findings with component availability and cost
