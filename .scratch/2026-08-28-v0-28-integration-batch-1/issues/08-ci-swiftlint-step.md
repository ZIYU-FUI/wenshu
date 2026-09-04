# Issue 08 — `.github/workflows/ci.yml` SwiftLint step addition

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Add a `swiftlint` step to `.github/workflows/ci.yml` (= existing commit-lint job). Runs `swiftlint lint` (= lint-only, no auto-fix). Add parallel job for `swiftformat --lint Sources Tests`.

## Why

- AGENTS.md §11/§12 rules should be enforced by CI (= not by per-commit code review alone).
- Existing `.github/workflows/ci.yml` already has build-and-test + lint-commits; this extends to lint-source.
- SwiftLint rules to enable: `force_cast`, `force_try`, `identifier_name`, `custom_rules` (for [forbidden-vocab-1] tokens etc.).

## What the new job does

1. Install SwiftLint via Homebrew (`brew install swiftlint`).
2. Run `swiftlint lint --quiet` (= lint-only).
3. Install SwiftFormat via Homebrew.
4. Run `swiftformat --lint Sources Tests`.
5. Fail the job on either step non-zero.

## Acceptance criteria

- `.github/workflows/ci.yml` has a new job `lint-source`.
- Job installs SwiftLint + SwiftFormat via `brew install`.
- Job runs both lint commands.
- Job fails on non-zero exit.
- Locally: `swiftlint lint --quiet` returns 0 against current `Sources/` (verify no false positives).

## Test results

- PENDING

## UI verify (boss)

N/A — CI tooling only.

## Status: PENDING