#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SUMMARY_SCRIPT = REPO_ROOT / "tools" / "ci" / "write_yiacad_pr_summary.py"
PUBLISH_SCRIPT = REPO_ROOT / "tools" / "ci" / "publish_yiacad_pr_comment.py"
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "yiacad_product.yml"


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class YiacadCiPrCommentContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.summary_module = load_module(SUMMARY_SCRIPT, "write_yiacad_pr_summary")
        cls.publish_module = load_module(PUBLISH_SCRIPT, "publish_yiacad_pr_comment")

    def test_docs_only_pr_summary_is_favorable(self) -> None:
        module = self.summary_module
        profile = module.classify_pull_request_diff(["EASTER_EGGS.md"])
        assessment = module.assess_pull_request(
            profile,
            [module.CheckRecord(name="evidence_pack", status="pass", summary="ok", details_url=None)],
            [
                module.EvidenceRecord(
                    workflow="Evidence Pack Validation",
                    status="success",
                    summary="ok",
                    details_url="https://example.test/run",
                )
            ],
        )

        self.assertEqual(profile.scope, "docs-only")
        self.assertEqual(assessment.risk_level, "low")
        self.assertEqual(assessment.merge_recommendation, "favorable")

    def test_cad_pr_without_evidence_is_blocking(self) -> None:
        module = self.summary_module
        profile = module.classify_pull_request_diff(["hardware/demo/demo.kicad_pcb"])
        assessment = module.assess_pull_request(
            profile,
            [module.CheckRecord(name="yiacad-web-build", status="success", summary="ok", details_url=None)],
            [],
        )

        self.assertEqual(profile.scope, "cad")
        self.assertEqual(assessment.risk_level, "high")
        self.assertEqual(assessment.merge_recommendation, "blocking")

    def test_publish_script_updates_marker_comment(self) -> None:
        module = self.publish_module
        calls: list[tuple[str, str, dict[str, object] | None]] = []

        def fake_request(method: str, path: str, token: str, payload=None):
            calls.append((method, path, payload))
            if method == "GET":
                return [{"id": 42, "body": "<!-- yiacad-pr-summary --> old", "html_url": "https://example.test/old"}]
            return {"html_url": "https://example.test/new"}

        with patch.object(module, "github_request", side_effect=fake_request):
            result = module.publish_comment(
                repository="electron-rare/Kill_LIFE",
                pull_request_number="16",
                body="<!-- yiacad-pr-summary -->\nnew",
                token="token",
            )

        self.assertEqual(result["action"], "updated")
        self.assertEqual(result["comment_url"], "https://example.test/new")
        self.assertEqual(calls[0][0], "GET")
        self.assertEqual(calls[1][0], "PATCH")
        self.assertIn("/issues/comments/42", calls[1][1])

    def test_workflow_wires_pr_review_job_and_permissions(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("pull-requests: write", workflow)
        self.assertIn("checks: read", workflow)
        self.assertIn("actions: read", workflow)
        self.assertIn("yiacad-pr-review:", workflow)
        self.assertIn("write_yiacad_pr_summary.py", workflow)
        self.assertIn("publish_yiacad_pr_comment.py", workflow)
        self.assertIn("/commits/${{ github.event.pull_request.head.sha }}/check-runs", workflow)
        self.assertIn("/pulls/${{ github.event.pull_request.number }}/files", workflow)


if __name__ == "__main__":
    unittest.main()
