# Issue to PR Walkthrough

Step-by-step guide: from opening an issue to merging a PR in Kill_LIFE.

## 1. Open an Issue

Go to **Issues > New Issue** and pick a template:

| Template | Use case |
|---|---|
| `systems-engineering.yml` | New feature or hardware change |
| `consulting-intake.yml` | Bug report or general request |
| `compliance-release.yml` | Compliance profile or release |
| `rnd-spike.yml` | Research spike or agentic update |

Fill in the required fields. The template will guide you through context, constraints, and acceptance criteria.

## 2. Triage and Label

The issue is triaged (weekly or on creation). Labels are applied:

- **Type**: `type:feature`, `type:bug`, `type:compliance`, `type:process`
- **AI workflow**: `ai:spec`, `ai:plan`, `ai:tasks`, `ai:impl`, `ai:qa`, `ai:hold`

The `ai:*` label determines which workflow step the agent will execute.

## 3. Write or Update the Spec

If the issue requires a spec (`ai:spec` label):

```bash
# Create spec structure
mkdir -p specs/
# Edit the relevant spec file
$EDITOR specs/01_spec.md
```

Spec rules:
- Use RFC 2119 keywords (MUST, SHOULD, MAY)
- Each requirement must be verifiable
- Include acceptance criteria (functional + non-functional)

Validate:
```bash
python3 tools/validate_specs.py
```

## 4. Create a Branch

```bash
git checkout -b feat/42-my-feature main
```

Naming convention: `feat/`, `fix/`, `chore/`, `docs/` prefix + issue number + short slug.

## 5. Implement

Write your code, tests, and docs. Key commands:

```bash
# Build firmware
python3 tools/build_firmware.py

# Run native tests
python3 tools/test_firmware.py

# Run integration tests (simulated)
bash tools/test_integration_hil.sh --sim

# Run spec validation
python3 tools/validate_specs.py

# Run compliance check
python3 tools/compliance/validate.py

# Run scope guard (checks file paths vs label policy)
python3 tools/scope_guard.py
```

## 6. Commit

```bash
git add <files>
git commit -m "feat(hw): implement feature X for issue #42

- Added sensor driver
- Updated spec with measured values
- Tests pass (native + simulated HIL)"
```

## 7. Push and Open PR

```bash
git push -u origin feat/42-my-feature
gh pr create --title "feat(hw): implement feature X" --body "Closes #42"
```

The PR template will prompt you to:
- Link the spec (`specs/___`)
- Check off acceptance criteria
- Confirm all verification steps pass

## 8. CI Checks

The following checks run automatically:

| Check | What it does |
|---|---|
| `ci` | Build + native tests |
| `scope-guard` | Verifies files modified match the `ai:*` label policy |
| `evidence-pack` | Collects compliance evidence |
| `secret-scan` | Scans for leaked secrets |
| `spec-lint` | Validates spec format |

All required checks must pass before merge.

## 9. Review

- At least 1 reviewer must approve
- Sensitive paths (`.github/`, `tools/security/`, `compliance/`) require CODEOWNERS review
- Reviewer checks: AC met, tests adequate, no scope creep

## 10. Merge

Once approved and green:
- Use **Squash and merge** for feature branches
- The PR title becomes the commit message
- The issue is auto-closed via `Closes #42` in the PR body

## Quick Reference

```
Issue ──> Label ──> Spec ──> Branch ──> Code ──> Test ──> PR ──> CI ──> Review ──> Merge
  │         │        │                    │                │       │
  └─ template    ai:* label         validate_specs    scope_guard │
                                    test_firmware     evidence_pack
                                    compliance/validate
```

## See Also

- `docs/AI_WORKFLOWS.md` — Full agentic workflow diagram
- `docs/INSTALL.md` — Dev environment setup
- `docs/RUNBOOK.md` — Operations runbook
- `specs/` — All specifications
