#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
GRAPHQL_SCHEMA = REPO_ROOT / "web" / "lib" / "graphql" / "schema.ts"
GRAPHQL_CLIENT = REPO_ROOT / "web" / "lib" / "graphql" / "client.ts"
WEB_TYPES = REPO_ROOT / "web" / "lib" / "types.ts"
WORKER = REPO_ROOT / "web" / "workers" / "eda-worker.mjs"
PROJECT_STORE = REPO_ROOT / "web" / "lib" / "project-store.ts"


class YiacadWebReviewContractTests(unittest.TestCase):
    def test_ci_run_shape_is_exposed_consistently(self) -> None:
        schema = GRAPHQL_SCHEMA.read_text(encoding="utf-8")
        client = GRAPHQL_CLIENT.read_text(encoding="utf-8")
        types = WEB_TYPES.read_text(encoding="utf-8")

        for expected in (
            "engine: String!",
            "summary: String!",
            "degradedReasons: [String!]!",
            "artifactCount: Int!",
            "startedAt: String",
            "completedAt: String",
        ):
            self.assertIn(expected, schema)

        for expected in (
            "engine",
            "summary",
            "degradedReasons",
            "artifactCount",
            "startedAt",
            "completedAt",
        ):
            self.assertIn(expected, client)
            self.assertIn(expected, types)

    def test_review_contract_exposes_github_checks_and_evidence_packs(self) -> None:
        schema = GRAPHQL_SCHEMA.read_text(encoding="utf-8")
        client = GRAPHQL_CLIENT.read_text(encoding="utf-8")
        types = WEB_TYPES.read_text(encoding="utf-8")

        for expected in (
            "type GitHubCheck",
            "type EvidencePack",
            "githubChecks: [GitHubCheck!]!",
            "evidencePacks: [EvidencePack!]!",
            "checkSummary: String!",
            "changeScope: String!",
            "riskLevel: String!",
            "mergeRecommendation: String!",
            "checkIds: [String!]!",
            "evidencePackIds: [String!]!",
        ):
            self.assertIn(expected, schema)

        for expected in (
            "githubChecks",
            "evidencePacks",
            "checkSummary",
            "changeScope",
            "riskLevel",
            "mergeRecommendation",
            "checkIds",
            "evidencePackIds",
            "detailsUrl",
            "artifactUrl",
        ):
            self.assertIn(expected, client)
            self.assertIn(expected, types)

        self.assertIn("publishPullRequestSummary", schema)
        self.assertIn("PUBLISH_PULL_REQUEST_SUMMARY_MUTATION", client)

    def test_worker_persists_review_ready_ci_metadata(self) -> None:
        content = WORKER.read_text(encoding="utf-8")
        self.assertIn("degradedReasons", content)
        self.assertIn("artifactCount", content)
        self.assertIn("startedAt", content)
        self.assertIn("completedAt", content)
        self.assertIn("summary:", content)

    def test_project_store_resolves_github_checks_and_evidence_packs(self) -> None:
        content = PROJECT_STORE.read_text(encoding="utf-8")
        self.assertIn("/commits/${headSha}/check-runs", content)
        self.assertIn("/actions/runs?", content)
        self.assertIn("/actions/runs/${runId}/artifacts", content)
        self.assertIn("yiacad-evidence-pack", content)
        self.assertIn("Evidence Pack Validation", content)
        self.assertIn("/issues/${pullRequestId}/comments", content)
        self.assertIn("yiacad-pr-summary", content)

    def test_review_shell_offers_pr_summary_publish_action(self) -> None:
        review_shell = (REPO_ROOT / "web" / "components" / "pr-review-shell.tsx").read_text(
            encoding="utf-8"
        )
        self.assertIn("Publish YiACAD summary", review_shell)
        self.assertIn("publishPullRequestSummary", review_shell)


if __name__ == "__main__":
    unittest.main()
