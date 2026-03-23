#!/usr/bin/env python3
"""
T-MA-021 — Benchmark comparatif multi-provider Mascarade
=========================================================
Compare base models vs fine-tuned sur 100 prompts métier (KiCad, SPICE, embedded).

Providers testés:
  - Mistral (mistral-small-latest, codestral-latest, + fine-tuned LoRA)
  - Anthropic (claude-sonnet-4-20250514, claude-haiku-4-5-20251001)
  - OpenAI (gpt-4o, gpt-4o-mini)

Usage:
  python benchmark_providers.py --prompts prompts/kicad_100.jsonl --output results/
  python benchmark_providers.py --prompts prompts/spice_100.jsonl --output results/ --providers mistral,anthropic
  python benchmark_providers.py --prompts prompts/all_100.jsonl --output results/ --dry-run

Env vars requis:
  MISTRAL_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional

# --- Provider abstractions ---

@dataclass
class BenchmarkResult:
    prompt_id: str
    provider: str
    model: str
    prompt: str
    response: str
    latency_ms: float
    input_tokens: int
    output_tokens: int
    error: Optional[str] = None
    score: Optional[float] = None  # filled by evaluator


class ProviderClient:
    """Base class for provider API calls."""

    def complete(self, prompt: str, system: str = "", max_tokens: int = 1024) -> dict:
        raise NotImplementedError


class MistralClient(ProviderClient):
    def __init__(self, model: str = "mistral-small-latest"):
        from mistralai import Mistral
        self.client = Mistral(api_key=os.environ["MISTRAL_API_KEY"])
        self.model = model
        self.name = "mistral"

    def complete(self, prompt: str, system: str = "", max_tokens: int = 1024) -> dict:
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        t0 = time.time()
        resp = self.client.chat.complete(
            model=self.model,
            messages=messages,
            max_tokens=max_tokens,
        )
        latency = (time.time() - t0) * 1000

        choice = resp.choices[0]
        return {
            "response": choice.message.content,
            "latency_ms": latency,
            "input_tokens": resp.usage.prompt_tokens,
            "output_tokens": resp.usage.completion_tokens,
        }


class AnthropicClient(ProviderClient):
    def __init__(self, model: str = "claude-sonnet-4-20250514"):
        import anthropic
        self.client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        self.model = model
        self.name = "anthropic"

    def complete(self, prompt: str, system: str = "", max_tokens: int = 1024) -> dict:
        t0 = time.time()
        resp = self.client.messages.create(
            model=self.model,
            max_tokens=max_tokens,
            system=system if system else "You are a helpful electronics engineering assistant.",
            messages=[{"role": "user", "content": prompt}],
        )
        latency = (time.time() - t0) * 1000

        return {
            "response": resp.content[0].text,
            "latency_ms": latency,
            "input_tokens": resp.usage.input_tokens,
            "output_tokens": resp.usage.output_tokens,
        }


class OpenAIClient(ProviderClient):
    def __init__(self, model: str = "gpt-4o"):
        from openai import OpenAI
        self.client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
        self.model = model
        self.name = "openai"

    def complete(self, prompt: str, system: str = "", max_tokens: int = 1024) -> dict:
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        t0 = time.time()
        resp = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            max_tokens=max_tokens,
        )
        latency = (time.time() - t0) * 1000

        choice = resp.choices[0]
        return {
            "response": choice.message.content,
            "latency_ms": latency,
            "input_tokens": resp.usage.prompt_tokens,
            "output_tokens": resp.usage.completion_tokens,
        }


# --- Benchmark runner ---

PROVIDER_CONFIGS = {
    "mistral": [
        ("mistral-small-latest", "base"),
        ("codestral-latest", "base"),
        # ("ft:mistral-small:kicad-v1", "fine-tuned"),  # décommenter après fine-tune
    ],
    "anthropic": [
        ("claude-sonnet-4-20250514", "base"),
        ("claude-haiku-4-5-20251001", "base"),
    ],
    "openai": [
        ("gpt-4o", "base"),
        ("gpt-4o-mini", "base"),
    ],
}

CLIENT_CLASSES = {
    "mistral": MistralClient,
    "anthropic": AnthropicClient,
    "openai": OpenAIClient,
}


def load_prompts(path: str) -> list[dict]:
    """Load prompts from JSONL. Format: {"id": "P001", "prompt": "...", "system": "...", "expected": "..."}"""
    prompts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                prompts.append(json.loads(line))
    return prompts


def run_benchmark(
    prompts: list[dict],
    providers: list[str],
    output_dir: Path,
    max_tokens: int = 1024,
    dry_run: bool = False,
    rate_limit_delay: float = 1.0,
) -> list[BenchmarkResult]:
    """Run all prompts against all provider/model combos."""

    results = []
    total = sum(len(PROVIDER_CONFIGS.get(p, [])) for p in providers) * len(prompts)
    current = 0

    for provider_name in providers:
        configs = PROVIDER_CONFIGS.get(provider_name, [])
        if not configs:
            print(f"  [SKIP] Provider inconnu: {provider_name}")
            continue

        for model_id, model_type in configs:
            print(f"\n{'='*60}")
            print(f"  Provider: {provider_name} | Model: {model_id} ({model_type})")
            print(f"{'='*60}")

            try:
                client = CLIENT_CLASSES[provider_name](model=model_id)
            except Exception as e:
                print(f"  [ERROR] Init client: {e}")
                continue

            for prompt_data in prompts:
                current += 1
                pid = prompt_data.get("id", f"P{current:03d}")
                prompt_text = prompt_data["prompt"]
                system_text = prompt_data.get("system", "")

                print(f"  [{current}/{total}] {pid}...", end=" ", flush=True)

                if dry_run:
                    print("[DRY RUN]")
                    results.append(BenchmarkResult(
                        prompt_id=pid, provider=provider_name, model=model_id,
                        prompt=prompt_text[:100], response="[dry run]",
                        latency_ms=0, input_tokens=0, output_tokens=0,
                    ))
                    continue

                try:
                    resp = client.complete(prompt_text, system=system_text, max_tokens=max_tokens)
                    result = BenchmarkResult(
                        prompt_id=pid,
                        provider=provider_name,
                        model=model_id,
                        prompt=prompt_text[:200],
                        response=resp["response"][:500],
                        latency_ms=round(resp["latency_ms"], 1),
                        input_tokens=resp["input_tokens"],
                        output_tokens=resp["output_tokens"],
                    )
                    print(f"OK ({resp['latency_ms']:.0f}ms, {resp['output_tokens']} tokens)")
                except Exception as e:
                    result = BenchmarkResult(
                        prompt_id=pid,
                        provider=provider_name,
                        model=model_id,
                        prompt=prompt_text[:200],
                        response="",
                        latency_ms=0,
                        input_tokens=0,
                        output_tokens=0,
                        error=str(e),
                    )
                    print(f"ERROR: {e}")

                results.append(result)
                time.sleep(rate_limit_delay)

    return results


def save_results(results: list[BenchmarkResult], output_dir: Path, run_name: str):
    """Save results as JSONL + summary."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # Raw results
    results_file = output_dir / f"{run_name}_results.jsonl"
    with open(results_file, "w") as f:
        for r in results:
            f.write(json.dumps(asdict(r), ensure_ascii=False) + "\n")
    print(f"\nResults saved: {results_file}")

    # Summary
    summary = generate_summary(results)
    summary_file = output_dir / f"{run_name}_summary.json"
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    print(f"Summary saved: {summary_file}")

    # Print summary
    print_summary(summary)


def generate_summary(results: list[BenchmarkResult]) -> dict:
    """Generate benchmark summary with per-model stats."""
    from collections import defaultdict

    stats = defaultdict(lambda: {
        "count": 0, "errors": 0,
        "total_latency": 0, "total_input_tokens": 0, "total_output_tokens": 0,
        "latencies": [],
    })

    for r in results:
        key = f"{r.provider}/{r.model}"
        s = stats[key]
        s["count"] += 1
        if r.error:
            s["errors"] += 1
        else:
            s["total_latency"] += r.latency_ms
            s["total_input_tokens"] += r.input_tokens
            s["total_output_tokens"] += r.output_tokens
            s["latencies"].append(r.latency_ms)

    summary = {
        "timestamp": datetime.now().isoformat(),
        "total_prompts": len(set(r.prompt_id for r in results)),
        "total_calls": len(results),
        "models": {},
    }

    for key, s in stats.items():
        success = s["count"] - s["errors"]
        latencies = sorted(s["latencies"])
        summary["models"][key] = {
            "calls": s["count"],
            "success": success,
            "errors": s["errors"],
            "avg_latency_ms": round(s["total_latency"] / max(success, 1), 1),
            "p50_latency_ms": round(latencies[len(latencies)//2], 1) if latencies else 0,
            "p95_latency_ms": round(latencies[int(len(latencies)*0.95)], 1) if latencies else 0,
            "total_input_tokens": s["total_input_tokens"],
            "total_output_tokens": s["total_output_tokens"],
            "avg_output_tokens": round(s["total_output_tokens"] / max(success, 1), 1),
        }

    return summary


def print_summary(summary: dict):
    """Pretty-print benchmark summary."""
    print(f"\n{'='*80}")
    print(f"  BENCHMARK SUMMARY — {summary['timestamp']}")
    print(f"  {summary['total_prompts']} prompts × {len(summary['models'])} models = {summary['total_calls']} calls")
    print(f"{'='*80}")
    print(f"{'Model':<40} {'OK':>4} {'Err':>4} {'Avg ms':>8} {'P95 ms':>8} {'Avg tok':>8}")
    print(f"{'-'*80}")

    for model, s in sorted(summary["models"].items()):
        print(f"{model:<40} {s['success']:>4} {s['errors']:>4} {s['avg_latency_ms']:>8.0f} {s['p95_latency_ms']:>8.0f} {s['avg_output_tokens']:>8.0f}")

    print(f"{'='*80}")


# --- CLI ---

def main():
    parser = argparse.ArgumentParser(description="T-MA-021 Benchmark multi-provider Mascarade")
    parser.add_argument("--prompts", required=True, help="Path to prompts JSONL file")
    parser.add_argument("--output", default="results/", help="Output directory")
    parser.add_argument("--providers", default="mistral,anthropic,openai", help="Comma-separated providers")
    parser.add_argument("--max-tokens", type=int, default=1024, help="Max output tokens")
    parser.add_argument("--rate-limit", type=float, default=1.0, help="Delay between calls (seconds)")
    parser.add_argument("--dry-run", action="store_true", help="Don't make actual API calls")
    parser.add_argument("--run-name", default=None, help="Run name for output files")
    args = parser.parse_args()

    providers = [p.strip() for p in args.providers.split(",")]
    prompts = load_prompts(args.prompts)
    run_name = args.run_name or f"bench_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

    print(f"Benchmark: {len(prompts)} prompts × providers {providers}")
    print(f"Output: {args.output}/{run_name}_*")

    results = run_benchmark(
        prompts=prompts,
        providers=providers,
        output_dir=Path(args.output),
        max_tokens=args.max_tokens,
        dry_run=args.dry_run,
        rate_limit_delay=args.rate_limit,
    )

    save_results(results, Path(args.output), run_name)


if __name__ == "__main__":
    main()
