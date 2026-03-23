# YiACAD global feature map (2026-03-20)

## Carte Mermaid

```mermaid
flowchart TD
  Core["Kill_LIFE core"] --> Specs["specs/"]
  Core --> Docs["docs/"]
  Core --> Tools["tools/"]
  Core --> Artifacts["artifacts/"]
  Tools --> Cockpit["cockpit / TUI"]
  Tools --> CAD["tools/cad"]
  Tools --> MCP["MCP runtime"]
  Tools --> AI["tools/ai"]
  CAD --> YiACAD["YiACAD lane"]
  YiACAD --> NativeKiCad["KiCad native shells"]
  YiACAD --> NativeFreeCAD["FreeCAD native workbench"]
  YiACAD --> Runner["yiacad_native_ops.py"]
  Runner --> Outputs["CAD artifacts + summaries"]
  Cockpit --> Plans["plans + todos"]
  Docs --> Audit["global audit + AI assessment"]
  Docs --> UX["UI/UX Apple-native bundle"]
  MCP --> Knowledge["knowledge / github / openscad / freecad / kicad"]
  AI --> ZeroClaw["ZeroClaw integrations"]
  AI --> Mesh["mesh tri-repo"]
  Outputs --> Artifacts
  Plans --> Artifacts
```

## Cartes de fonctionnalites

### 1. Gouvernance

- Manifeste de refonte
- Plans vivants
- TODOs prioritaires
- Matrice agents / write-sets

### 2. Pilotage operateur

- Cockpit de refonte
- TUI YiACAD UI/UX
- TUI globale YiACAD
- Resume hebdomadaire
- Politique logs / purge

### 3. CAD IA-native

- Fusion KiCad + FreeCAD
- Hooks natifs dans `kicad manager`, `pcbnew`, `eeschema`
- Workbench FreeCAD YiACAD
- Utilities `status`, `ERC/DRC`, `BOM Review`, `ECAD/MCAD Sync`

### 4. IA et orchestration

- Runtime MCP
- ZeroClaw integrations
- Patterns LangGraph / AutoGen
- Knowledge base / GitHub dispatch

### 5. Compliance et evidence

- Evidence packs
- Badges
- Validation spec / repo / compliance
- Historisation des lots et de leurs artefacts
