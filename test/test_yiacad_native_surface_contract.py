#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
KICAD_MANAGER_CONTROL = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "kicad"
    / "tools"
    / "kicad_manager_control.cpp"
)
PCB_TOOLBAR = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "pcbnew"
    / "toolbars_pcb_editor.cpp"
)
SCH_TOOLBAR = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "eeschema"
    / "toolbars_sch_editor.cpp"
)
BOARD_EDITOR_CONTROL = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "pcbnew"
    / "tools"
    / "board_editor_control.cpp"
)
SCH_EDITOR_CONTROL = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "eeschema"
    / "tools"
    / "sch_editor_control.cpp"
)
KICAD_PLUGIN = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "kicad-ki"
    / "scripting"
    / "plugins"
    / "yiacad_kicad_plugin"
    / "yiacad_action.py"
)
FREECAD_WORKBENCH = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "freecad-ki"
    / "src"
    / "Mod"
    / "YiACADWorkbench"
    / "yiacad_freecad_gui.py"
)
FREECAD_MAIN_WINDOW = (
    REPO_ROOT
    / ".runtime-home"
    / "cad-ai-native-forks"
    / "freecad-ki"
    / "src"
    / "Gui"
    / "MainWindow.cpp"
)
REQUIRED_NATIVE_SURFACES = (
    KICAD_MANAGER_CONTROL,
    PCB_TOOLBAR,
    SCH_TOOLBAR,
    BOARD_EDITOR_CONTROL,
    SCH_EDITOR_CONTROL,
    KICAD_PLUGIN,
    FREECAD_WORKBENCH,
    FREECAD_MAIN_WINDOW,
)


class YiacadNativeSurfaceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        missing = [str(path) for path in REQUIRED_NATIVE_SURFACES if not path.exists()]
        if missing:
            raise unittest.SkipTest(
                "Native CAD forks are not installed under .runtime-home: " + ", ".join(missing)
            )

    def read_text(self, path: Path) -> str:
        self.assertTrue(path.exists(), path)
        return path.read_text(encoding="utf-8")

    def assert_contains_all(self, path: Path, *needles: str) -> str:
        content = self.read_text(path)
        for needle in needles:
            self.assertIn(needle, content, f"Missing {needle!r} in {path}")
        return content

    def test_kicad_manager_exposes_full_yiacad_native_action_set(self) -> None:
        self.assert_contains_all(
            KICAD_MANAGER_CONTROL,
            "ShowYiacadStatus",
            "ShowYiacadErcDrc",
            "ShowYiacadBomReview",
            "ShowYiacadEcadMcadSync",
            "yiacad_backend_client.py",
        )

    def test_kicad_shell_toolbars_keep_yiacad_review_group(self) -> None:
        self.assert_contains_all(PCB_TOOLBAR, '_( "YiACAD Review" )')
        self.assert_contains_all(SCH_TOOLBAR, '_( "YiACAD Review" )')

    def test_kicad_control_layers_share_the_service_first_bridge(self) -> None:
        for path in (BOARD_EDITOR_CONTROL, SCH_EDITOR_CONTROL):
            self.assert_contains_all(
                path,
                "yiacad_backend_client.py",
                "PYTHON_EXECUTABLE",
                'python3',
                "ShowYiacadStatus",
                "ShowYiacadErcDrc",
                "ShowYiacadBomReview",
                "ShowYiacadEcadMcadSync",
            )

    def test_kicad_plugin_keeps_palette_review_center_and_persistence(self) -> None:
        content = self.assert_contains_all(
            KICAD_PLUGIN,
            "PALETTE_ACTIONS = [",
            "latest_review_session.json",
            "review_history.json",
            "YiACAD Command Palette",
            'label="Command Palette"',
            'label="Review Center"',
        )
        self.assertEqual(content.count("def load_review_history() -> dict:"), 1)

    def test_freecad_workbench_keeps_palette_review_center_and_persistence(self) -> None:
        self.assert_contains_all(
            FREECAD_WORKBENCH,
            'DOCK_TITLE = "YiACAD Inspector"',
            "PALETTE_ACTIONS = [",
            "latest_review_session.json",
            "review_history.json",
            'QtGui.QLabel("Command Palette")',
            'QtGui.QLabel("Review Center")',
            '"YiACAD_Inspector"',
        )

    def test_freecad_shell_anchor_remains_available_for_native_convergence(self) -> None:
        self.assert_contains_all(
            FREECAD_MAIN_WINDOW,
            'yiacadShellDockObjectName = "Std_YiACADShellView"',
            'QDockWidget::tr("YiACAD Shell")',
            '"<b>Surface:</b> freecad-shell"',
            '"<b>Status:</b> degraded"',
            '"<b>Artifacts:</b> output contract, review logs, workbench evidence"',
            '"<b>Next steps:</b> attach normalized result cards, route artifacts, then converge with the persistent inspector contract."',
        )


if __name__ == "__main__":
    unittest.main()
