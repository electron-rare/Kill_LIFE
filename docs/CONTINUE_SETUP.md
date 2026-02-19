# VS Code Continue + Mistral (Codestral)

Continue supports Mistral as a model provider.

## Config (YAML)
Create `~/.continue/config.yaml`:

```yaml
name: My Config
version: 0.0.1
schema: v1
models:
  - name: Codestral
    provider: mistral
    model: codestral-latest
    apiKey: <YOUR_MISTRAL_API_KEY>
    apiBase: https://codestral.mistral.ai/v1
    roles:
      - chat
      - autocomplete
```

## Important
Continue notes that the API key for `codestral.mistral.ai` is different from `api.mistral.ai`
and you should set `apiBase` accordingly.
