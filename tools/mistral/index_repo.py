#!/usr/bin/env python3
"""
Create a simple local embedding index for this repo (specs/docs by default)
using Mistral embeddings.

Output:
  .mistral_index/
    meta.jsonl
    vectors.npy

Search:
  python tools/mistral/search_index.py --query "scope guard" --topk 5
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List

import numpy as np

from tools.mistral.mistral_client import get_client

DEFAULT_GLOBS = ["specs/**/*.md", "docs/**/*.md", "README.md"]


def iter_files(root: Path, globs: List[str]) -> List[Path]:
    out: List[Path] = []
    for g in globs:
        out.extend(root.glob(g))
    out = sorted({p for p in out if p.is_file()})
    return out


def chunk_text(text: str, max_chars: int = 3000) -> List[str]:
    chunks = []
    i = 0
    while i < len(text):
        chunks.append(text[i:i + max_chars])
        i += max_chars
    return chunks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--model", default="mistral-embed")
    ap.add_argument("--globs", nargs="*", default=DEFAULT_GLOBS)
    ap.add_argument("--out", default=".mistral_index")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out_dir = root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    files = iter_files(root, args.globs)
    if not files:
        raise SystemExit("No files matched.")

    client = get_client()
    meta_path = out_dir / "meta.jsonl"
    vec_path = out_dir / "vectors.npy"

    metas = []
    vectors = []

    for p in files:
        rel = str(p.relative_to(root)).replace("\\", "/")
        text = p.read_text(encoding="utf-8", errors="ignore")
        for idx, chunk in enumerate(chunk_text(text)):
            metas.append({"path": rel, "chunk": idx, "chars": len(chunk)})
            resp = client.embeddings.create(model=args.model, inputs=[chunk])
            vectors.append(resp.data[0].embedding)

    np.save(vec_path, np.array(vectors, dtype=np.float32))
    with meta_path.open("w", encoding="utf-8") as f:
        for m in metas:
            f.write(json.dumps(m, ensure_ascii=False) + "\n")

    print(f"Indexed {len(metas)} chunks from {len(files)} files into {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
