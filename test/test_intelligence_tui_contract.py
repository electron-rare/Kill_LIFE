#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from kill_life.agent_catalog import canonical_agent_ids

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "tools" / "cockpit" / "intelligence_tui.sh"
LEGACY_SCRIPT = REPO_ROOT / "tools" / "cockpit" / "intelligence_program_tui.sh"
CANONICAL_AGENT_IDS = set(canonical_agent_ids())


class IntelligenceTuiContractTests(unittest.TestCase):
    def run_script(self, *args: str) -> dict:
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return json.loads(proc.stdout)

    def run_script_from_cwd(self, cwd: Path, *args: str) -> dict:
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=str(cwd),
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return json.loads(proc.stdout)

    def run_text_script(self, *args: str) -> str:
        proc = subprocess.run(
            ["bash", str(SCRIPT), *args],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(proc.stdout.strip(), proc.stderr)
        return proc.stdout

    def test_status_reports_canonical_sources_and_extension_repos(self) -> None:
        payload = self.run_script("--action", "status", "--json")
        self.assertEqual(payload["contract_version"], "cockpit-v1")
        self.assertEqual(payload["component"], "intelligence_tui")
        self.assertEqual(payload["action"], "status")
        self.assertIn("canonical_sources", payload)
        self.assertGreaterEqual(len(payload["canonical_sources"]), 4)
        self.assertTrue(payload["spec_doc"].endswith("specs/agentic_intelligence_integration_spec.md"))
        self.assertTrue(payload["plan_doc"].endswith("docs/plans/22_plan_integration_intelligence_agentique.md"))
        self.assertTrue(payload["todo_doc"].endswith("docs/plans/22_todo_integration_intelligence_agentique.md"))
        self.assertTrue(payload["web_spec_doc"].endswith("specs/yiacad_git_eda_platform_spec.md"))
        self.assertTrue(payload["web_plan_doc"].endswith("docs/plans/23_plan_yiacad_git_eda_platform.md"))
        self.assertTrue(payload["web_todo_doc"].endswith("docs/plans/23_todo_yiacad_git_eda_platform.md"))
        labels = {source["label"] for source in payload["canonical_sources"]}
        self.assertIn("Plan 23", labels)
        self.assertIn("Web spec", labels)
        repo_names = {repo["name"] for repo in payload["extension_repos"]}
        self.assertTrue({"kill-life-studio", "kill-life-mesh", "kill-life-operator"}.issubset(repo_names))

    def test_memory_writes_latest_artifacts(self) -> None:
        payload = self.run_script("--action", "memory", "--json")
        memory_artifacts = payload["memory_artifacts"]
        latest_json = Path(memory_artifacts["json"])
        latest_md = Path(memory_artifacts["markdown"])
        self.assertTrue(latest_json.exists())
        self.assertTrue(latest_md.exists())
        persisted = json.loads(latest_json.read_text(encoding="utf-8"))
        self.assertEqual(persisted["component"], "intelligence_tui")
        self.assertIn("intelligence_views", persisted)
        self.assertEqual(
            set(persisted["intelligence_views"].keys()),
            {"scorecard", "comparison", "recommendations"},
        )
        probes = persisted["web_platform_health"]["probes"]
        self.assertIn("worker", probes)
        self.assertIn("queue", probes)
        self.assertIn(probes["worker"]["status"], {"up", "degraded", "down", "unknown"})

    def test_status_is_repo_root_stable_outside_repo_cwd(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            payload = self.run_script_from_cwd(Path(tmp_dir), "--action", "status", "--json")
        self.assertTrue(payload["spec_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["plan_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["todo_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["audit_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["feature_map_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["research_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["web_spec_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["web_plan_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(payload["web_todo_doc"].startswith(str(REPO_ROOT)))
        self.assertTrue(
            payload["intelligence_views"]["scorecard"]["json"].startswith(str(REPO_ROOT))
        )

    def test_next_actions_is_exposed(self) -> None:
        payload = self.run_script("--action", "next-actions", "--json")
        self.assertEqual(payload["action"], "next-actions")
        self.assertIn("next_steps", payload)
        self.assertGreaterEqual(len(payload["next_steps"]), 1)

    def test_scorecard_persists_lane_maturity_and_fragmentation(self) -> None:
        payload = self.run_script("--action", "scorecard", "--json")
        self.assertEqual(payload["action"], "scorecard")
        self.assertIn("fragmentation_score", payload)
        self.assertIn("overall_maturity_score", payload)
        self.assertIn("lane_maturity", payload)
        self.assertGreaterEqual(len(payload["lane_maturity"]), 4)
        for lane in payload["lane_maturity"]:
            self.assertIn(lane["owner_agent"], CANONICAL_AGENT_IDS)
        lane_names = {lane["lane"] for lane in payload["lane_maturity"]}
        self.assertIn("Program-Governance", lane_names)
        self.assertIn("Contracts", lane_names)
        self.assertIn("Runtime-Gateway", lane_names)
        self.assertIn("Web-Git-EDA", lane_names)
        scorecard_json = Path(payload["artifacts"][1])
        scorecard_md = Path(payload["artifacts"][2])
        self.assertTrue(scorecard_json.exists())
        self.assertTrue(scorecard_md.exists())

    def test_comparison_covers_five_target_repos(self) -> None:
        payload = self.run_script("--action", "comparison", "--json")
        self.assertEqual(payload["action"], "comparison")
        repo_names = {repo["name"] for repo in payload["repos"]}
        self.assertEqual(
            repo_names,
            {
                "Kill_LIFE",
                "ai-agentic-embedded-base",
                "kill-life-studio",
                "kill-life-mesh",
                "kill-life-operator",
            },
        )
        studio = next(repo for repo in payload["repos"] if repo["name"] == "kill-life-studio")
        self.assertEqual(studio["governance_signal"], "consumer")
        self.assertIsInstance(studio["enabled_capabilities"], list)

    def test_recommendations_exposes_prioritized_queue(self) -> None:
        payload = self.run_script("--action", "recommendations", "--json")
        self.assertEqual(payload["action"], "recommendations")
        queue = payload["queue"]
        self.assertGreaterEqual(len(queue), 5)
        for item in queue:
            self.assertIn(item["owner_agent"], CANONICAL_AGENT_IDS)
        self.assertEqual(queue[0]["id"], "AI-RQ-101")
        priorities = [item["priority"] for item in queue]
        self.assertEqual(priorities, sorted(priorities, key=lambda value: {"P0": 0, "P1": 1, "P2": 2}[value]))
        recommendation_json = Path(payload["artifacts"][1])
        recommendation_md = Path(payload["artifacts"][2])
        self.assertTrue(recommendation_json.exists())
        self.assertTrue(recommendation_md.exists())

    def test_research_uses_current_official_table(self) -> None:
        payload = self.run_script("--action", "research", "--json")
        self.assertEqual(payload["action"], "research")
        self.assertTrue(payload["research_doc"].startswith(str(REPO_ROOT)))
        self.assertGreaterEqual(len(payload["research"]), 1)
        first_row = payload["research"][0]
        self.assertTrue(
            any(
                key in first_row
                for key in (
                    "Source officielle",
                    "Pattern / source primaire",
                    "Projet / source",
                )
            )
        )

    def test_summary_short_json_is_compact_and_stable(self) -> None:
        payload = self.run_script("--action", "summary-short", "--json")
        self.assertEqual(payload["contract_version"], "summary-short/v1")
        self.assertEqual(payload["component"], "intelligence_tui")
        self.assertEqual(payload["action"], "summary-short")
        self.assertEqual(payload["owner_repo"], "Kill_LIFE")
        self.assertEqual(payload["owner_agent"], "PM-Mesh")
        self.assertIn(payload["owner_agent"], CANONICAL_AGENT_IDS)
        self.assertEqual(payload["owner_subagent"], "Plan-Orchestrator")
        self.assertIn(payload["status"], {"ready", "degraded", "blocked"})
        self.assertIsInstance(payload["write_set"], list)
        self.assertGreaterEqual(len(payload["write_set"]), 1)
        self.assertIsInstance(payload["evidence"], list)
        self.assertGreaterEqual(len(payload["evidence"]), 1)
        self.assertTrue(payload["summary_short"])
        self.assertLessEqual(len(payload["summary_short"]), 320)
        self.assertIsInstance(payload["open_task_count"], int)
        self.assertIsInstance(payload["intelligence_open_todo_count"], int)
        self.assertIsInstance(payload["global_open_task_count"], int)
        self.assertLessEqual(len(payload["next_steps"]), 3)
        self.assertIn("goal", payload)
        self.assertIn("state", payload)
        self.assertIn("blockers", payload)
        self.assertIn("next", payload)
        self.assertIn("owner", payload)
        self.assertIn("first_next_step", payload)
        self.assertIn("first_priority_lane", payload)
        self.assertNotIn("canonical_sources", payload)
        self.assertNotIn("owners", payload)
        self.assertNotIn("research", payload)
        self.assertNotIn("extension_repos", payload)

    def test_summary_short_text_is_extension_friendly(self) -> None:
        output = self.run_text_script("--action", "summary-short")
        lines = [line.strip() for line in output.splitlines() if line.strip()]
        self.assertGreaterEqual(len(lines), 6)
        self.assertTrue(all("=" in line for line in lines))
        self.assertEqual(lines[0], "contract_version=summary-short/v1")
        self.assertIn("component=intelligence_tui", lines)
        self.assertIn("action=summary-short", lines)
        self.assertTrue(any(line.startswith("owner_repo=Kill_LIFE") for line in lines))
        self.assertTrue(any(line.startswith("summary_short=") for line in lines))
        self.assertTrue(any(line.startswith("status=") for line in lines))
        self.assertTrue(any(line.startswith("open_task_count=") for line in lines))
        self.assertTrue(any(line.startswith("first_next_step=") for line in lines))
        self.assertTrue(any(line.startswith("evidence=") for line in lines))

    def test_legacy_wrapper_still_works(self) -> None:
        proc = subprocess.run(
            ["bash", str(LEGACY_SCRIPT), "--action", "summary-short", "--json"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["component"], "intelligence_tui")
        self.assertEqual(payload["action"], "summary-short")
        self.assertEqual(payload["contract_version"], "summary-short/v1")


if __name__ == "__main__":
    unittest.main()
