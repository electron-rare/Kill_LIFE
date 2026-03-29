from __future__ import annotations

import importlib
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = ROOT / "tools" / "cad" / "integrations" / "kicad"


class YiACADKiCadPluginContractTest(unittest.TestCase):
    def setUp(self) -> None:
        sys.path.insert(0, str(PLUGIN_ROOT))

    def tearDown(self) -> None:
        if str(PLUGIN_ROOT) in sys.path:
            sys.path.remove(str(PLUGIN_ROOT))
        for name in list(sys.modules):
            if name.startswith("yiacad_kicad_plugin"):
                sys.modules.pop(name, None)

    def test_common_project_inputs_from_board_path(self) -> None:
        common = importlib.import_module("yiacad_kicad_plugin._common")
        with tempfile.TemporaryDirectory() as tmpdir:
            board = Path(tmpdir) / "sample_project.kicad_pcb"
            schematic = Path(tmpdir) / "sample_project.kicad_sch"
            board.write_text("", encoding="utf-8")
            schematic.write_text("", encoding="utf-8")
            payload = common._project_inputs(str(board))
            self.assertEqual(payload["board"], str(board))
            self.assertEqual(payload["schematic"], str(schematic))

    def test_common_exposes_registry_backed_actions_and_runtime_discovery(self) -> None:
        common = importlib.import_module("yiacad_kicad_plugin._common")
        actions = common.available_actions()
        commands = {entry["transport_command"] for entry in actions}
        self.assertIn("kicad-erc-drc", commands)
        self.assertIn("bom-review", commands)

        board = type("Board", (), {"GetFileName": lambda self: "/tmp/demo.kicad_pcb"})()
        pcbnew = type("PcbNew", (), {"GetBoard": staticmethod(lambda: board)})
        source_path, backend = common.resolve_kicad_source_path(pcbnew, {"KICAD_IPC_PROJECT_PATH": ""})
        self.assertEqual(source_path, "/tmp/demo.kicad_pcb")
        self.assertIn(backend, {"pcbnew-runtime", "kicad-python-runtime"})

    def test_action_module_imports_without_kicad_runtime(self) -> None:
        module = importlib.import_module("yiacad_kicad_plugin.yiacad_action")
        message = module._result_message(
            {
                "status": "degraded",
                "summary": "example summary",
                "degraded_reasons": ["missing-board"],
                "next_steps": ["load a KiCad board"],
            }
        )
        self.assertIn("Status: degraded", message)
        self.assertIn("missing-board", message)

    def test_session_roundtrip(self) -> None:
        common = importlib.import_module("yiacad_kicad_plugin._common")
        with tempfile.TemporaryDirectory() as tmpdir:
            session_file = Path(tmpdir) / "session.json"
            common.remember_session_state("board-review", "inspect grounding", "/tmp/example.kicad_pcb", session_file)
            common.append_session_message(
                "user",
                "inspect grounding",
                intent="board-review",
                source_path="/tmp/example.kicad_pcb",
                path=session_file,
            )
            common.append_session_message(
                "assistant",
                "Status: done\nSummary: review completed",
                intent="board-review",
                source_path="/tmp/example.kicad_pcb",
                status="done",
                path=session_file,
            )
            payload = common.load_session(session_file)
            self.assertEqual(payload["last_intent"], "board-review")
            self.assertEqual(payload["last_prompt"], "inspect grounding")
            self.assertEqual(len(payload["messages"]), 2)
            self.assertEqual(payload["messages"][1]["status"], "done")


if __name__ == "__main__":
    unittest.main()
