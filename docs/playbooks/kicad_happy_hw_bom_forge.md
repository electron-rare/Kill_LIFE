# Playbook: kicad-happy patterns → YiACAD / Forge / HW-BOM

> T-RE-298 | 2026-03-26 | Owner: HW-BOM (pattern sourcing/JLCPCB), Forge (design review), Embedded-CAD (fab package)

## Contexte

`kicad-happy` est un répertoire de référence de patterns pour le review de schémas KiCad, l'extraction de BOM, le sourcing LCSC/JLCPCB et les contrôles DFM. Ce playbook formalise ces patterns dans le workflow Kill_LIFE.

Référence exécution pilote: `artifacts/evals/hypnoled_playbook_2026-03-25.md` (235 composants, 98 lignes uniques).

---

## Étapes canoniques (8 steps kicad-happy)

### Step 1 — Forge Review (design correctness)

**Agent**: Forge (Codestral / Mistral)
**Entrée**: fichiers `*.kicad_sch`
**Sortie**: critiques, avertissements, recommandations avec sévérité

```bash
# Via YiACAD / Forge agent (LLM)
# Coût pilote: ~$0.009 (9 067 tokens Mistral Codestral)
# Sorties typiques: critiques design (Zener, adresses I2C, redondances)
```

**AC**: aucun critique HIGH non résolu avant fab.

---

### Step 2 — BOM parse + normalisation

**Agent**: HW-BOM
**Outil**: `python3 tools/industrial/bom_analyzer.py parse <bom.csv>`
**Entrée**: BOM KiCad export (`File > Fabrication Output > BOM`)
**Sortie**: BOM normalisée (colonnes: Ref, Value, Footprint, MPN, Quantity)

Formats supportés: KiCad, Altium, Eagle, CSV générique.
Déduplication par fingerprint `value+footprint+MPN`.

---

### Step 3 — LCSC auto-matching

**Agent**: HW-BOM
**Outil**: `python3 tools/industrial/bom_analyzer.py suggest <bom_normalized.csv>`
**Sortie**: mapping `LCSC code → Basic/Extended/Unavailable`

Performance pilote: 8/98 lignes matchées automatiquement (8%).
Les passifs standard (0603 R/C, footprints communs) ont le meilleur taux.

---

### Step 4 — BOM sourcing manuel (si LCSC < 50%)

**Agent**: HW-BOM (escalade user si ICs spécialisés)
**Critères d'escalade**:
- ICs spécialisés sans LCSC direct → recherche Nexar MCP (`nexar-api`)
- Connecteurs → recherche manuelle Mouser/LCSC
- Modules (ESP32, OLED) → BOM séparée "assembly-excluded"

---

### Step 5 — JLCPCB export

**Agent**: HW-BOM
**Outil**: `python3 tools/industrial/bom_analyzer.py report <bom.csv> --format jlcpcb`
**Sortie**: CSV 5 colonnes (Comment, Designator, Footprint, LCSC Part #, Quantity)

Format JLCPCB attendu:
```
Comment,Designator,Footprint,LCSC Part #,Quantity
10K 0603,R1 R2,0603,C25804,2
```

---

### Step 6 — DRC (Design Rule Check)

**Agent**: Embedded-CAD
**Outil**: `kicad-cli pcb drc --output <report.json> <board.kicad_pcb>`
**Sortie**: rapport JSON `drc_report` (requis dans `fab_package.schema.json`)

**AC**: 0 erreurs DRC bloquantes. Les avertissements sont documentés.

```bash
/usr/bin/kicad-cli pcb drc \
  --output hardware/esp32_minimal/drc_report.json \
  hardware/esp32_minimal/esp32_minimal.kicad_pcb
```

---

### Step 7 — Gerber + drill export

**Agent**: Embedded-CAD / KiBot
**Outil**: `kibot -c hardware/esp32_minimal/.kibot.yaml` (KiBot 1.8.5 en `.kibot-venv/`)

Layers requis: `F.Cu, B.Cu, F.SilkS, B.SilkS, F.Mask, B.Mask, Edge.Cuts`
Drill: Excellon + rapport de perçage

---

### Step 8 — Fab package assembly

**Agent**: Embedded-CAD (orchestration)
**Outil**: `bash tools/cockpit/fab_package_tui.sh --action build --json`
**Contrat**: `specs/contracts/fab_package.schema.json` (`fab-package-v1`)

Champs requis: `bom_file`, `cpl_file`, `gerber_dir`, `drill_file`, `drc_report`, `provenance`, `acceptance_gates`
Statut de sortie: `ready | degraded | blocked`

---

## Ownership matrix

| Pattern | Owner agent | Outil local | MCP |
|---------|-------------|-------------|-----|
| Design review | Forge | LLM call | — |
| BOM parse/normalise | HW-BOM | `bom_analyzer.py parse` | — |
| LCSC matching | HW-BOM | `bom_analyzer.py suggest` | `nexar-api` (fallback) |
| JLCPCB export | HW-BOM | `bom_analyzer.py report` | — |
| DRC | Embedded-CAD | `kicad-cli pcb drc` | `kicad` MCP |
| Gerber/drill | Embedded-CAD | KiBot | — |
| Fab package | Embedded-CAD | `fab_package_tui.sh` | — |
| 3D export | Embedded-CAD | `kicad-cli pcb export step` | `freecad` MCP |

## Critères d'assembly-ready

- [ ] 0 critique HIGH de Forge
- [ ] BOM: ≥ 80% lignes avec LCSC ou MPN explicite
- [ ] DRC: 0 erreurs bloquantes
- [ ] Gerbers complets (7 layers minimum)
- [ ] CPL présent (Centre de gravité + rotation)
- [ ] Fab package validé: `fab_package_tui.sh --action validate` → `ready`
