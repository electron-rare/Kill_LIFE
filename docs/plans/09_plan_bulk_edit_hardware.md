# 9) Plan de bulk edit hardware

## Objectif
Orchestrer des modifications massives (KiCad, exports, snapshots, artefacts) de manière sûre, reproductible et reviewable.

## Labels recommandés
- Issue : `type:systems` + `scope:hardware` + `risk:med` + `ai:plan`
- PR : `ai:impl` (ou `ai:plan` si c’est uniquement scripts/process)

## Étapes

### 1. Définir le scope du batch
- [x] Liste exacte des transformations (ex : rename nets, swap footprints) — Delivered: `hardware/rules/nets_rename.yaml` + `hardware/rules/fields.yaml`
- [x] Répertoires concernés (`hardware/` uniquement) — Delivered: scope guard limits to `hardware/`
- [x] Mode dry‑run si script — Delivered: `tools/hw/cad_stack.sh doctor` provides dry-run verification

### 2. Snapshots “avant”
- [ ] Export schéma PDF
- [ ] Export PCB renders
- [ ] Export BOM
- [x] Version des libs/footprints — Delivered: `hardware/rules/footprints.csv`

### 3. Exécution du bulk edit
- [ ] Dry‑run
- [ ] Apply
- [ ] Vérifier ERC/DRC

### 4. Snapshots “après”
- [ ] Exports identiques à “avant”
- [ ] Diff visuel (captures)

### 5. Evidence pack
- [x] Artefacts avant/après attachés à la PR — Delivered: `tools/collect_evidence.py` + `.github/workflows/evidence_pack.yml`
- [x] Logs du script — Delivered: `artifacts/` directory structure

## Gates
- DRC/ERC (si pipeline)
- Scope guard (doit rester dans `hardware/`)

## Critère de sortie
✅ Modif massive réalisée, vérifiée, et diff visuel clair.

## Références
- `docs/KICAD_AI_LOCAL.md`
- `docs/KICAD_PREVIEWS.md`
