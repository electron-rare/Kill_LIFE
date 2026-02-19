# Mistral RAG (local index)

This pack includes a simple local semantic index using Mistral embeddings.

## Build the index
```bash
python tools/mistral/index_repo.py
```

## Search
```bash
python tools/mistral/search_index.py --query "scope guard" --topk 5
```

## Notes
- Minimal numpy index (cosine similarity).
- For large repos, consider a vector DB later.
