# Issue 05 — adopt `li3zhen1/Grape::ForceSimulation` (1.1.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

力导向图布局算法 (物理弹簧模拟, 关联强的节点自动聚拢)

## Adapter / integration note

ONLY ForceSimulation product (never Grape view = MiniMap+Toolbar+Panel)

## Trigger condition (when to actually use it)

M4 力导向伏笔图视觉化 ticket 落地时

## Module + dimension + ADR-0008 carve-out

M4 Foreshadowing & Plot Web · Swift framework

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

15mo stale (gate #2 fail 3mo) = WARN accepted per boss拍 A; ~700 LOC hand-rolled spring-force as fallback

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/05-ForceSimulation-Grape.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
