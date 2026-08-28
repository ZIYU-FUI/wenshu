# Issue 06 — add `scripts/setup-dev-env.sh` for new-dev bootstrap

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Add a shell script `scripts/setup-dev-env.sh` that runs `brew bundle` (= installs SwiftLint + SwiftFormat at pinned versions). Also runs any other one-time bootstrap steps the dev environment needs.

## Why

- New devs joining the project (= boss hires help or sets up new machine) need a single command to get to "ready to build".
- `brew bundle` reads the new `Brewfile` from issue 01.
- Prevents the "forgot to install swiftlint" failure mode (= pre-commit hook silently passes because binary missing).

## What the script does

1. Verify `brew` is installed (exit 1 with hint if missing).
2. Verify `swift` is installed (= check `swift --version`, exit 1 with hint if missing).
3. Run `brew bundle --no-upgrade` (= install pinned SwiftLint + SwiftFormat).
4. Verify tools reachable: `swiftlint --version`, `swiftformat --version`.
5. Print summary: "Dev environment ready. Run: swift build && swift test".

## Acceptance criteria

- `scripts/setup-dev-env.sh` exists with the above 5 steps.
- `bash scripts/setup-dev-env.sh` exit 0 (= all checks pass on a freshly-installed machine).
- Permission bit `chmod +x scripts/setup-dev-env.sh` (= executable).
- AGENTS.md or README updated to mention this script.

## Test results

- PENDING (manual test on a clean machine)

## UI verify (boss)

N/A — dev tooling only.

## Status: PENDING