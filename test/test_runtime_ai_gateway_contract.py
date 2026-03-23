#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cockpit" / "runtime_ai_gateway.sh"


class RuntimeAiGatewayContractTests(unittest.TestCase):
    def test_status_aggregates_sources_into_runtime_mcp_ia_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            intelligence = root / "intelligence.json"
            mesh = root / "mesh.json"
            mascarade = root / "mascarade.json"

            intelligence.write_text(
                json.dumps(
                    {
                        "contract_version": "summary-short/v1",
                        "status": "degraded",
                        "summary_short": "IA lane degraded with open governance items.",
                        "evidence": ["artifacts/cockpit/intelligence_program/latest.json"],
                        "open_task_count": 3,
                        "next_steps": ["Do intelligence thing"],
                    }
                ),
                encoding="utf-8",
            )
            mesh.write_text(
                "\n".join(
                    [
                        "INFO 2026-03-21 mesh preflight",
                        json.dumps(
                            {
                                "mesh_status": "ready",
                                "load_profile": "tower-first",
                                "host_order": ["clems", "kxkm"],
                            }
                        ),
                    ]
                ),
                encoding="utf-8",
            )
            mascarade.write_text(
                json.dumps({"status": "ok", "provider": "ollama", "model": "qwen"}),
                encoding="utf-8",
            )

            proc = subprocess.run(
                [
                    "bash",
                    str(SCRIPT),
                    "--action",
                    "status",
                    "--json",
                    "--intelligence-report",
                    str(intelligence),
                    "--mesh-report",
                    str(mesh),
                    "--mascarade-report",
                    str(mascarade),
                ],
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
                check=True,
            )

            payload = json.loads(proc.stdout)
            self.assertEqual(payload["contract_version"], "runtime-mcp-ia-gateway/v1")
            self.assertEqual(payload["component"], "runtime-mcp-ia-gateway")
            self.assertEqual(payload["owner_repo"], "Kill_LIFE")
            self.assertEqual(payload["owner_agent"], "Runtime-Companion")
            self.assertEqual(payload["owner_subagent"], "MCP-Health")
            self.assertEqual(payload["status"], "degraded")
            self.assertTrue(payload["summary_short"])
            self.assertLessEqual(len(payload["summary_short"]), 320)
            self.assertIn("surfaces", payload)
            self.assertEqual(payload["surfaces"]["ia"]["status"], "degraded")
            self.assertEqual(payload["surfaces"]["ia"]["open_task_count"], 3)
            self.assertEqual(payload["surfaces"]["mcp"]["status"], "ready")
            self.assertEqual(payload["surfaces"]["mcp"]["host_order"], ["clems", "kxkm"])
            self.assertEqual(payload["surfaces"]["runtime"]["status"], "ready")
            self.assertIn("firmware_cad", payload["surfaces"])
            self.assertIn(payload["surfaces"]["firmware_cad"]["status"], {"ready", "degraded", "blocked"})
            self.assertIn("firmware_cad", payload["summary_short_artifacts"])
            firmware_cad_summary_path = REPO_ROOT / payload["summary_short_artifacts"]["firmware_cad"]["json"]
            self.assertTrue(firmware_cad_summary_path.exists())
            self.assertEqual(payload["sources"]["mascarade"]["provider"], "ollama")
            self.assertGreaterEqual(len(payload["evidence"]), 1)
            self.assertIn("Do intelligence thing", payload["next_steps"])

    def test_refresh_degrades_fast_when_mesh_probe_times_out(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            intelligence_script = root / "intelligence.sh"
            mesh_script = root / "mesh.sh"
            mascarade_script = root / "mascarade.sh"

            intelligence_script.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' '{\"contract_version\":\"summary-short/v1\",\"status\":\"ready\",\"summary_short\":\"ok\",\"evidence\":[\"a\"],\"open_task_count\":0,\"next_steps\":[]}'\n",
                encoding="utf-8",
            )
            mesh_script.write_text(
                "#!/usr/bin/env bash\n"
                "sleep 2\n"
                "printf '%s\\n' '{\"mesh_status\":\"ready\",\"load_profile\":\"tower-first\",\"host_order\":[\"clems\"]}'\n",
                encoding="utf-8",
            )
            mascarade_script.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' '{\"status\":\"ok\",\"provider\":\"ollama\",\"model\":\"qwen\"}'\n",
                encoding="utf-8",
            )

            env = os.environ.copy()
            env.update(
                {
                    "RUNTIME_GATEWAY_INTELLIGENCE_SCRIPT": str(intelligence_script),
                    "RUNTIME_GATEWAY_MESH_SCRIPT": str(mesh_script),
                    "RUNTIME_GATEWAY_MASCARADE_SCRIPT": str(mascarade_script),
                    "RUNTIME_GATEWAY_INTELLIGENCE_TIMEOUT_SEC": "5",
                    "RUNTIME_GATEWAY_MESH_TIMEOUT_SEC": "1",
                    "RUNTIME_GATEWAY_MASCARADE_TIMEOUT_SEC": "5",
                }
            )

            proc = subprocess.run(
                ["bash", str(SCRIPT), "--action", "status", "--json", "--refresh"],
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
                check=True,
                env=env,
            )

            payload = json.loads(proc.stdout)
            self.assertEqual(payload["surfaces"]["runtime"]["status"], "ready")
            self.assertEqual(payload["surfaces"]["ia"]["status"], "ready")
            self.assertEqual(payload["surfaces"]["mcp"]["status"], "degraded")
            self.assertTrue(payload["sources"]["mesh"]["refresh_timeout"])
            self.assertIn("mesh-refresh-timeout", payload["degraded_reasons"])
            self.assertTrue(
                any("timed out" in step.lower() for step in payload["next_steps"])
            )


if __name__ == "__main__":
    unittest.main()
