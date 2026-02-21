# Required checks friendly CI (economical + never blocks merges)

If you make a GitHub Actions check **required** in branch protection, GitHub expects that check to exist on **every** pull request.

A common failure mode is using `on: pull_request: paths:` filters (or similar) on a required workflow:
- the workflow is **skipped**,
- the required check never appears (or stays pending),
- and merges are blocked.

## The clean pattern used by the patches in this pack

1) Trigger required workflows on **all PRs** (remove `paths:` from `pull_request`).

2) Keep it **economical** by skipping heavy work **inside the job**:
- Run a fast path detector step (changed files filter)
- Gate heavy steps (`install`, `build`, `test`) behind `if:` conditions
- If nothing relevant changed, the job still completes **successfully**, but quickly.

This guarantees:
- The required check exists on every PR
- It reports success when irrelevant
- It still runs full builds/tests when relevant

## Apply the patches

From repo root:

```bash
git apply patches/firmware_ci_required_checks.patch
git apply patches/hardware_ci_required_checks.patch
git apply patches/compliance_gate_required_checks.patch
```

Then commit.

## Verify required check contexts

After your first PR, open **PR → Checks** and note the exact names, e.g.
- `Firmware CI / pio`
- `Scope Guard / guard`

Use those exact names in branch protection (the provided `setup_repo.sh` uses the defaults from the template).
