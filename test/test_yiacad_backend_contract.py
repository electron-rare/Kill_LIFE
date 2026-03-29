#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest.mock import patch

import tools.cad.yiacad_backend as backend
from tools.cad.yiacad_backend import build_context_record, build_uiux_output, detect_integrated_engines


class YiacadBackendContractTests(unittest.TestCase):
    def test_build_uiux_output_keeps_engine_status_and_degraded_reasons(self) -> None:
        engine_status = detect_integrated_engines()
        payload = build_uiux_output(
            surface="yiacad-web",
            action="review.erc_drc",
            execution_mode="background",
            status="degraded",
            severity="warning",
            summary="YiACAD review completed with engine warnings.",
            details="KiCad review returned warnings and KiBot is not ready.",
            context_ref="project:demo/main",
            artifacts=[],
            next_steps=["open review center"],
            latency_ms=120,
            degraded_reasons=["kicad-violations-present", "kibot-runtime-not-ready"],
            engine_status=engine_status,
        )
        self.assertEqual(payload["surface"], "yiacad-web")
        self.assertEqual(payload["degraded_reasons"], ["kicad-violations-present", "kibot-runtime-not-ready"])
        self.assertIn("kicad", payload["engine_status"])
        self.assertIn("freecad", payload["engine_status"])

    def test_context_record_exposes_engine_baseline_and_runtime_state(self) -> None:
        context = build_context_record(
            "yiacad-api",
            source_path="hardware/esp32_minimal",
            artifacts_dir="artifacts/cad-ai-native/test-run",
        )
        runtime = context["runtime"]
        self.assertEqual(runtime["engine_baseline"]["kicad"], ">=10.0")
        self.assertEqual(runtime["engine_baseline"]["freecad"], ">=1.1")
        self.assertIn("kicad", runtime["integrated_engines"])
        self.assertIn("freecad", runtime["integrated_engines"])
        self.assertIn(runtime["integrated_engines"]["kicad"]["status"], {"done", "degraded", "blocked"})

    def test_command_output_returns_timeout_instead_of_hanging(self) -> None:
        with patch("tools.cad.yiacad_backend.subprocess.run", side_effect=backend.subprocess.TimeoutExpired(cmd=["demo"], timeout=0.1)):
            rc, text = backend.command_output(["demo"], timeout_sec=0.1)
        self.assertEqual(rc, 124)
        self.assertIn("timed out", text)

    def test_detect_integrated_engines_uses_freecad_bundle_without_launching_gui(self) -> None:
        commands: list[list[str]] = []

        def fake_resolve_binary(*candidates):
            first = candidates[0]
            if first == backend.KICAD_APP_CLI:
                return str(backend.KICAD_APP_CLI)
            if first == backend.FREECAD_APP_CMD:
                return None
            if first == backend.FREECAD_APP_GUI:
                return str(backend.FREECAD_APP_GUI)
            if first == "kibot":
                return "/usr/local/bin/kibot"
            if first == "pcbnew_do":
                return "/usr/local/bin/pcbnew_do"
            return None

        def fake_command_output(command, timeout_sec=backend.COMMAND_TIMEOUT_SEC):
            commands.append(command)
            if command[0] == str(backend.KICAD_APP_CLI):
                return (0, "10.0.0")
            if command[0] == "/usr/local/bin/kibot":
                return (0, "KiBot 1.8.5")
            if command[0] == "/usr/local/bin/pcbnew_do":
                return (0, "pcbnew_do 2.3.5")
            raise AssertionError(f"unexpected command: {command}")

        with (
            patch.object(backend, "resolve_binary", side_effect=fake_resolve_binary),
            patch.object(backend, "command_output", side_effect=fake_command_output),
            patch.object(backend, "bundle_version", return_value="1.1.0"),
        ):
            engines = backend.detect_integrated_engines()

        self.assertEqual(engines["freecad"]["detected_version"], "1.1.0")
        self.assertEqual(engines["freecad"]["status"], "done")
        self.assertEqual(engines["freecad"]["reason"], "bundle-ready")
        self.assertEqual(engines["freecad"]["binary"], str(backend.FREECAD_APP_GUI))
        self.assertTrue(all(command[0] != str(backend.FREECAD_APP_GUI) for command in commands))


if __name__ == "__main__":
    unittest.main()
