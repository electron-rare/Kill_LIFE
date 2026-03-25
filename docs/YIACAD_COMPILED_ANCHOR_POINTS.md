# YiACAD Compiled Anchor Points (T-UX-007)

> Date: 2026-03-25 | Source: Plan 20 - UI/UX Apple-native

---

## 1. KiCad (`kicad-ki` fork) -- Compiled Insertion Points

### 1.1 Toolbar anchors

| File | Role | Write-set status |
|---|---|---|
| `pcbnew/toolbars_pcb_editor.cpp` | PCB editor toolbar groups, YiACAD Review group | SAFE -- already used |
| `eeschema/toolbars_sch_editor.cpp` | Schematic editor toolbar groups, YiACAD Review group | SAFE -- already used |
| `common/eda_base_frame.cpp` | Shared `configureToolbars()` -- global toolbar rebuild | NO-TOUCH (shared, macOS menu sensitivity) |
| `include/eda_base_frame.h` | Header for toolbar extension API | READ-ONLY reference |

### 1.2 Menu anchors

| File | Role | Write-set status |
|---|---|---|
| `pcbnew/menubar_pcb_editor.cpp` | PCB editor menubar, YiACAD Status entry | SAFE -- already used |
| `eeschema/menubar.cpp` | Schematic editor menubar, YiACAD Status entry | SAFE -- already used |
| `kicad/menubar.cpp` | KiCad Manager menubar | SAFE -- already used |

### 1.3 Editor control anchors (action handlers)

| File | Role | Write-set status |
|---|---|---|
| `pcbnew/tools/board_editor_control.cpp` | PCB TOOL_ACTION handlers: Status, ERC/DRC, BOM Review, ECAD/MCAD Sync | SAFE -- already used |
| `pcbnew/tools/board_editor_control.h` | PCB handler declarations | SAFE -- already used |
| `eeschema/tools/sch_editor_control.cpp` | Schematic TOOL_ACTION handlers (symmetric to PCB) | SAFE -- already used |
| `eeschema/tools/sch_editor_control.h` | Schematic handler declarations | SAFE -- already used |

### 1.4 Inspector / assistant panel anchors

| File | Role | Write-set status |
|---|---|---|
| `pcbnew/pcb_edit_frame.cpp` | PCB editor main frame -- dockable assistant pane slot | CANDIDATE (next lot) |
| `eeschema/sch_edit_frame.cpp` | Schematic editor main frame -- dockable assistant pane slot | CANDIDATE (next lot) |
| `common/widgets/properties_panel.h` | Properties panel API -- model for AssistantPane | READ-ONLY reference |

### 1.5 Rich panel / webview anchors

| File | Role | Write-set status |
|---|---|---|
| `include/widgets/webview_panel.h` | WEBVIEW_PANEL header (embedded chromium panel) | CANDIDATE (rich review UI) |
| `common/widgets/webview_panel.cpp` | WEBVIEW_PANEL implementation | CANDIDATE (rich review UI) |
| `include/tool/tool_action.h` | TOOL_ACTION registration API | READ-ONLY reference |
| `include/tool/action_menu.h` | ACTION_MENU builder API | READ-ONLY reference |

### 1.6 Known risks (KiCad)

- `wxExecute(..., wxEXEC_SYNC)` + `wxMessageBox` blocks UI thread in current runners
- Toolbar/menu rebuild on macOS uses deferred recreation -- fragile with dynamic groups
- PCB and SCH shells are duplicated; any extension must stay strictly symmetric
- `EDA_BASE_FRAME` is shared across all frames -- changes there cascade everywhere

---

## 2. FreeCAD (`freecad-ki` fork) -- Compiled Insertion Points

### 2.1 Shell dock anchor

| File | Role | Write-set status |
|---|---|---|
| `src/Gui/MainWindow.cpp` | `Std_YiACADShellView` dock, hidden by default, toggle via "YiACAD Shell" | SAFE -- already used (T-UX-003D) |

### 2.2 Dock management anchors

| File | Role | Write-set status |
|---|---|---|
| `src/Gui/DockWindow.h` | Dock widget base API | NO-TOUCH (layout persistence risk) |
| `src/Gui/DockWindowManager.cpp` | Dock lifecycle, tabification | NO-TOUCH (double ownership risk) |
| `src/Gui/ComboView.h` | ComboView (tree+property) -- model for inspector | NO-TOUCH |
| `src/Gui/ComboView.cpp` | ComboView implementation | NO-TOUCH |

### 2.3 Workbench anchors (Python-level, compile-adjacent)

| File | Role | Write-set status |
|---|---|---|
| `src/Mod/YiACADWorkbench/InitGui.py` | Workbench registration entry point | SAFE -- already used |
| `src/Mod/YiACADWorkbench/yiacad_freecad_gui.py` | Inspector, command palette, review center (Python) | SAFE -- primary surface |
| `src/Gui/Workbench.cpp` | C++ workbench manager | READ-ONLY reference |
| `src/Gui/Application.cpp` | Application init, workbench loading | READ-ONLY reference |

### 2.4 Global menu/toolbar injection anchors

| File | Role | Write-set status |
|---|---|---|
| `src/Gui/WorkbenchManipulator.h` | Manipulator API for cross-workbench toolbar injection | CANDIDATE (global YiACAD toolbar) |
| `src/Gui/WorkbenchManipulatorPython.cpp` | Python-accessible manipulator | CANDIDATE |
| `src/Gui/ApplicationPy.cpp` | Python-side application commands | CANDIDATE |

### 2.5 Command registration anchors

| File | Role | Write-set status |
|---|---|---|
| `src/Gui/Command.cpp` | C++ command framework | READ-ONLY reference |
| `src/Gui/PropertyView.h` | Property inspector API (reference for panel design) | READ-ONLY reference |

### 2.6 Known risks (FreeCAD)

- Menu/toolbar rebuilt on every workbench switch -- injected items must re-register
- Dock name persistence: layout restore breaks if dock objectName changes
- Double ownership if Python workbench inspector and C++ shell dock coexist
- `run_native_action()` is synchronous in UI thread -- risk of freezes

---

## 3. Unified Semantic Toolbar Specification (T-UX-007)

### 3.1 Design principles

1. **Symmetric**: KiCad PCB/SCH and FreeCAD expose the same action set
2. **Grouped**: single "YiACAD" toolbar group, not scattered actions
3. **Non-blocking**: all actions must dispatch asynchronously (target: service-first via backend client)
4. **Degradable**: toolbar present even when backend is unreachable (status shows "offline")

### 3.2 Canonical action set

| Action ID | Label | Icon hint | Shortcut | Backend command |
|---|---|---|---|---|
| `yiacad.status` | YiACAD Status | status-circle | Ctrl+Shift+Y | `status` |
| `yiacad.erc_drc` | ERC/DRC Review | check-shield | Ctrl+Shift+E | `kicad-erc-drc` |
| `yiacad.bom_review` | BOM Review | list-check | Ctrl+Shift+B | `bom-review` |
| `yiacad.ecad_mcad_sync` | ECAD/MCAD Sync | arrows-sync | Ctrl+Shift+S | `ecad-mcad-sync` |
| `yiacad.inspector` | Inspector | magnifying-glass | Ctrl+Shift+I | (local UI toggle) |
| `yiacad.palette` | Command Palette | command-line | Ctrl+Shift+P | (local UI toggle) |

### 3.3 Toolbar layout per surface

```
KiCad pcbnew toolbar:     [ YiACAD Status | ERC/DRC | BOM | Sync | --- | Inspector | Palette ]
KiCad eeschema toolbar:   [ YiACAD Status | ERC/DRC | BOM | Sync | --- | Inspector | Palette ]
FreeCAD YiACAD toolbar:   [ YiACAD Status | ERC/DRC | BOM | Sync | --- | Inspector | Palette ]
```

All three surfaces use the identical group. KiCad uses `TOOL_ACTION` registration; FreeCAD uses `WorkbenchManipulator` or `FreeCADGui.addCommand`.

### 3.4 Transport contract

Every toolbar action calls `yiacad_backend_client.py` (or its compiled equivalent) with:
- Input: `{"command": "<action_id>", ...params}`
- Output: YiACAD UX contract (`status`, `severity`, `summary`, `details`, `artifacts`, `next_steps`)
- Fallback: direct call to `yiacad_native_ops.py` if service is unreachable

### 3.5 Implementation path

| Step | Surface | Effort | Requires compiled fork |
|---|---|---|---|
| 1 | FreeCAD Python workbench | Done | No |
| 2 | KiCad Python plugin (via action plugin API) | Done | No |
| 3 | KiCad compiled toolbar groups (`toolbars_*_editor.cpp`) | Done (T-UX-003A) | Yes (safe files) |
| 4 | FreeCAD compiled shell dock (`MainWindow.cpp`) | Done (T-UX-003D) | Yes (safe file) |
| 5 | KiCad compiled AssistantPane | Next lot | Yes (pcb/sch_edit_frame) |
| 6 | FreeCAD compiled global toolbar via WorkbenchManipulator | Next lot | Yes |
| 7 | KiCad WEBVIEW_PANEL for rich review UI | Future | Yes |

---

*Generated 2026-03-25 for Plan 20 T-UX-007*
