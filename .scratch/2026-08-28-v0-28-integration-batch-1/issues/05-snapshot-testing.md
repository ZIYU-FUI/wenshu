# Issue 05 — add `pointfreeco/swift-snapshot-testing` 1.19.4 to testTarget

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Add `swift-snapshot-testing` to `Package.swift` dependencies + `testTarget` only (NEVER runtime target, per README warning). No source-code changes.

## Why

- 2026-08-28-six-module-audit / M1 recommended this for ticket 028-011 (drag-lost regression suite).
- ADR-0008 §"Does NOT apply to" explicitly extends to test tooling.
- `ViewInspector` already in testTarget; swift-snapshot-testing is complementary (= structure + pixel assertions).

## Acceptance criteria

- `Package.swift`:
  - `.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4"),` in dependencies
  - `.product(name: "SnapshotTesting", package: "swift-snapshot-testing"),` in testTarget ONLY (NOT executableTarget)
- AGENTS.md §11.1 row updated to reflect version
- `swift package resolve` exit 0
- `swift build` exit 0
- `swift test` exit 0 (verify existing tests still pass; verify SnapshotTesting is NOT pulled into executableTarget)

## Test results

- PENDING

## UI verify (boss)

N/A — testTarget only.

## Status: PENDING