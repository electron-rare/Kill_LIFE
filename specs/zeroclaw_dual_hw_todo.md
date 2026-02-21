# TODO: Dual Hardware Autonomy (RTC + Zacus)

Last updated: 2026-02-21

## Phase A: Local Baseline

- [ ] Run `tools/ai/zeroclaw_dual_bootstrap.sh` and capture hardware snapshot.
- [ ] Validate `tools/ai/zeroclaw_dual_chat.sh rtc -m "<diagnostic prompt>"`.
- [ ] Validate `tools/ai/zeroclaw_dual_chat.sh zacus -m "<diagnostic prompt>"`.
- [ ] Record detected ports and map preferred role per board.

## Phase B: Repo Specs and PR Cadence

- [ ] Create/refresh one issue in `RTC_BL_PHONE` for ZeroClaw-assisted hardware loop.
- [ ] Create/refresh one issue in `le-mystere-professeur-zacus` for ZeroClaw-assisted hardware loop.
- [ ] Open one small PR per repo focused on one gate (build, tests, hardware smoke, docs).
- [ ] Require code review pass before merge (`gh pr review --approve` only after checks).

## Phase C: Autonomy + Cost Optimization

- [ ] Keep prompts short, target one repo at a time.
- [ ] Use provider auto-fallback (`copilot` -> `openai-codex` -> `openrouter`) to avoid dead sessions.
- [ ] Add repo-level path filters in workflows to avoid expensive irrelevant runs.
- [ ] Use `workflow_dispatch` for hardware-required jobs to avoid noisy CI failures.

## Phase D: Hardware Robustness

- [ ] Add serial-port resolver step before every upload/flash action.
- [ ] Fail fast if no expected USB device is detected.
- [ ] Archive logs per run for replayability (`artifacts/<timestamp>/...`).

## Exit Criteria

- [ ] Both repos can be targeted with one command (`rtc` or `zacus`) without workspace leakage.
- [ ] Hardware discovery passes before action on connected boards.
- [ ] At least one successful PR cycle completed per repo with this orchestration path.
