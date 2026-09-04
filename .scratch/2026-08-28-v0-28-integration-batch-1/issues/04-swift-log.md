# Issue 04 — adopt `apple/swift-log` 1.5.4

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Add `swift-log` to `Package.swift` (= Apple first-party Logger API). Defer consumer wiring to future M6 telemetry ticket (out of scope here).

## Why

- 2026-08-28-six-module-audit adopted at 1.5.4.
- Apple first-party = lowest risk.
- This ticket = pure Package.swift row add. No source-code changes.

## Acceptance criteria

- `Package.swift` line: `.package(url: "https://github.com/apple/swift-log", from: "1.5.4"),`
- AGENTS.md §11.1 row: "apple/swift-log · Apple Logger API (Apache-2.0, 4k stars, P3)"
- `swift package resolve` exit 0
- `swift build` exit 0
- `swift test` exit 0
- Zero consumer code added (= this ticket is dep preparation only)

## Test results

- PENDING

## UI verify (boss)

N/A — package pin add only.

## Status: PENDING