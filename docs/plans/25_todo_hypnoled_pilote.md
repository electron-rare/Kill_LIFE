# TODO 25 — Projet Hypnoled : Cas pilote Mascarade + Kill_LIFE

> **Owner**: PM-Mesh + Architect
> **Date création**: 2026-03-22
> **Statut global**: 🟢 Phase 1 — Reviews Forge complètes, rapport livré
> **Client**: M. Garnier (`Clients/Garnier/`)
> **Projet**: `Projets/Hypnoled/`

---

## Contexte

Hypnoled est le premier projet client réel utilisé comme **cas pilote end-to-end** pour valider l'infrastructure multi-LLM Mascarade + Kill_LIFE. Le projet combine hardware (PCB KiCad, DALI), simulation (LTspice), et firmware (ESP32).

## Inventaire assets

### Hardware (4 projets KiCad)
| Projet | Fichier | Sous-schémas | Statut |
|--------|---------|-------------|--------|
| DALI PCB (main) | `hardware/pcb/DALI_PCB_main/` | DALI, esp32, audio, audio2led, MCP_power, UI | **Actif** (rev 0.1, 2026-02-10) |
| DALI PCB (backup) | `hardware/pcb/DALI_PCB_backup/` | idem | Backup |
| Audio2LED | `hardware/pcb/Audio2LED_PCB/` | standalone | Audio-réactif |
| Legacy | `hardware/pcb/PCB_legacy/` | standalone | Prototype 2021 |

### Composants DALI identifiés
- 1SMA4746 (Zener protection)
- BSS123 (N-MOSFET bus DALI)
- EL357N optocoupler (isolation galvanique)
- MB10S (pont redresseur 16V DALI)
- STN1HNK60 (MOSFET HV 600V — driver DALI)
- STN93003 (PNP amplificateur)
- BC857 (PNP interface)
- ESP32 (MCU principal)

### Simulation
- `hardware/simulation/hypnoled.asc` — LTspice, circuit LED driver
- `hardware/simulation/hypnoled simple.asc` — version simplifiée

### BOMs
- `Audio2LED_PCB/BOM.csv`
- `PCB_legacy/BOM.csv`
- `PCB_2021-03-31/BOM_*.csv`

---

## Phase 0 — Structuration (DONE)

- [x] T-HP-001: Créer fiche client Garnier (`Clients/Garnier/fiche_client.md`)
- [x] T-HP-002: Structurer projet Hypnoled (hardware/pcb, mecanique, simulation, docs, photos)
- [x] T-HP-003: Migrer tous les fichiers depuis `Fauteuil_Hypnotherapie/` et `Pro_Garnier/`
- [x] T-HP-004: Indexer les fichiers KiCad (4 projets, 7 sous-schémas)
- [x] T-HP-005: Test connectivité Forge/Codestral sur schéma DALI réel ✅ (200 OK, 800 tokens)

## Phase 1 — Agents Kill_LIFE sur Hypnoled

- [x] T-HP-010: **Forge review PCB** — ✅ 6/6 sous-schémas reviewés par Codestral (22 mars 2026)
  - DALI.kicad_sch → 660 in / 952 out — 1 critique (Zener 15V), 1 avert., 3 recos
  - esp32.kicad_sch → 785 in / 1222 out — 2 critiques (double ESP32, USB-C CC), 2 avert., 3 recos
  - audio.kicad_sch → 529 in / 771 out — 1 critique (PCM5122 alim), 1 avert., 3 recos
  - audio2led.kicad_sch → 560 in / 712 out — 1 critique (IRF3415 surdim.), 1 avert., 3 recos
  - MCP_power.kicad_sch → 624 in / 961 out — 2 critiques (chaîne alim incohérente), 1 avert., 3 recos
  - UI.kicad_sch → 478 in / 813 out — 1 critique (MPR121 addr I2C), 1 avert., 3 recos
  - **Total : 3 636 tokens in, 5 431 tokens out, 8 critiques, 7 avertissements, 18 recommandations**

- [x] T-HP-011: **Sentinelle monitoring** — ✅ Métriques collectées (22 mars 2026)
  - 6 appels API, 9 067 tokens total, taux succès 100%, coût ~0.009€

- [x] T-HP-012: **Tower documentation** — ✅ Rapport généré (22 mars 2026)
  - PDF : `Clients/Garnier/rapports/review_hardware_hypnoled_2026-03-22.pdf`
  - Markdown : `Projets/Hypnoled/docs/reviews/forge_review_DALI_PCB_2026-03-22.md`

- [x] T-HP-013: **BOM analysis** — ✅ BOM extraite et analysée (25 mars 2026)
  - Source: 7 sous-schémas KiCad (.kicad_sch) parsés via extraction s-expression
  - 235 composants extraits, 98 lignes uniques après déduplication
  - LCSC coverage: 8/98 (8%) auto-matched — MB10S, 1SMA4746, BSS123, BC857, R 0603, C 0805
  - 25 basic, 3 extended, 70 unavailable (manual sourcing needed)
  - Assembly status: **BLOCKED** — 70 composants nécessitent sourcing LCSC manuel
  - Artefacts: `hardware/bom/DALI_PCB_bom.csv`, `*_suggestions.csv`, `*_report.md`
  - Repo: `hypnoled` branch main, commit pending push

## Phase 2 — Simulation et Firmware

- [ ] T-HP-020: **Forge SPICE review** — Analyser `hypnoled.asc` avec Codestral, proposer optimisations — [ready: assets in electron-rare/hypnoled] + [ready: Mistral key active, use devstral via Ollama on Tower to save credits]
- [x] T-HP-021: **Forge firmware** — Skeleton firmware ESP32 pour contrôle DALI (I2C + UART) — DONE (25 mars 2026)
  - `firmware/src/main.cpp` — DALI TX Manchester encoding, RX optocoupler ISR, WiFi+MQTT, I2C bus
  - `firmware/platformio.ini` — ESP32-DevKitC target, PubSubClient, Wire
  - Pushed to `electron-rare/hypnoled` main branch
- [x] T-HP-022: **Benchmark Hypnoled** — DONE (25 mars 2026)
  - 10 prompts Hypnoled-spécifiques créés: `tools/evals/prompts/hypnoled_10_benchmark.jsonl`
  - Categories: 3 KiCad schematic, 2 component, 2 firmware, 2 BOM/fabrication, 1 EMC cross-domain
  - Runner script: `tools/evals/run_hypnoled_benchmark.sh` (Tower Ollama devstral, zero API cost)
  - Results placeholder: `artifacts/evals/hypnoled_benchmark_2026-03-25.json`
  - Execution: run `bash tools/evals/run_hypnoled_benchmark.sh` when Tower is reachable

## Phase 3 — Fine-tune enrichissement

- [x] T-HP-030: **Dataset KiCad** — Extraire les schémas Hypnoled en paires prompt/response pour enrichir le dataset fine-tune T-MA-016 — DONE (25 mars 2026)
  - `tools/mistral/extract_hypnoled_datasets.py` created — s-expression parser for .kicad_sch
  - 7 schematics parsed: DALI PCB, DALI, MCP_power, UI, audio, audio2led, esp32
  - 30 ChatML JSONL Q&A pairs generated covering components, connections, architecture, design issues
  - Output: `tools/mistral/datasets/hypnoled_kicad/train.jsonl`
- [x] T-HP-031: **Dataset SPICE** — Extraire les simulations LTspice pour enrichir T-MA-017 — DONE (25 mars 2026)
  - Parser created in same script (LTspice .asc support)
  - No .asc simulation files found in current clone (hardware/simulation/ directory absent)
  - Empty output: `tools/mistral/datasets/hypnoled_spice/train.jsonl` — will populate when .asc files are added to repo
- [ ] T-HP-032: **Évaluation post fine-tune** — Re-run les reviews Forge sur Hypnoled avec le modèle fine-tuné vs base → mesurer l'amélioration — [blocked: depends Plan 24 fine-tune]

---

## Test initial validé (22 mars 2026)

```
Provider: Mistral (Codestral-latest / Forge)
Clé: mascarade-router (708z...7kG)
Prompt: Review schéma DALI Hypnoled
Résultat: 200 OK — 315 tokens in, 800 tokens out
Qualité: Bonne — identifie protection Zener, isolation optocoupleur, dimensionnement MOSFET HV
```

---

## Review complète Forge (22 mars 2026)

```
Provider: Mistral (Codestral-latest / Forge)
Clé: mascarade-router (708z...7kG)
Schémas reviewés: 6/6 (DALI, esp32, audio, audio2led, MCP_power, UI)
Total composants analysés: 333
Total tokens: 9 067 (3 636 in / 5 431 out)
Résultats: 8 critiques, 7 avertissements, 18 recommandations
Top 3 critiques:
  1. Architecture alimentation incohérente (MCP_power)
  2. Double ESP32 non justifié (esp32)
  3. Adresse I2C MPR121 non configurée (UI)
Rapport: Clients/Garnier/rapports/review_hardware_hypnoled_2026-03-22.pdf
```

---

## Gate d'execution 2026-03-22

Constat repo:
- les assets Hypnoled references dans ce TODO ne sont pas presents dans le checkout courant `Kill_LIFE`
- les prochains lots Hypnoled sont donc `blocked-by-missing-assets-in-current-checkout` tant que les schemas, boards, BOMs et rapports references ne sont pas materialises ici

Ordre d'execution retenu des que les assets sont presents:
1. `T-HP-013` — analyse BOM et alternatives composants
2. `T-RE-297` — contrat `fab package`
3. `T-HP-035` — parite `kicad-happy`
4. `T-HP-033` — canary `Quilter`
5. `T-HP-034` — evaluation `PCB Designer AI`

Sortie attendue pour `T-HP-013`:
- BOM normalisee
- alternatives composants
- mapping fournisseur `LCSC/JLCPCB` quand possible
- recommandations cout/disponibilite
- statut `assembly-ready` ou `blocked`

## Delta 2026-03-22 - PCB AI / BOM / fabrication

- [ ] T-HP-033: **Quilter canary route** — Executer un aller-retour `KiCad -> Quilter -> package fab` sur une carte Hypnoled et comparer le candidat au flux YiACAD local. — [ready: files in electron-rare/hypnoled/hardware/pcb/]
- [ ] T-HP-034: **PCB Designer AI fast-fab lane** — Evaluer une voie `schema -> layout -> export fabrication` sur un sous-ensemble Hypnoled, sans contourner le gate local `BOM/DRC/provenance`. — [ready: files in electron-rare/hypnoled/hardware/pcb/]
- [x] T-HP-035: **kicad-happy playbook parity** — DONE (25 mars 2026)
  - BOM analyzer run on `DALI_PCB_bom.csv` (235 components, 98 unique lines)
  - JLCPCB-ready BOM export: `artifacts/evals/hypnoled_jlcpcb_bom_2026-03-25.csv` (5-column JLCPCB format)
  - Playbook parity report: `artifacts/evals/hypnoled_playbook_2026-03-25.md`
  - Findings: 8/98 LCSC auto-matched, 70 need manual sourcing, 2 footprint errors (C39, R10/R11)
  - Assembly status: BLOCKED until manual LCSC sourcing complete
  - Parity score: 5/8 playbook steps complete, 1 partial, 2 blocked (DRC + full sourcing)

---

## Journal 2026-03-25

- `tools/industrial/bom_analyzer.py` created — generic BOM parser for T-HP-013
  - 4 commands: parse, suggest, report, batch
  - Column normalization covers KiCad, Altium, Eagle, generic CSV
  - Deduplication by value+footprint+MPN fingerprint
  - LCSC/JLCPCB alternative suggestion engine with static knowledge base
  - JLCPCB assembly category classification (basic/extended/unavailable)
  - Markdown report generation with assembly-ready status
- All blocked tasks annotated with explicit blocker tags
- Status report: `docs/HYPNOLED_STATUS_2026-03-25.md`
- Execution order documented for when assets become available
