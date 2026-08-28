# Issue 03 — bump `sindresorhus/Defaults` 8.2.0 → 9.0.8

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Bump `Defaults` from `from: "8.2.0"` to `from: "9.0.0"` (= SPM resolves to 9.0.8). Update AGENTS.md §11.1 row to reflect the bumped version. Verify zero source-code breakage.

## Why

- 2026-08-28-six-module-audit / M6 reported v8.2.0 → v9.0.8 ≈ 1.5-yr gap.
- boss拍 "v8 → v9 breaking-change risk 由 ticket 评估" (= evaluate at implementation time).
- Wenshu source inspection: `grep -rn 'import Defaults' Sources/ Tests/` to verify whether any source code actually uses Defaults API. If zero usages = bump is safe (the dep is unused, bump is purely a Pin for future feature work).

## Acceptance criteria

- `Package.swift` line: `.package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),`
- `Package.swift` line: `.product(name: "Defaults", package: "Defaults"),` (unchanged)
- AGENTS.md §11.1 row updated: "sindresorhus/Defaults · UserDefaults typed wrapper (MIT, 2.7k stars, P0, 9.0.8)"
- `swift package resolve` exit 0
- `swift build` exit 0
- `swift test` exit 0 (no new failures vs baseline 7c1f548e0)
- **Risk flag**: if any source code uses Defaults API, evaluate v9 breaking changes separately (per boss拍). If zero usages, this ticket is a pure pin bump.

## Test results

- PENDING

## UI verify (boss)

N/A — package pin update only; no source-code change unless Defaults API was used.

## Status: PENDING