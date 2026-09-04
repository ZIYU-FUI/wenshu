# Issue 01 — adopt `realm/SwiftLint` 0.65.1 + add Brewfile entry

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`

## What

Adopt SwiftLint 0.65.1 (binary tool, not a SwiftPM dep) + add to `Brewfile` at repo root + verify integration with `.github/workflows/ci.yml` and `Tools/wenshu-devtool/commit_filter.py`.

## Why

- AGENTS.md §11.1 lists SwiftLint + SwiftFormat in the "DEV / TEST only (no runtime impact)" approved bucket.
- The 2026-08-28-six-module-audit adopted both at version 0.65.1 (= SwiftLint bumped from the 0.62.1 in the audit per `brew info swiftlint` 2026-08-28 returning 0.65.1 as latest stable; SwiftFormat stayed at 0.62.1 per its brew info).
- `Tools/wenshu-devtool/commit_filter.py` exists for commit-message linting but does not yet invoke `swiftlint` for source-file linting.
- No `Brewfile` exists at repo root yet (= gap; AGENTS.md §11.1 explicitly says "binary tooling via Brewfile").

## Where to add

1. New file `Brewfile` at repo root:
   ```ruby
   tap "realm/SwiftLint"
   brew "swiftlint", version: "0.65.1"
   brew "swiftformat", version: "0.62.1"
   ```
2. `.github/workflows/ci.yml`: add a new step "Run SwiftLint" between "Swift test" and the comment-lint step.
3. `Tools/wenshu-devtool/wenshu_devtool.py`: add a `lint` subcommand that invokes `swiftlint` + `swiftformat --lint`.

## Acceptance criteria

- `Brewfile` exists with both pinned versions
- `brew bundle --no-upgrade` exit 0 (= both tools install at pinned version)
- `swiftlint --version` returns `0.65.1`
- `.github/workflows/ci.yml` runs `swiftlint` (= lint job green)
- `Tools/wenshu-devtool/wenshu_devtool.py lint` runs without error
- No SwiftLint rules auto-applied (= lint-only, no auto-fix in CI)

## Test results

- PENDING

## UI verify (boss)

N/A — dev tooling only.

## Status: PENDING


## Forward-fix (= 2026-08-28 H3 fix commit)

This issue ticket was retroactively updated to match the actual installed version 0.65.1 (= per the Standards-axis sub-agent H3 forward-fix). The commit body for issue 01 (in 2c42cb22c) claimed the version bump but did not update this ticket file (= Q35 commit message 描述 vs 真值 drift); the forward-fix reconciles all sources of truth.

Per Q34 chain: spec → ticket → commit (not commit → spec). The 0.65.1 was correct (= verified by `brew info`), but the spec/ticket files needed the update too. Future batches: any version bump during implementation MUST also forward-fix the corresponding spec + ticket files in the same commit (= 3-file touch).
