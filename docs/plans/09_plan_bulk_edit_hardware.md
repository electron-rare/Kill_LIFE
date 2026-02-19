# 9) Plan de bulk edit hardware

## Objectif
Orchestrer des modifications massives (KiCad, exports, snapshots, artefacts) de manière sûre, reproductible et reviewable.

## Labels recommandés
- Issue : `type:hardware` + `risk:med` + `ai:plan`
- PR : `ai:impl` (ou `ai:plan` si c’est uniquement scripts/process)

## Étapes

### 1. Définir le scope du batch
- [ ] Liste exacte des transformations (ex : rename nets, swap footprints)
- [ ] Répertoires concernés (`hardware/` uniquement)
- [ ] Mode dry‑run si script

### 2. Snapshots “avant”
- [ ] Export schéma PDF
- [ ] Export PCB renders
- [ ] Export BOM
- [ ] Version des libs/footprints

### 3. Exécution du bulk edit
- [ ] Dry‑run
- [ ] Apply
- [ ] Vérifier ERC/DRC

### 4. Snapshots “après”
- [ ] Exports identiques à “avant”
- [ ] Diff visuel (captures)

### 5. Evidence pack
- [ ] Artefacts avant/après attachés à la PR
- [ ] Logs du script

## Gates
- DRC/ERC (si pipeline)
- Scope guard (doit rester dans `hardware/`)

## Critère de sortie
✅ Modif massive réalisée, vérifiée, et diff visuel clair.

## Références
- `docs/KICAD_AI_LOCAL.md`
- `docs/KICAD_PREVIEWS.md`