#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROJECT_SHELL = REPO_ROOT / "web" / "components" / "project-shell.tsx"


class YiacadProjectShellContractTests(unittest.TestCase):
    def test_project_shell_surfaces_github_review_lane(self) -> None:
        content = PROJECT_SHELL.read_text(encoding="utf-8")
        self.assertIn("project?.pullRequests ?? []", content)
        self.assertIn("project?.githubChecks ?? []", content)
        self.assertIn("project?.evidencePacks ?? []", content)
        self.assertIn("pullRequest.changeScope", content)
        self.assertIn("pullRequest.riskLevel", content)
        self.assertIn("pullRequest.mergeRecommendation", content)
        self.assertIn("Open review", content)
        self.assertIn("GitHub QA lane", content)
        self.assertIn("Checks + evidence packs", content)


if __name__ == "__main__":
    unittest.main()
