#!/usr/bin/env python3
"""
Search the local .mistral_index with cosine similarity.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Tuple

import numpy as np

from tools.mistral.mistral_client import get_client


def cosine_topk(matrix: np.ndarray, q: np.ndarray, k: int) -> Tuple[List[int], np.ndarray]:
    m = matrix / (np.linalg.norm(matrix, axis=1, keepdims=True) + 1e-9)
    qn = q / (np.linalg.norm(q) + 1e-9)
    scores = m @ qn
    return list(np.argsort(-scores)[:k]), scores


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--query", required=True)
    ap.add_argument("--index", default=".mistral_index")
    ap.add_argument("--model", default="mistral-embed")
    ap.add_argument("--topk", type=int, default=5)
    args = ap.parse_args()

    idx_dir = Path(args.index)
    meta_path = idx_dir / "meta.jsonl"
    vec_path = idx_dir / "vectors.npy"
    if not meta_path.exists() or not vec_path.exists():
        raise SystemExit("Index not found. Run: python tools/mistral/index_repo.py")

    metas = [json.loads(line) for line in meta_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    vecs = np.load(vec_path)

    client = get_client()
    resp = client.embeddings.create(model=args.model, inputs=[args.query])
    q = np.array(resp.data[0].embedding, dtype=np.float32)

    ids, scores = cosine_topk(vecs, q, args.topk)
    print("Top matches:")
    for i in ids:
        m = metas[i]
        print(f"- {m['path']} (chunk {m['chunk']}) score={float(scores[i]):.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
