"""
Minimal Mistral client wrapper for safe-output patch generation.

- Uses official `mistralai` SDK.
- Supports JSON Mode (`response_format={"type":"json_object"}`) to enforce valid JSON.
- Optional API base override (Codestral uses a different API base in some setups).
"""
from __future__ import annotations

import os
from typing import Any, Dict

from mistralai import Mistral


def get_client() -> Mistral:
    api_key = os.environ.get("MISTRAL_API_KEY")
    if not api_key:
        raise RuntimeError("MISTRAL_API_KEY is not set.")

    api_base = os.environ.get("MISTRAL_API_BASE")  # e.g. https://codestral.mistral.ai/v1
    # SDK supports server_url in recent versions; we pass it if available.
    try:
        if api_base:
            return Mistral(api_key=api_key, server_url=api_base)
    except TypeError:
        pass

    return Mistral(api_key=api_key)


def chat_json(
    *,
    model: str,
    system: str,
    user: str,
    temperature: float = 0.0,
    max_tokens: int = 4096,
) -> Dict[str, Any]:
    """
    Request JSON mode output. Returns parsed JSON dict.

    The SDK returns `choices[0].message.content` as a *stringified JSON object* in JSON mode.
    """
    import json

    client = get_client()
    resp = client.chat.complete(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        response_format={"type": "json_object"},
        temperature=temperature,
        max_tokens=max_tokens,
    )

    content = resp.choices[0].message.content
    if isinstance(content, dict):
        return content
    if not isinstance(content, str):
        raise RuntimeError(f"Unexpected content type: {type(content)}")

    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Model did not return valid JSON: {e}\nRaw:\n{content}") from e
