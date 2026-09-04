# Issue 01 — adopt `pointfreeco/swift-snapshot-testing` (1.19.4)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

SwiftUI 像素快照对比 (= 让 drag UX regression 在 CI 被卡住, 不会让你 macOS 上跑出来才发现)

## Adapter / integration note

testTarget only; 跟 ViewInspector 互补 (= structure assertion + pixel snapshot)

## Trigger condition (when to actually use it)

v0.28 ticket 028-011 (drag-lost regression suite)

## Module + dimension + ADR-0008 carve-out

M1 Workspace Shell · testTarget · dev only

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

Pure test dep, no runtime impact

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/01-snapshot-testing.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
