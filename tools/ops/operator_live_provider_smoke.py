#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path
from urllib import error, request

DEFAULT_CHAT_URL = os.environ.get("MASCARADE_CHAT_URL", "http://localhost:3000/api/v1/chat/completions")
DEFAULT_PROVIDERS_URL = os.environ.get("MASCARADE_PROVIDERS_URL", "http://localhost:3000/api/agents/providers")
DEFAULT_OUTPUT = "artifacts/operator_lane/live_provider_result.json"
DEFAULT_CATALOG = str(Path(__file__).resolve().parents[2] / "specs" / "contracts" / "mascarade_model_profiles.kxkm_ai.json")
DEFAULT_PROMPT = "Summarise the current Kill_LIFE operator lane in one concise sentence."
DEFAULT_PROVIDER_PREFERENCE = ["apple-coreml", "openai", "ollama", "anthropic", "openrouter"]
DEFAULT_MODELS = {
    "apple-coreml": "apple-coreml:qwen3.5-4b-onnx-q4f16",
    "openai": "openai:gpt-4.1-mini",
    "ollama": "ollama:qwen3.5:9b",
    "anthropic": "anthropic:claude-3-5-haiku-latest",
    "openrouter": "openrouter:openai/gpt-4.1-mini",
}


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Full operator lane live-provider smoke.")
    parser.add_argument("--chat-url", default=DEFAULT_CHAT_URL)
    parser.add_argument("--providers-url", default=DEFAULT_PROVIDERS_URL)
    parser.add_argument("--catalog", default=os.environ.get("MASCARADE_MODEL_CATALOG", DEFAULT_CATALOG))
    parser.add_argument("--profile", default=os.environ.get("MASCARADE_OPERATOR_PROFILE", ""))
    parser.add_argument("--provider", default=os.environ.get("MASCARADE_OPERATOR_PROVIDER", ""))
    parser.add_argument("--model", default=os.environ.get("MASCARADE_OPERATOR_MODEL", ""))
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--timeout", type=float, default=float(os.environ.get("MASCARADE_OPERATOR_TIMEOUT", "30")))
    return parser.parse_args()


def auth_headers() -> dict[str, str]:
    api_key = (
        os.environ.get("MASCARADE_API_KEY")
        or os.environ.get("CRAZY_LIFE_API_KEY")
        or os.environ.get("KILL_LIFE_API_KEY")
        or ""
    ).strip()
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    return headers


def decode_json_bytes(payload: bytes) -> tuple[str, object | None]:
    text = payload.decode("utf-8", errors="replace")
    try:
        return text, json.loads(text)
    except json.JSONDecodeError:
        return text, None


def http_json(url: str, *, method: str = "GET", body: object | None = None, timeout: float = 30.0) -> tuple[int, object | None, str]:
    payload = None
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
    req = request.Request(url, data=payload, method=method, headers=auth_headers())
    try:
        with request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            text, parsed = decode_json_bytes(raw)
            return response.getcode(), parsed, text
    except error.HTTPError as exc:
        raw = exc.read()
        text, parsed = decode_json_bytes(raw)
        return exc.code, parsed, text


def load_catalog(path_str: str) -> dict[str, object]:
    path = Path(path_str)
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def select_profile(catalog: dict[str, object], profile_id: str) -> dict[str, object]:
    requested = profile_id.strip()
    profiles = catalog.get("profiles")
    if not isinstance(profiles, list):
        return {}
    for item in profiles:
        if isinstance(item, dict) and str(item.get("id", "")).strip() == requested:
            return item
    return {}


def profile_preference(profile: dict[str, object]) -> list[str]:
    raw = profile.get("provider_preference")
    if not isinstance(raw, list):
        return []
    return [item.strip() for item in raw if isinstance(item, str) and item.strip()]


def choose_provider(available: list[str], requested: str, preferred: list[str] | None = None) -> str:
    if requested:
        return requested
    wanted = [item.strip() for item in os.environ.get("MASCARADE_OPERATOR_PROVIDER_PREFERENCE", "").split(",") if item.strip()]
    preferred_order = preferred or wanted or DEFAULT_PROVIDER_PREFERENCE
    for provider in preferred_order:
        if provider in available:
            return provider
    return available[0] if available else ""


def choose_model(provider: str, requested: str) -> str:
    if requested:
        return requested
    env_default = os.environ.get("MASCARADE_DEFAULT_MODEL", "").strip()
    if env_default:
        if provider and ":" not in env_default:
            return f"{provider}:{env_default}"
        return env_default
    return DEFAULT_MODELS.get(provider, "")


def choose_profile_model(profile: dict[str, object], provider: str, requested: str) -> str:
    if requested:
        return requested

    candidates: list[str] = []
    default_model = profile.get("default_model")
    if isinstance(default_model, str) and default_model.strip():
        candidates.append(default_model.strip())

    fallback_models = profile.get("fallback_models")
    if isinstance(fallback_models, list):
        candidates.extend(item.strip() for item in fallback_models if isinstance(item, str) and item.strip())

    if provider:
        provider_prefix = f"{provider.lower()}:"
        for candidate in candidates:
            if candidate.lower().startswith(provider_prefix):
                return candidate

    return candidates[0] if candidates else choose_model(provider, "")


def infer_provider_from_model(model: str) -> str:
    normalized = model.strip().lower()
    if not normalized:
        return ""
    if ":" in normalized:
        return normalized.split(":", 1)[0]
    if normalized.startswith("claude"):
        return "claude"
    if normalized.startswith("gpt") or normalized.startswith("o1") or normalized.startswith("o3"):
        return "openai"
    if normalized.startswith("gemini"):
        return "gemini"
    if normalized.startswith("mistral"):
        return "mistral"
    return ""


def write_output(path_str: str, payload: dict[str, object]) -> None:
    path = Path(path_str)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")



def extract_completion(body: object | None) -> str:
    if not isinstance(body, dict):
        return ""
    choices = body.get("choices")
    if not isinstance(choices, list) or not choices:
        return ""
    first = choices[0]
    if not isinstance(first, dict):
        return ""
    message = first.get("message")
    if not isinstance(message, dict):
        return ""
    content = message.get("content")
    return content if isinstance(content, str) else ""



def main() -> int:
    args = parse_args()
    result: dict[str, object] = {
        "generated_at": utc_now(),
        "status": "blocked",
        "execution_path": "live-provider",
        "chat_url": args.chat_url,
        "providers_url": args.providers_url,
        "catalog": args.catalog,
        "profile": "",
        "prompt": args.prompt,
        "provider": "",
        "model": "",
        "available_providers": [],
        "completion": "",
        "summary": "",
        "error": None,
        "http_status": None,
        "usage": None,
    }

    catalog = load_catalog(args.catalog)
    requested_profile = args.profile.strip()
    selected_profile = select_profile(catalog, requested_profile) if requested_profile else {}
    preferred_providers: list[str] = []
    if requested_profile and not selected_profile:
        result["status"] = "blocked"
        result["error"] = f"profile not found: {requested_profile}"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 2

    if selected_profile:
        result["profile"] = str(selected_profile.get("id", "")).strip()
        preferred_providers = profile_preference(selected_profile)
        if args.prompt == DEFAULT_PROMPT:
            profile_prompt = str(selected_profile.get("prompt", "")).strip()
            if profile_prompt:
                args.prompt = profile_prompt
                result["prompt"] = args.prompt

    try:
        providers_status, providers_body, providers_text = http_json(
            args.providers_url,
            timeout=args.timeout,
        )
    except error.URLError as exc:
        result["status"] = "blocked"
        result["error"] = f"providers lookup failed: {exc.reason}"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 4

    result["http_status"] = providers_status
    available: list[str] = []
    if isinstance(providers_body, dict):
        providers = providers_body.get("providers")
        if isinstance(providers, list):
            available = [item for item in providers if isinstance(item, str) and item.strip()]
    result["available_providers"] = available

    requested_provider = args.provider.strip()
    requested_model = args.model.strip()
    provider = requested_provider or str(selected_profile.get("default_provider", "")).strip()
    model = requested_model
    result["provider"] = provider
    result["model"] = model

    if providers_status >= 400:
        result["status"] = "degraded"
        result["error"] = f"providers endpoint returned HTTP {providers_status}: {providers_text.strip() or 'empty response'}"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 3

    if not requested_provider and not requested_model and not available:
        result["status"] = "degraded"
        result["error"] = "no runtime provider is currently advertised by mascarade"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 3

    if selected_profile and not requested_provider and available and provider and provider not in available:
        provider = choose_provider(available, "", preferred_providers)
        result["provider"] = provider

    if not provider and requested_model:
        provider = infer_provider_from_model(requested_model)
        result["provider"] = provider

    if not provider and not requested_model and available:
        provider = choose_provider(available, "", preferred_providers)
        result["provider"] = provider

    payload = {
        "system": "You are a concise operations copilot.",
        "messages": [
            {"role": "user", "content": args.prompt},
        ],
        "temperature": 0.2,
        "max_tokens": 160,
    }
    if requested_model and model:
        payload["model"] = model

    try:
        chat_status, chat_body, chat_text = http_json(
            args.chat_url,
            method="POST",
            body=payload,
            timeout=args.timeout,
        )
    except error.URLError as exc:
        result["status"] = "blocked"
        result["error"] = f"chat request failed: {exc.reason}"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 4

    result["http_status"] = chat_status
    if chat_status >= 400:
        result["status"] = "degraded"
        result["error"] = chat_text.strip() or f"chat endpoint returned HTTP {chat_status}"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 3

    completion = extract_completion(chat_body)
    if not completion:
        result["status"] = "degraded"
        result["error"] = "chat response did not contain a completion message"
        write_output(args.output, result)
        print(json.dumps(result, ensure_ascii=True))
        return 3

    result["status"] = "ready"
    result["completion"] = completion
    result["summary"] = completion.splitlines()[0].strip() if completion.strip() else ""
    if isinstance(chat_body, dict):
        body_model = chat_body.get("model")
        if isinstance(body_model, str) and body_model.strip():
            result["model"] = body_model.strip()
            if not result["provider"]:
                result["provider"] = infer_provider_from_model(body_model.strip())
        usage = chat_body.get("usage")
        if isinstance(usage, dict):
            result["usage"] = usage

    write_output(args.output, result)
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
