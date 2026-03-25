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
- [x] Export schéma PDF — Delivered: `tools/hw/snapshot.sh --label before` calls `tools/hw/exports.py` (SVG + PDF-ready renders)
- [x] Export PCB renders — Delivered: `tools/hw/snapshot.sh` + `tools/hw/exports.py` (PCB SVG export)
- [x] Export BOM — Delivered: `tools/hw/snapshot.sh` + `tools/hw/exports.py` (bom.csv + netlist.xml)
- [x] Version des libs/footprints — Delivered: `hardware/rules/footprints.csv`

### 3. Exécution du bulk edit
- [x] Dry‑run — Delivered: `tools/hw/bulk_edit.py --mode dry-run`
- [x] Apply — Delivered: `tools/hw/bulk_edit.py --mode apply`
- [x] Vérifier ERC/DRC — Delivered: `tools/hw/bulk_edit.py --mode verify` (runs ERC + DRC via kicad-cli)

### 4. Snapshots “après”
- [x] Exports identiques à “avant” — Delivered: `tools/hw/snapshot.sh --label after` (same export pipeline as “before”)
- [x] Diff visuel (captures) — Delivered: `tools/hw/hw_diff.sh <before> <after>` (BOM diff, ERC/DRC comparison, SVG side-by-side)

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
