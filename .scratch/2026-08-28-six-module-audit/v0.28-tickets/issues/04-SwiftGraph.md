# Issue 04 — adopt `davecom/SwiftGraph` (4.0.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

纯 Swift 图算法 (BFS / DFS / Dijkstra / Prim / Kruskal)

## Adapter / integration note

pure data — wraps in Core/Graph/SwiftGraphAdapter.swift

## Trigger condition (when to actually use it)

M4 伏笔图算法 ticket 落地时

## Module + dimension + ADR-0008 carve-out

M4 Foreshadowing & Plot Web · Swift framework

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

811 stars / 2026-03-05 / Apache-2.0; clean spec, active maintenance

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/04-SwiftGraph.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
