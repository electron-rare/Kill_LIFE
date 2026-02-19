# Mistral integration pack

This template can use Mistral for:
- **Code**: Codestral / Devstral
- **Specs/Docs**: Mistral Small/Medium/Large
- **RAG**: `mistral-embed` embeddings

## Keys & endpoints
Set:
- `MISTRAL_API_KEY` (required)
- `MISTRAL_API_BASE` (optional)

Some setups use a different base URL for Codestral. See `docs/CONTINUE_SETUP.md`.

## Recommended models by role
- PM/Doc: `mistral-small-latest` or `mistral-medium-latest`
- Architect: `mistral-large-latest`
- Firmware/Implementation: `codestral-latest`
- QA (tests/refactors): `devstral-*` or `codestral-latest`

## Safe-output approach (critical)
This pack uses **JSON-mode structured patches**:
1) generate `SafePatch` JSON (no repo writes)
2) validate schema + scope allowlists
3) apply patch (writes files only; never runs commands)

See `docs/MISTRAL_AGENTIC.md`.
