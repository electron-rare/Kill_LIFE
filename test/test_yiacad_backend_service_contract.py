#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import tools.cad.yiacad_backend_service as service


class YiacadBackendServiceContractTests(unittest.TestCase):
    def test_dispatch_status_keeps_requested_surface_and_engine_status(self) -> None:
        rc, payload = service.dispatch_command("status", {"surface": "yiacad-web"})
        self.assertEqual(rc, 0)
        self.assertEqual(payload["component"], "yiacad")
        self.assertEqual(payload["surface"], "yiacad-web")
        self.assertEqual(payload["action"], "status.surface")
        self.assertIn("engine_status", payload)
        self.assertIn("kicad", payload["engine_status"])

    def test_failure_contract_and_artifact_index_remain_structured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            temp_dir = Path(tmp)
            with patch.object(service, "SERVICE_ARTIFACTS", temp_dir):
                service.write_json(
                    temp_dir / "latest_response.json",
                    {
                        "artifacts": [
                            {
                                "kind": "report",
                                "path": "/tmp/yiacad-report.json",
                                "label": "YiACAD report",
                            }
                        ]
                    },
                )
                index = service.latest_artifacts_payload()
                self.assertEqual(index["status"], "done")
                self.assertEqual(index["artifacts"][0]["label"], "YiACAD report")

        failure = service.uiux_contract_from_failure("service.dispatch", "boom", surface="yiacad-api")
        self.assertEqual(failure["surface"], "yiacad-api")
        self.assertEqual(failure["status"], "blocked")
        self.assertIn("engine_status", failure)
        self.assertIn("backend-dispatch-failed", failure["degraded_reasons"])

    def test_dispatch_manufacturing_and_kiauto_commands_stays_structured(self) -> None:
        rc, package_payload = service.dispatch_command("manufacturing-package", {"surface": "yiacad-web"})
        self.assertNotEqual(rc, 0)
        self.assertEqual(package_payload["surface"], "yiacad-web")
        self.assertEqual(package_payload["action"], "manufacturing.export")
        self.assertIn("engine_status", package_payload)

        rc, kiauto_payload = service.dispatch_command("kiauto-checks", {"surface": "yiacad-web"})
        self.assertNotEqual(rc, 0)
        self.assertEqual(kiauto_payload["surface"], "yiacad-web")
        self.assertEqual(kiauto_payload["action"], "manufacturing.validate")
        self.assertIn("engine_status", kiauto_payload)


if __name__ == "__main__":
    unittest.main()
