#!/usr/bin/env python3
from __future__ import annotations

import importlib
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = REPO_ROOT / "tools" / "cad" / "integrations" / "freecad"


class YiacadFreecadWorkbenchContractTests(unittest.TestCase):
    def setUp(self) -> None:
        sys.path.insert(0, str(PLUGIN_ROOT))

    def tearDown(self) -> None:
        if str(PLUGIN_ROOT) in sys.path:
            sys.path.remove(str(PLUGIN_ROOT))
        for name in list(sys.modules):
            if name.startswith("YiACADWorkbench"):
                sys.modules.pop(name, None)

    def test_adapter_exposes_document_selection_and_actions_without_runtime(self) -> None:
        adapter = importlib.import_module("YiACADWorkbench._adapter")
        freecad = type("FreeCAD", (), {"ActiveDocument": type("Doc", (), {"FileName": "/tmp/demo.FCStd"})()})
        selection_item = type("SelectionItem", (), {"ObjectName": "Body"})()
        selection = type(
            "Selection",
            (),
            {"getSelectionEx": staticmethod(lambda: [selection_item])},
        )
        freecad_gui = type("FreeCADGui", (), {"Selection": selection})

        self.assertEqual(adapter.current_document_path(freecad), "/tmp/demo.FCStd")
        self.assertEqual(adapter.selection_summary(freecad_gui), ["Body"])
        commands = {entry["transport_command"] for entry in adapter.available_registry_actions()}
        self.assertIn("ecad-mcad-sync", commands)

    def test_gui_module_imports_without_freecad_runtime(self) -> None:
        module = importlib.import_module("YiACADWorkbench.yiacad_freecad_gui")
        self.assertTrue(hasattr(module, "show_dialog"))
        commands = {entry["transport_command"] for entry in module.ACTION_ENTRIES}
        self.assertIn("ecad-mcad-sync", commands)
        self.assertIn("manufacturing-package", commands)

    def test_session_roundtrip(self) -> None:
        common = importlib.import_module("YiACADWorkbench._common")
        with tempfile.TemporaryDirectory() as tmpdir:
            session_file = Path(tmpdir) / "session.json"
            common.remember_session_state("ecad-mcad-sync", "check fit", "/tmp/demo.FCStd", session_file)
            common.append_session_message(
                "user",
                "check fit",
                intent="ecad-mcad-sync",
                source_path="/tmp/demo.FCStd",
                path=session_file,
            )
            common.append_session_message(
                "assistant",
                "Status: done\nSummary: sync completed",
                intent="ecad-mcad-sync",
                source_path="/tmp/demo.FCStd",
                status="done",
                path=session_file,
            )
            payload = common.load_session(session_file)
            self.assertEqual(payload["last_intent"], "ecad-mcad-sync")
            self.assertEqual(len(payload["messages"]), 2)
            self.assertEqual(payload["messages"][1]["status"], "done")


if __name__ == "__main__":
    unittest.main()
