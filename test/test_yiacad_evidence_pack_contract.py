#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "tools" / "ci" / "write_yiacad_evidence_pack.py"
YIACAD_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "yiacad_product.yml"
KICAD_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "kicad-exports.yml"


def load_module():
    spec = importlib.util.spec_from_file_location("write_yiacad_evidence_pack", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class YiacadEvidencePackContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.module = load_module()

    def test_builder_emits_normalized_schema(self) -> None:
        payload = self.module.build_payload(
            self.module.EvidenceInputs(
                workflow="YiACAD Product",
                lane="product",
                status="success",
                summary="YiACAD product contracts and web build passed.",
                repository="electron-rare/Kill_LIFE",
                server_url="https://github.com",
                run_id="123",
                run_attempt="1",
                ref="refs/heads/main",
                sha="abc123",
                event="push",
                engines=["yiacad", "kicad", "freecad"],
                artifact_paths=["artifacts/ci/yiacad_product_evidence.json", "web/"],
                generated_at="2026-03-29T12:00:00Z",
            )
        )

        self.assertEqual(payload["schemaVersion"], "yiacad-evidence-pack/v1")
        self.assertEqual(payload["workflow"], "YiACAD Product")
        self.assertEqual(payload["lane"], "product")
        self.assertEqual(payload["status"], "success")
        self.assertEqual(payload["repository"], "electron-rare/Kill_LIFE")
        self.assertEqual(payload["engines"], ["yiacad", "kicad", "freecad"])
        self.assertEqual(payload["artifacts"][0]["path"], "artifacts/ci/yiacad_product_evidence.json")
        self.assertEqual(
            payload["run"]["url"],
            "https://github.com/electron-rare/Kill_LIFE/actions/runs/123",
        )

    def test_workflows_publish_standard_evidence_pack_artifacts(self) -> None:
        yiacad_workflow = YIACAD_WORKFLOW.read_text(encoding="utf-8")
        kicad_workflow = KICAD_WORKFLOW.read_text(encoding="utf-8")

        self.assertIn("write_yiacad_evidence_pack.py", yiacad_workflow)
        self.assertIn("yiacad-evidence-pack-product", yiacad_workflow)
        self.assertIn("write_yiacad_evidence_pack.py", kicad_workflow)
        self.assertIn("yiacad-evidence-pack-kicad-exports", kicad_workflow)


if __name__ == "__main__":
    unittest.main()
