#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


DEFAULT_MARKER = "<!-- yiacad-pr-summary -->"
GITHUB_API = "https://api.github.com"


def github_request(
    method: str,
    path: str,
    token: str,
    payload: dict[str, object] | None = None,
) -> dict[str, object] | list[object]:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        f"{GITHUB_API}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def find_existing_comment(
    comments: list[dict[str, object]], marker: str
) -> dict[str, object] | None:
    for comment in comments:
        body = comment.get("body")
        if isinstance(body, str) and marker in body:
            return comment
    return None


def publish_comment(
    *,
    repository: str,
    pull_request_number: str,
    body: str,
    token: str,
    marker: str = DEFAULT_MARKER,
) -> dict[str, object]:
    comments_raw = github_request(
        "GET",
        f"/repos/{repository}/issues/{pull_request_number}/comments?per_page=100",
        token,
    )
    comments = comments_raw if isinstance(comments_raw, list) else []
    existing = find_existing_comment(
        [comment for comment in comments if isinstance(comment, dict)], marker
    )

    if existing and isinstance(existing.get("id"), int):
        comment_id = existing["id"]
        response = github_request(
            "PATCH",
            f"/repos/{repository}/issues/comments/{comment_id}",
            token,
            {"body": body},
        )
        action = "updated"
    else:
        response = github_request(
            "POST",
            f"/repos/{repository}/issues/{pull_request_number}/comments",
            token,
            {"body": body},
        )
        action = "created"

    if not isinstance(response, dict):
        raise RuntimeError("GitHub comment response was not an object.")

    return {
        "action": action,
        "comment_url": response.get("html_url"),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish or update the sticky YiACAD PR summary comment.")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--pull-request-number", required=True)
    parser.add_argument("--body-file", required=True)
    parser.add_argument("--token-env", default="GITHUB_TOKEN")
    parser.add_argument("--marker", default=DEFAULT_MARKER)
    parser.add_argument("--output-json", default=None)
    return parser.parse_args()


def resolve_token(token_env: str) -> str | None:
    token = os.environ.get(token_env)
    if token:
        return token
    if token_env == "GITHUB_TOKEN":
        return os.environ.get("GH_TOKEN")
    return None


def main() -> int:
    args = parse_args()
    token = resolve_token(args.token_env)
    if not token:
        if args.token_env == "GITHUB_TOKEN":
            raise SystemExit("GITHUB_TOKEN is not configured. GH_TOKEN fallback was also empty.")
        raise SystemExit(f"{args.token_env} is not configured.")

    body = Path(args.body_file).read_text(encoding="utf-8")
    try:
        result = publish_comment(
            repository=args.repository,
            pull_request_number=args.pull_request_number,
            body=body,
            token=token,
            marker=args.marker,
        )
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise SystemExit(
            f"GitHub PR comment publish failed ({error.code}): {detail or error.reason}"
        ) from error

    if args.output_json:
        Path(args.output_json).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    else:
        print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
