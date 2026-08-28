# Wenshu v0.28 integration batch 1 — 工程加固 + 首批4 adoptions

> Boss 2026-08-28 OOB: "整个项目" + "走完 8 步" (= Q34 po main flow 完整 checklist)

## Scope (= Q34 step 1)

This batch covers 4 adoptions (工程管理 + 低风险 framework bumps) + 3 工程加固 items, all running through Q34 8-step checklist (= spec → tickets → commit → build → test → review → domain → verify).

## Adopt-list (batch 1)

| # | Lib | Pin | Why batch 1 |
|---|---|---|---|
| 1 | `realm/SwiftLint` | 0.65.1 (= `brew info swiftlint` 2026-08-28 reports 0.65.1 as latest stable; supersedes the 0.62.1 cited in the six-module audit verdict which predated the current brew release) | binary tool, no runtime risk; needed for engineering hygiene (= AGENTS.md §11/§12 CI gate) |
| 2 | `nicklockwood/SwiftFormat` | 0.62.1 | binary tool, no runtime risk; pairs with SwiftLint (= pre-commit formatter) |
| 3 | `sindresorhus/Defaults` | 9.0.8 | UserDefaults typed wrapper bump; v9 has breaking changes but wenshu source already uses `@AppStorage` directly (not `Defaults` API), so zero source-code impact |
| 4 | `apple/swift-log` | 1.5.4 | Apple first-party; doesn't impact any source code that doesn't import it |

## Engineering hardening items (batch 1)

| # | Item | Why now |
|---|---|---|
| 1 | Add `Brewfile` to repo root | SwiftLint + SwiftFormat need version pinning (= AGENTS.md §11.1 "binary tooling via Brewfile + wenshu-devtool hooks chain") |
| 2 | Extend `Tools/wenshu-devtool/pollution_watchdog.py` to also scan staged `.swift` files for forbidden-vocab tokens (currently only scans `.md`/`.swift` but `commit_filter.py` already does this for `.swift`) | Verify the existing pattern is working + add `.swift` scan to watchdog for completeness |
| 3 | Add `.swift-format` config file at repo root | pairs with SwiftFormat binary (= format-on-save behavior) |
| 4 | Add `scripts/setup-dev-env.sh` that runs `brew bundle` (= installs SwiftLint + SwiftFormat at pinned versions) | bootstrap for new devs + CI |

## Deferred to batch 2 (= higher runtime risk)

- 5 `smittytone/HighlighterSwift` 3.1.0 (UI primitive, no ADR-0008 risk but needs consumer wiring ticket)
- 6 `witekbobrowski/EPUBKit` 0.5.0 (parser, has sole-maintainer risk, needs `EPUBImportService` adapter)
- 7 `davecom/SwiftGraph` 4.0.0 (algorithm, pure data, but consumes 8/27 ticket 028-001+ free-layout)
- 8 `li3zhen1/Grape::ForceSimulation` 1.1.0 (WARN 15mo stale, needs `ForceSimulationAdapter.swift` wrapper per boss拍 A)
- 9 `orchetect/MenuBarExtraAccess` 1.3.0 (macOS platform integration, needs menu shape ticket)
- 10 `sindresorhus/KeyboardShortcuts` 2.2.0 (framework bump, but v1→v2 has breaking changes, needs Settings pane ticket first)

## Deferred to batch 3 (= hermes-port, ~6,500 LOC across 9 tickets)

- M5 entity extraction / smart-query rewriter / cross-ref inject / LLM Wiki pipeline
- M6 Provider / Agent identity / MemoryManager / Skills hub / Cron scheduler

## Q34 step 1 → step 2 mapping

- ✅ step 1 = spec (= this file)
- step 2 = tickets (per-issue files at `.scratch/2026-08-28-v0-28-integration-batch-1/issues/NN-*.md`)
- step 3 = implement (Q124 1-ticket-1-commit, no batch commits)
- step 4 = swift build exit 0 (per commit)
- step 5 = swift test exit 0 (per commit; pre-existing 12 flaky tests tolerated)
- step 6 = dual-axis code review sub-agents (Standards + Spec per Q125)
- step 7 = CONTEXT.md domain-modeling commit (per spec)
- step 8 = Q22 CUA 真验证 (= app rebuild + 老板 macOS 验)

## Acceptance criteria

- All 4 adoptions land with `swift package resolve` exit 0 + `swift build` exit 0
- 0 new test failures vs baseline 7c1f548e0 (= all adoptions are pure Package.swift + AGENTS.md edits)
- Brewfile + scripts/setup-dev-env.sh + .swift-format land with `brew bundle --no-upgrade` exit 0
- pollution_watchdog.py + commit_filter.py verified against staged .swift files
- Dual-axis code-review sub-agent reports archived in `.scratch/2026-08-28-v0-28-integration-batch-1/code-review-{standards,spec}-axis.md`
- CONTEXT.md domain word entries added per Q34 step 7 (if any new concept introduced)
- AGENTS.md §11.1 reflects the 4 adopted versions (= version bumps land in same commit as Package.swift row add)

## Out of scope

- 5-10 from deferred batch 2 (= adoptions with runtime risk, scheduled separately)
- M5/M6 hermes-port from deferred batch 3
- v0.28 free-layout ticket 028-001+ (separate spec at `.scratch/2026-08-28-v0-28-free-layout/`)
- Bonsplit (rejected per ADR-0008 path C)
- [forbidden-vocab-1] literal tokens in commit body / source code (= pollution-defense hook active)


## Version reconciliation (forward-fix per Standards-axis H3 finding)

The original spec.md adopted SwiftLint 0.62.1 (= per the 2026-08-28-six-module-audit verdict) but the actual `brew info swiftlint` 2026-08-28 returned 0.65.1 (= latest stable). The 2c42cb22c commit body self-rationalized the bump to 0.65.1 (= "superseding the 0.62.1 from the six-module audit verdict") but the spec was not updated to match. This forward-fix reconciles the spec with the actual installed version (forward-fix commits = spec + ticket 01 + AGENTS.md). The decision criterion is: spec is the source of truth per Q34 chain (spec → tickets → commit), not commit body.

SwiftFormat stayed at 0.62.1 (= no drift; brew info returned 0.62.1 as latest stable for swiftformat).
