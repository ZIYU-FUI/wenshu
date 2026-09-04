# Issue 07 — verify + extend `Tools/wenshu-devtool/pollution_watchdog.py`

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Verify `Tools/wenshu-devtool/pollution_watchdog.py` correctly scans staged `.swift` files for the 12 forbidden-vocab tokens. Extend coverage if missing. Confirm it is wired into the pre-commit hook chain.

## Why

- pollution-defense contract: any future commit that writes a [forbidden-vocab-1] / [forbidden-vocab-2] / etc. literal in source MUST be blocked at pre-commit time (= not after-the-fact via dual-axis code review).
- The 2026-08-28[forbidden-vocab-1] hex-encoding commit (`2748bb8`) confirmed that the LLM can still write these literals accidentally.
- Sanity check: does the current watchdog already cover `.swift` files? If yes, document + verify. If no, extend + write a regression test.

## Acceptance criteria

- `Tools/wenshu-devtool/pollution_watchdog.py` scans the full working tree including `.swift` files for the 12-token xianxia list.
- `Tools/wenshu-devtool/commit_filter.py` scans staged `.swift` files for the same list (verify existing behavior).
- Pre-commit hook `Tools/wenshu-devtool/hooks/pre-commit` invokes both (= defense-in-depth).
- `Tools/wenshu-devtool/tests/test_block_added_line.sh` passes (= existing test still green).
- Add a new test `test_block_added_swift.sh` that creates a fake `.swift` file with the literal token, attempts to commit it, and verifies the hook blocks.

## Test results

- PENDING

## UI verify (boss)

N/A — dev tooling only.

## Status: PENDING