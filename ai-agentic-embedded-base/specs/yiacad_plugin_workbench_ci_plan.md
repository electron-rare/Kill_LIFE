# Plan - YiACAD plugin, workbench, QA, and CI/CD

## Intent

Define the implementation boundary for:

- the YiACAD KiCad extension
- the YiACAD FreeCAD workbench
- the integrated test and QA model
- the CI/CD layout that validates the 2026 stack

## 1. KiCad integration plan

### Product role

- provide the native ECAD authoring and review lane inside YiACAD desktop
- expose YiACAD commands where ECAD operators already work

### Boundary

- live integration through `IPC API`
- typed helper layer through `kicad-python`
- batch/export/review through `kicad-cli`
- optional distribution through `Plugin and Content Manager`

### Minimum feature set

- `YiACAD Status`
- `YiACAD ERC/DRC`
- `YiACAD BOM Review`
- `YiACAD Sync Export`
- `Open YiACAD Review Center`

### Rules

- the plugin MUST call the YiACAD backend, not reimplement product logic
- no dependency on deprecated SWIG bindings
- no silent writeback to projects
- every command MUST return normalized evidence and next steps

## 2. FreeCAD integration plan

### Product role

- provide the native MCAD inspection, sync, and export lane inside YiACAD desktop

### Boundary

- Python API
- YiACAD workbench package
- addon packaging for distribution/update when needed

### Minimum feature set

- `YiACAD Status`
- `YiACAD ECAD/MCAD Sync`
- `YiACAD Artifact Browser`
- `YiACAD Explain Selection`

### Rules

- the workbench remains an adapter into YiACAD, not the product shell
- FreeCAD document actions MUST publish artifacts and provenance
- MCAD sync MUST preserve explicit degraded states when ECAD inputs are missing

## 3. Backend and action model

- desktop extensions call `yiacad_backend_client.py` or the stable local service
- web worker calls the same action registry
- `KiBot` and `KiAuto` MUST only appear behind backend actions
- action families:
  - `review.*`
  - `sync.*`
  - `manufacturing.export`
  - `manufacturing.validate`
  - `status.*`

## 4. QA strategy

### Fixture classes

- KiCad-only board project
- FreeCAD-only model project
- mixed ECAD/MCAD project
- manufacturing-ready project
- intentionally degraded project with missing runtime or missing design input

### Evidence required

- normalized JSON output
- artifact manifest
- runner logs
- engine status snapshot
- next steps digest

### Required test lanes

- unit tests for adapters and contract shaping
- contract tests for backend schemas
- integration tests for backend <-> engines
- end-to-end tests on fixture projects
- regression tests for degraded mode

## 5. CI/CD target state

### Blocking PR lanes

- `yiacad-contracts-and-python`
- `yiacad-web-build-and-tests`
- `yiacad-backend-integration`
- `yiacad-cad-smokes`

### Blocking main/release lanes

- all PR lanes
- `yiacad-manufacturing-bundle`
- `yiacad-evidence-pack`

### Scheduled lanes

- nightly extended CAD matrix
- nightly packaging smoke
- nightly representative project matrix

## 6. Runner policy

### macOS runners

- desktop integration smokes
- KiCad extension smoke
- FreeCAD workbench smoke
- backend surface checks

### Linux runners

- `KiBot`
- `KiAuto`
- deterministic manufacturing bundle jobs
- nightly representative project matrix

### Rule

- manufacturing jobs MUST not depend on developer desktops

## 7. Workflow shape

### yiacad-contracts-and-python

- validate schemas and examples
- run stable Python test suite
- fail on contract drift

### yiacad-web-build-and-tests

- install dependencies
- typecheck
- build web app
- run unit and integration web tests

### yiacad-backend-integration

- start local backend service
- execute backend client tests
- verify normalized outputs and engine status reporting

### yiacad-cad-smokes

- macOS smoke for `KiCad >= 10.0`
- macOS smoke for `FreeCAD >= 1.1`
- verify extension/workbench handshake and core commands

### yiacad-manufacturing-bundle

- Linux runner
- pinned container image
- run `KiBot` package and `KiAuto` checks on fixtures
- publish artifacts and evidence

### yiacad-evidence-pack

- collect logs, reports, normalized outputs, and generated artifacts
- emit a release-readable summary

## 8. Release gates

- backend contracts valid
- desktop extension/workbench smokes pass
- manufacturing lane passes on at least one representative fixture
- evidence pack published
- degraded states are explicit and actionable

## 9. Non-goals

- browser-native CAD editing in this plan
- custom forks of KiCad or FreeCAD as release prerequisite
- direct client access to `KiBot` or `KiAuto`

## References

- stack target: `specs/yiacad_2026_stack_target_spec.md`
- ADR: `specs/yiacad_adr_20260329_sot.md`
- 90 day plan: `specs/yiacad_90_day_delivery_plan.md`
- orchestration UX: `specs/yiacad_tux004_orchestration_spec.md`
- backend architecture: `specs/yiacad_backend_architecture_spec.md`
