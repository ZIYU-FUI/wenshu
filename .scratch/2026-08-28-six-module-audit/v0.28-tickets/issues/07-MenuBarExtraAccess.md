# Issue 07 — adopt `orchetect/MenuBarExtraAccess` (1.3.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

SwiftUI MenuBarExtra 的 show/hide/toggle 编程控制 (macOS 13+ MenuBarExtra 公开 API 不暴露这层)

## Adapter / integration note

macOS 平台集成 (falls under macOS platform integration allowed per ADR-0008)

## Trigger condition (when to actually use it)

v0.28+ 决定在菜单栏加 wenshu 入口时

## Module + dimension + ADR-0008 carve-out

M6 Settings & Library · UI enhancement (macOS platform)

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

218 stars / 2025-02-25 / MIT; macOS 13+ required

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/07-MenuBarExtraAccess.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
