# Issue 02 — adopt `smittytone/HighlighterSwift` (3.1.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

纯 Swift 代码语法高亮 (185 种语言, 89 个主题, 不带 JS engine)

## Adapter / integration note

UI leaf primitive — token 列表 + Textual preview 接彩色

## Trigger condition (when to actually use it)

M2 章节 preview 落地时 (Code-fence syntax highlight)

## Module + dimension + ADR-0008 carve-out

M2 Book Reader & Editor · UI enhancement

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

Stars = 105 = 100 门槛刚好过; thin margin 5★; mitigation = swift-markdown-engine 1.0 transitive

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/02-HighlighterSwift.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
