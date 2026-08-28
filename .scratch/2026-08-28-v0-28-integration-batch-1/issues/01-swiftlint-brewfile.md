# Issue 01 — adopt `realm/SwiftLint` 0.62.1 + add Brewfile entry

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`

## What

Adopt SwiftLint 0.62.1 (binary tool, not a SwiftPM dep) + add to `Brewfile` at repo root + verify integration with `.github/workflows/ci.yml` and `Tools/wenshu-devtool/commit_filter.py`.

## Why

- AGENTS.md §11.1 lists SwiftLint + SwiftFormat in the "DEV / TEST only (no runtime impact)" approved bucket.
- The 2026-08-28-six-module-audit adopted both at version 0.62.1.
- `Tools/wenshu-devtool/commit_filter.py` exists for commit-message linting but does not yet invoke `swiftlint` for source-file linting.
- No `Brewfile` exists at repo root yet (= gap; AGENTS.md §11.1 explicitly says "binary tooling via Brewfile").

## Where to add

1. New file `Brewfile` at repo root:
   ```ruby
   tap "realm/SwiftLint"
   brew "swiftlint", version: "0.62.1"
   brew "swiftformat", version: "0.62.1"
   ```
2. `.github/workflows/ci.yml`: add a new step "Run SwiftLint" between "Swift test" and the comment-lint step.
3. `Tools/wenshu-devtool/wenshu_devtool.py`: add a `lint` subcommand that invokes `swiftlint` + `swiftformat --lint`.

## Acceptance criteria

- `Brewfile` exists with both pinned versions
- `brew bundle --no-upgrade` exit 0 (= both tools install at pinned version)
- `swiftlint --version` returns `0.62.1`
- `.github/workflows/ci.yml` runs `swiftlint` (= lint job green)
- `Tools/wenshu-devtool/wenshu_devtool.py lint` runs without error
- No SwiftLint rules auto-applied (= lint-only, no auto-fix in CI)

## Test results

- PENDING

## UI verify (boss)

N/A — dev tooling only.

## Status: PENDING