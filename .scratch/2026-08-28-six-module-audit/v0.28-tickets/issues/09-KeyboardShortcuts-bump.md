# Issue 09 — adopt `sindresorhus/KeyboardShortcuts` (2.2.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

允许用户在 System Settings 重绑全局快捷键 (= 取代写死 .keyboardShortcut) — 版本 bump

## Adapter / integration note

1.10.0 → 2.2.0 ≈ 1.5-yr gap; v2 / v3 major jumps exist

## Trigger condition (when to actually use it)

v0.28+ Settings pane 加 Keyboard 标签页时

## Module + dimension + ADR-0008 carve-out

M6 Settings & Library · Swift framework (bump)

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

老板拍 v1 → v2 breaking-change risk 由 ticket 评估

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/09-KeyboardShortcuts-bump.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
