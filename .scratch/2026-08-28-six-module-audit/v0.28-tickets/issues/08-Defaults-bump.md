# Issue 08 — adopt `sindresorhus/Defaults` (9.0.8)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

UserDefaults typed wrapper (自动 Codable + @Observable + 类型安全) — 版本 bump

## Adapter / integration note

8.2.0 → 9.0.8 ≈ 1.5-yr gap; v9 引入 breaking changes

## Trigger condition (when to actually use it)

v0.28 chat history migration ticket 时 (= first consumer of complex Codable UserDefaults)

## Module + dimension + ADR-0008 carve-out

M6 Settings & Library · Swift framework (bump)

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

老板拍 v8 → v9 breaking-change risk 由 ticket 评估

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/08-Defaults-bump.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
