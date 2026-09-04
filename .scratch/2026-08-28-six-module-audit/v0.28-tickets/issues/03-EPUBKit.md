# Issue 03 — adopt `witekbobrowski/EPUBKit` (0.5.0)

> Parent spec: `.scratch/2026-08-28-six-module-audit/v0.28-tickets/spec.md`
> Audit verdict: `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
> Boss拍 2026-08-28 OOB: full audit adopted = 7 NEW deps cleared + 4 version bumps

## What it does

纯 Swift EPUB 2/3 解析 (ZIP + OPF spine + NCX 导航 + Dublin Core)

## Adapter / integration note

adapter 协议 EPUBImportService 包一层; 替换 = 1-file change

## Trigger condition (when to actually use it)

M3 EPUB import 菜单项落地时 → feeds M5-15 LLM Wiki pipeline (= 抽核心设定 + 文风 fingerprint 进 reference-library)

## Module + dimension + ADR-0008 carve-out

M3 Project / Manuscript Manager · Swift framework

AGENTS.md §11.1 four-condition gate: **PASS** (per per-module audit at `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` through `M6-settings-library.md`).

ADR-0008 view-framework FORBIDDEN carve-out: **not applicable** (library does NOT claim pane / dock / split / drag ownership).

## Risk note

Sole maintainer 5mo stale; bus factor = 1; mitigation = adapter protocol

## Acceptance criteria

- `swift package resolve` exit 0
- `swift build` exit 0
- AGENTS.md §11.1 row added (or version bumped) in same commit
- `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/03-EPUBKit.md` archived (= this file)

## Implementation order

Per spec.md dependency graph: independent (no blockers). All 11 adoptions can land in parallel across 1-2 sprint cycles.

## Test results

- PENDING (lands with the wiring ticket that consumes it)

## UI verify (boss)

N/A — build-time Package.swift + AGENTS.md change; no user-visible UI until the feature ticket that consumes this lib ships.

## Status: PENDING (lands with consuming feature ticket)
