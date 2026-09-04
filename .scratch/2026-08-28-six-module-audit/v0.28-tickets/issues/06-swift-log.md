# Issue 06 — adopt `apple/swift-log` (1.5.4)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

Apple 官方日志门面 (uniform Logger(label:) API + pluggable LogHandler)

## Adapter / integration note

observability layer for wenshu CLI / daemon / future background agents

## Trigger condition (when to actually use it)

v0.28+ 增加 wenshu CLI / 后台 agent 时

## Module + dimension + ADR-0008 carve-out

M6 Settings & Library · engineering management

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

First-party Apple, Apache 2.0; lowest risk

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/06-swift-log.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
