#!/usr/bin/env python3
"""Generate HuggingFace dataset entries from Kill_LIFE RAG collections.

Queries the mascarade RAG pipeline to extract Q&A pairs for fine-tuning
datasets. Outputs JSONL format compatible with HuggingFace datasets.

Usage:
    python3 tools/generate_hf_dataset.py --collection kb-kicad --output datasets/kicad_qa.jsonl
    python3 tools/generate_hf_dataset.py --collection kb-firmware --output datasets/firmware_qa.jsonl
    python3 tools/generate_hf_dataset.py --all --output-dir datasets/
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

MASCARADE_URL = os.environ.get("MASCARADE_URL", "http://localhost:8100")

# Seed questions per collection for dataset generation
SEED_QUESTIONS = {
    "kb-kicad": [
        "What components are in the Kill_LIFE ESP32-S3 minimal board?",
        "How is the power supply designed for the ESP32-S3 board?",
        "What are the KiCad ERC rules for Kill_LIFE schematics?",
        "What is the pin assignment for the ESP32-S3-WROOM-1?",
        "How do the reusable design blocks connect via net labels?",
        "What decoupling capacitors are used on the +3V3 rail?",
        "How does the USB-C power input work in the Kill_LIFE board?",
        "What is the AMS1117-3.3 LDO configuration?",
        "How was the SPICE simulation for the power LDO validated?",
        "What ferrite bead is used for EMI filtering?",
    ],
    "kb-firmware": [
        "How does the Kill_LIFE firmware voice pipeline work?",
        "What is the OTA update protocol?",
        "How does the WiFi captive portal provisioning work?",
        "What are the I2S pin assignments for audio?",
        "How is the radio player implemented?",
        "What pure functions are available for native testing?",
        "How does the button handling work (short/long press)?",
        "What is the WiFi scanner architecture?",
        "How does the firmware communicate with the Mascarade backend?",
        "What media modes does the RadioPlayer support?",
    ],
    "kb-spice": [
        "What does the LDO power simulation show?",
        "How is the WiFi TX burst modeled in SPICE?",
        "What is the voltage droop under load?",
        "How are decoupling capacitors modeled?",
        "What is the SPICE model for the AMS1117?",
    ],
    "kb-components": [
        "What is the ESP32-S3-WROOM-1-N16R8 module?",
        "What are the specifications of the AMS1117-3.3?",
        "What is the ICS-43434 MEMS microphone?",
        "What is the PCM5101 I2S DAC?",
        "What USB-C connector is used?",
    ],
}


def rag_query(collection: str, question: str) -> dict | None:
    """Query RAG pipeline and return the response."""
    try:
        resp = requests.post(
            f"{MASCARADE_URL}/v1/rag/query",
            json={"query": question, "collection": collection, "retrieve_k": 5, "rerank_top_k": 3},
            timeout=30,
        )
        if resp.status_code == 200:
            return resp.json()
    except requests.RequestException:
        pass
    return None


def rag_search(collection: str, question: str) -> list[str]:
    """Search RAG and return matching text chunks."""
    try:
        resp = requests.post(
            f"{MASCARADE_URL}/v1/rag/search",
            json={"query": question, "collection": collection, "limit": 3},
            timeout=15,
        )
        if resp.status_code == 200:
            data = resp.json()
            return [r["text"] for r in data.get("results", []) if r.get("text")]
    except requests.RequestException:
        pass
    return []


def generate_entries(collection: str, questions: list[str]) -> list[dict]:
    """Generate dataset entries from RAG queries."""
    entries = []
    for q in questions:
        # Try full query first (with LLM synthesis)
        result = rag_query(collection, q)
        if result and result.get("answer"):
            entries.append({
                "instruction": q,
                "input": "",
                "output": result["answer"],
                "source": f"rag:{collection}",
                "generated_at": datetime.now(timezone.utc).isoformat(),
            })
            print(f"  [query] {q[:60]}... → {len(result['answer'])} chars")
            continue

        # Fallback: search + format context as answer
        chunks = rag_search(collection, q)
        if chunks:
            context = "\n\n".join(chunks[:3])
            entries.append({
                "instruction": q,
                "input": "",
                "output": context,
                "source": f"rag-search:{collection}",
                "generated_at": datetime.now(timezone.utc).isoformat(),
            })
            print(f"  [search] {q[:60]}... → {len(context)} chars")
        else:
            print(f"  [skip] {q[:60]}... → no results")

    return entries


def main():
    parser = argparse.ArgumentParser(description="Generate HF dataset from RAG")
    parser.add_argument("--collection", "-c", help="RAG collection name")
    parser.add_argument("--output", "-o", help="Output JSONL file path")
    parser.add_argument("--all", action="store_true", help="Generate for all collections")
    parser.add_argument("--output-dir", "-d", default="datasets", help="Output dir for --all")
    args = parser.parse_args()

    if args.all:
        out_dir = Path(args.output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        total = 0
        for coll, questions in SEED_QUESTIONS.items():
            print(f"\n=== Collection: {coll} ({len(questions)} questions) ===")
            entries = generate_entries(coll, questions)
            out_path = out_dir / f"{coll.replace('-', '_')}_qa.jsonl"
            with open(out_path, "w") as f:
                for e in entries:
                    f.write(json.dumps(e, ensure_ascii=False) + "\n")
            print(f"  → {len(entries)} entries written to {out_path}")
            total += len(entries)
        print(f"\nTotal: {total} entries across {len(SEED_QUESTIONS)} collections")
    elif args.collection:
        questions = SEED_QUESTIONS.get(args.collection, [])
        if not questions:
            print(f"No seed questions for collection '{args.collection}'")
            print(f"Available: {list(SEED_QUESTIONS.keys())}")
            sys.exit(1)
        print(f"Collection: {args.collection} ({len(questions)} questions)")
        entries = generate_entries(args.collection, questions)
        out_path = Path(args.output or f"datasets/{args.collection.replace('-','_')}_qa.jsonl")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w") as f:
            for e in entries:
                f.write(json.dumps(e, ensure_ascii=False) + "\n")
        print(f"\n{len(entries)} entries written to {out_path}")
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
