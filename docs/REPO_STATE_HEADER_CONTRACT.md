# REPO_STATE Header Contract

Version: `v1`

## Source of truth

The global response header MUST be derived only from each configured repository file:

- `docs/REPO_STATE.md`

No free-form manual edits are allowed in generated outputs.

## Required local files (Kill_LIFE)

- `tools/repo_state/collect.py`
- `tools/repo_state/repo_refresh.sh`
- `tools/repo_state/lint_header_contract.py`
- `docs/REPO_STATE.md`
- `docs/repo_state.json`
- `tools/repo_state/repo_refresh.sh` (targets default: Kill_LIFE)

## Header format (mandatory)

```md
[REPO-STATE UTC: <timestamp>]
Kill_LIFE                    | HEAD <sha> | pivots: <...> | gates: <...>
[/REPO-STATE]
```

## Contract checks

`repo_state_header_gate` MUST fail if any of the following is true:

- missing `<!-- REPO_STATE:v1 -->` marker in `docs/REPO_STATE.md`
- missing required keys in `docs/REPO_STATE.md` or `docs/repo_state.json`
- malformed header markers in `artifacts/repo_state/header.latest.md`
- missing the repository line in the generated header

## Commands

Generate local state:

```bash
python tools/repo_state/collect.py --repo-name Kill_LIFE
```

Generate global artifacts:

```bash
tools/repo_state/repo_refresh.sh
```

Header only:

```bash
tools/repo_state/repo_refresh.sh --header-only
```

JSON only:

```bash
tools/repo_state/repo_refresh.sh --json-only
```
