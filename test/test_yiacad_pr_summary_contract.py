#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROJECT_STORE = REPO_ROOT / "web" / "lib" / "project-store.ts"


class YiacadPrSummaryContractTests(unittest.TestCase):
    def test_project_store_contains_docs_and_cad_review_logic(self) -> None:
        source = PROJECT_STORE.read_text(encoding="utf-8")
        self.assertIn('scope: "docs-only" | "cad" | "web" | "runtime" | "mixed" | "local-only"', source)
        self.assertIn("classifyPullRequestDiff", source)
        self.assertIn("assessPullRequest", source)
        self.assertIn("Merge recommendation", source)
        self.assertIn("Perform a final human CAD review", source)
        self.assertIn("Diff scope is documentation-only.", source)


if __name__ == "__main__":
    unittest.main()
