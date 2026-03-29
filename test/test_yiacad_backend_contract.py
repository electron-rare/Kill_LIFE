#!/usr/bin/env python3
from __future__ import annotations

import unittest

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


if __name__ == "__main__":
    unittest.main()
