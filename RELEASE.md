# Release Process

## Versioning Scheme

Kill_LIFE follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR** (X.0.0) — incompatible API changes, breaking firmware protocol changes
- **MINOR** (0.X.0) — new features (MCP tools, firmware capabilities, new board support)
- **PATCH** (0.0.X) — bug fixes, documentation, non-breaking improvements

Pre-release suffixes: `-alpha.N`, `-beta.N`, `-rc.N`

The canonical version lives in the `VERSION` file at the repository root.
`pyproject.toml` must stay in sync.

## Creating a Release

1. **Prepare the release branch** (optional for patch releases):
   ```bash
   git checkout -b release/0.2.0 main
   ```

2. **Update the version**:
   ```bash
   echo "0.2.0" > VERSION
   ```
   Also update `pyproject.toml`:
   ```toml
   version = "0.2.0"
   ```

3. **Commit the version bump**:
   ```bash
   git add VERSION pyproject.toml
   git commit -m "chore: bump version to 0.2.0"
   ```

4. **Create an annotated tag**:
   ```bash
   git tag -a v0.2.0 -m "Release 0.2.0 — short description of highlights"
   ```

5. **Push the tag** (this triggers the release workflow):
   ```bash
   git push origin main
   git push origin v0.2.0
   ```

6. The GitHub Actions workflow will:
   - Validate the tag matches the `VERSION` file
   - Run tests
   - Build the Python package and firmware binary
   - Create a GitHub Release with auto-generated changelog
   - Attach build artifacts (`.whl`, `.tar.gz`, `firmware.bin`)

## Hotfix Process

For urgent fixes against a released version:

1. **Branch from the release tag**:
   ```bash
   git checkout -b hotfix/0.1.1 v0.1.0
   ```

2. **Apply the fix**, update `VERSION` to `0.1.1`, commit.

3. **Tag and push**:
   ```bash
   git tag -a v0.1.1 -m "Hotfix 0.1.1 — description of fix"
   git push origin hotfix/0.1.1
   git push origin v0.1.1
   ```

4. **Merge the hotfix back into main**:
   ```bash
   git checkout main
   git merge hotfix/0.1.1
   ```

## Backport Policy

- **Critical security fixes**: backported to the latest minor release branch.
- **Bug fixes**: backported only if the affected version is still actively used on deployed hardware.
- **Features**: never backported. Users should upgrade to the latest minor release.

Backport branches follow the naming convention `backport/<fix-description>-to-<version>`.

## Pre-releases

For testing before a stable release:

```bash
echo "0.2.0-rc.1" > VERSION
git tag -a v0.2.0-rc.1 -m "Release candidate 1 for 0.2.0"
git push origin v0.2.0-rc.1
```

Pre-releases are automatically marked as such on GitHub when the tag contains
`-alpha`, `-beta`, or `-rc`.
