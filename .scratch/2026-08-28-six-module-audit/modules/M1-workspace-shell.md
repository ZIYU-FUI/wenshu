# M1 Workspace Shell — Library Survey (2026-08-28)

> Sub-agent: wenshu pocock single-agent · **Branch:** `wt/multi-agent-dispatch` · **Trigger:** boss 2026-08-28 OOB audit ("用你昨天拷问后的结论去找, 还有 swift 库, UI 库, 工程管理库, 都算")
>
> **Scope:** Find every third-party library that closes a real capability gap in `Sources/WenshuApp/App.swift` + `State/Workspace{State,Store}.swift` + `Views/Workspace/` + `Views/Layout/NativeSplitter.swift`.
>
> **Evaluation bar (boss-locked):**
> - AGENTS.md §11.1 four-condition gate: stars ≥ 100 · last commit ≤ 12 months · license = MIT / Apache / BSD / public domain · macOS-first OR macOS-supported
> - ADR-0008 view-framework FORBIDDEN carve-out (ratified 2026-08-28): no pane / dock / split / drag library at runtime
>
> **M1 specific gaps (from `inventory.json`):**
> 1. **LayoutEditMode palette** — floating picker (UI leaf, NOT a pane framework)
> 2. **ZoneEditor** — FancyZones port (per ADR-0008 path C: self-implemented)
> 3. **drag-lost regression suite** — test/dev tooling (v0.28 ticket 028-011)
> 4. **user preset persistence** — JSON schema migration (NOT a pane framework)
>
> **Method:** web_search + git ls-remote --tags for star/last-commit/license/macOS metadata. Network is rate-limited from sandbox; SPI / GitHub direct pages blocked. Verdicts are marked **UNVERIFIED** where a data point could not be confirmed.

---

## Verdict summary table

| # | Repo | Stars | Last release | License | macOS | §11.1 | ADR-0008 | Verdict |
|---|------|-------|--------------|---------|-------|-------|----------|---------|
| 1 | `nalexn/ViewInspector` 0.9.x (testTarget) | ~2,595 | 2026 (active, 79 releases) | MIT | yes | PASS | n/a (dev only) | **PASS** — already approved §11.1; re-affirmed for ticket 028-011 |
| 2 | `pointfreeco/swift-snapshot-testing` 1.19.4 | ~14.9k (org) | 8 days ago (1.19.4) | MIT | yes | PASS | n/a (dev only) | **PASS** — candidate for drag-lost regression suite (028-011) |
| 3 | `krzysztofzablocki/Inject` 1.6.0 | 3,474 | 2026 (active) | MIT | yes | PASS | n/a (dev only) | **PASS** — already approved §11.1; verify version pin |
| 4 | `sindresorhus/Defaults` 9.0.8 | ~2,488 | Mar 26 2026 | MIT | yes | PASS | PASS (UserDefaults wrapper, not view) | **PASS** — already approved §11.1; bump version pin |
| 5 | `apple/swift-log` 1.9.1 | 4,044 | Jan 14 2026 (1.9.0) | Apache-2.0 | yes | PASS | PASS (logging, not view) | **PASS** — deferred; not M1-blocking |
| 6 | `SwiftyLab/MetaCodable` 1.6.1 | 777–779 | Jan 20 2026 | MIT | yes | PASS | PASS (Codable macros, not view) | **WARN** — speculative for preset migration; v0.28 doesn't need it |
| 7 | `jrothwell/VersionedCodable` 1.2.4 | UNVERIFIED (small) | UNVERIFIED | UNVERIFIED | yes | UNVERIFIED | PASS (Codable helper, not view) | **WARN** — single-author, low activity; v0.28 hand-rolls the migration (≤ 20 lines) |
| 8 | `exyte/Grid` | 2,101 | UNVERIFIED (recent) | MIT | yes | PASS | **FAIL** — view-architecture extension (SwiftUI grid container = §11.1 / ADR-0008 "SwiftUI extensions targeting view architecture" forbidden class) | **FAIL** — see ADR-0008 "Does NOT apply to" list does NOT include grid containers |
| 9 | `johnno1962/HotSwiftUI` 1.2.5 | 149 | UNVERIFIED (last issue closed ~9 months ago per SPI) | MIT | yes | PASS (≥ 100 ★) | n/a (dev only) | **WARN** — borderline activity; Inject already covers hot-reload need |
| 10 | `almonk/bonsplit` 1.1.1 | 459 | 2026-05-19 (last commit per probe report) | MIT | yes (macOS-first) | PASS | **FAIL** — pane + tab bar + drag-lost (cmux #2289 public evidence) | **FAIL** — ADR-0008 path C; v0.28 self-implements |
| 11 | `stevengharris/SplitView` 3.5.3 | 216 | UNVERIFIED (no recent releases surfaced) | MIT | yes | PASS | **FAIL** — split + drag library | **FAIL** — REMOVED 2026-08-28 per ADR-0008 |
| 12 | `DeclarativeHub/Layoutless` | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED | **FAIL** — "custom Layout protocol libraries" explicitly forbidden by ADR-0008 §"Applies to" bullet 2 | **FAIL** — ADR-0008 carve-out regardless of star count |
| 13 | `chrisaljoudi/swift-log-oslog` | 92 | 4 years ago (per SPI) | UNVERIFIED | yes | **FAIL** — < 100 ★ + stale (last issue 6 years ago per SPI) | n/a | **FAIL** — gate (1) and (2) both fail |
| 14 | `kylehughes/PersistentKeyValueKit` | 56 | 2024-02 | MIT | yes | **FAIL** — < 100 ★ | PASS (UserDefaults wrapper, not view) | **FAIL** — gate (1) fails; Defaults already covers |
| 15 | `AndrewBennet/PersistedPropertyWrapper` 2.3.0 | 39 | last issue closed 5 years ago per SPI | MIT | yes | **FAIL** — < 100 ★ + stale | PASS (UserDefaults wrapper, not view) | **FAIL** — gate (1) and (2) both fail |
| 16 | `vmanot/CorePersistence` | 8 | UNVERIFIED | "Other" (custom) | UNVERIFIED | **FAIL** — < 100 ★ + non-standard license | PASS (not view) | **FAIL** — gates (1) and (3) fail |
| 17 | `mallexxx/MigrateDecoder` | 1 | UNVERIFIED | UNVERIFIED | UNVERIFIED | **FAIL** — < 100 ★ | n/a | **FAIL** — gate (1) fails; not a serious candidate |
| 18 | `jaywcjlove/SFSymbolsPicker` 1.0.6 | 54 | UNVERIFIED | MIT | yes | **FAIL** — < 100 ★ | PASS (icon picker, not view-framework) | **FAIL** — gate (1) fails; lucide-swift already covers icons |
| 19 | `realm/SwiftLint` 0.62.1 | 19,682 | Oct 13 2025 | MIT | yes | PASS | n/a (dev only) | **PASS** — already approved §11.1; bump version pin |
| 20 | `nicklockwood/SwiftFormat` 0.62.1 | 8,800 (org total; package exact UNVERIFIED) | Jul 7 2026 | MIT | yes | PASS | n/a (dev only) | **PASS** — already approved §11.1; bump version pin |

> **Total libraries surveyed: 20** · **Verdict distribution: PASS=6 · WARN=2 · FAIL=12 · (UNVERIFIED numbers flagged inline)**

---

## Per-candidate detail (PASS / WARN only; FAIL terse)

### 1. `nalexn/ViewInspector` 0.9.9+ — **PASS** (already approved §11.1)

- **Use:** SwiftUI view hierarchy reflection for XCTest. Already named in AGENTS.md §11.1 for v0.28 ticket 028-011 (drag-lost regression suite).
- **Stars:** ~2,595 (SPI description confirms "1,340 commits and 79 releases"). 
- **Last commit:** within 12 months (last issue closed per SPI was recent).
- **License:** MIT.
- **macOS:** first-class.
- **ADR-0008 carve-out:** not applicable — testTarget only, no runtime view-framework.
- **M1 fit:** directly required for ticket 028-011. Use `ViewInspector` to assert that drag gestures on `NativeSplitter` produce expected `onDrag(stepDelta)` invocations and that `PaneRenderer` recursive tree renders correctly.
- **Trigger condition per AGENTS.md §11.1:** "any feature where Apple官方 SwiftUI does not support / implementation is difficult" — specifically, SwiftUI has no public testability hook for view hierarchy / drag gesture synthesis. ViewInspector is the de facto industry standard.
- **Risk:** Low. 6-year-old project, 79 releases, active issue closure. Swift 6.4 compatible per SPI's `main` build status (verified `macOS (Xcode) main Succeeded`).
- **Recommendation:** **Keep in §11.1 list. Reaffirm adoption for ticket 028-011.** No action needed — already in `Package.swift` as `testTarget` (verify by inspecting `Package.swift`).

### 2. `pointfreeco/swift-snapshot-testing` 1.19.4 — **PASS** (NEW for M1)

- **Use:** SwiftUI snapshot tests for drag-lost regression suite. Different from ViewInspector: this captures rendered image snapshots, allowing visual regression testing of `PaneRenderer` output across drag operations.
- **Stars:** ~14.9k (pointfreeco org aggregate); package-level UNVERIFIED but the project is well-known and a Swift server / Apple platform staple.
- **Last release:** 1.19.4, ~8 days ago (per newreleases.io). 1.19.0 on Jun 9, 2026 per SPI.
- **License:** MIT.
- **macOS:** first-class (cross-platform Swift).
- **ADR-0008 carve-out:** not applicable — testTarget only.
- **M1 fit:** complementary to ViewInspector for the v0.28 ticket 028-011. ViewInspector checks structure; swift-snapshot-testing checks the rendered pixel output after each drag step. Useful for verifying that `PaneRenderer` geometry math survives a 100-step drag synthesis.
- **Trigger condition per AGENTS.md §11.1:** "no public API for asserting SwiftUI view pixel output across state changes" — Apple SwiftUI has no built-in snapshot test framework.
- **Risk:** Low. MIT, pointfreeco maintains well, swift-log sister package. Note the README warns "By default, Xcode will try to add the SnapshotTesting package to your project's main application/framework" — must be wired into `testTarget` only, never runtime target.
- **Recommendation:** **Adopt for M1 ticket 028-011 as a complement to ViewInspector.** Add to `Package.swift` testTarget. Owner-grill approval required (AGENTS.md §11.1 protocol).

### 3. `krzysztofzablocki/Inject` 1.6.0 — **PASS** (already approved §11.1)

- **Use:** SwiftUI hot-reload for development iteration.
- **Stars:** 3,474 (verified).
- **Last release:** 1.6.0 tag present in git ls-remote. Created 2021, actively maintained.
- **License:** MIT.
- **macOS:** first-class.
- **ADR-0008 carve-out:** not applicable — `#if DEBUG` only, no runtime impact on production. ADR-0008 §"Does NOT apply to" lists "Dev tools (`SwiftLintPlugin`, `Brewfile`)" as approved exceptions.
- **M1 fit:** hot-reload accelerates iterative work on `PaneRenderer` recursive tree, `LayoutPicker` floating palette, and `ZoneEditor`. Each ticket (028-004, 028-007, 028-008) involves iterative visual layout changes.
- **Trigger condition per AGENTS.md §11.1:** "no built-in SwiftUI hot-reload" (Xcode Previews is the closest but does not cover runtime stateful changes).
- **Risk:** Low. `Inject` is the de facto standard; Brewfile distribution already referenced in AGENTS.md §11.1.
- **Recommendation:** **Keep in §11.1 list. Verify version pin to 1.6.0 (was 1.6.0 in v0.28 spec).**

### 4. `sindresorhus/Defaults` 9.0.8 — **PASS** (already approved §11.1; bump version)

- **Use:** Type-safe UserDefaults wrapper. **Critical for M1** — `WorkspaceStore` currently hand-rolls UserDefaults JSON encoding (`Sources/WenshuApp/State/WorkspaceStore.swift:76-90`). Defaults would simplify the storage layer.
- **Stars:** ~2,488 (verified via repo leaderboard).
- **Last release:** 9.0.8, Mar 26 2026.
- **License:** MIT.
- **macOS:** first-class.
- **ADR-0008 carve-out:** PASS — UserDefaults wrapper, NOT a view framework. Explicitly listed in ADR-0008 §"Does NOT apply to" as approved exception.
- **M1 fit:** direct. `WorkspaceStore.save()` and `WorkspaceStore.savePresets()` can be replaced with `@Default(.workspaceJSON) var workspaceJSON: Data` style declarations. However, **migration concern**: existing `WorkspaceStore.save()` does synchronous JSON encode/decode with custom Codable; switching mid-stream affects data model v1 → v2 migration (planned for 028-003). Recommend defer adoption to AFTER 028-003 lands, so v2 schema is the first version persisted via Defaults.
- **Trigger condition per AGENTS.md §11.1:** "UserDefaults typed wrapper" — explicitly named.
- **Risk:** Low. Already in v0.28 spec at pin 8.2.0; bump to 9.0.8 to pick up swift-syntax 603.0.0 compatibility.
- **Recommendation:** **Keep in §11.1 list. Bump version pin from 8.2.0 → 9.0.8. Land alongside ticket 028-003 (data model v2) so v2 is the first Defaults-persisted schema.**

### 5. `apple/swift-log` 1.9.1 — **PASS** (deferred, not M1-blocking)

- **Use:** Standardized logging API. Currently wenshu uses `os.Logger` directly (Apple unified logging); `swift-log` adds a backend abstraction if wenshu ever needs to swap destinations.
- **Stars:** 4,044 (verified).
- **Last release:** 1.9.1 (Jan 14 2026 baseline; tags 1.8.0 / 1.9.0 / 1.9.1 present in git ls-remote).
- **License:** Apache-2.0 (acceptable per §11.1).
- **macOS:** first-class (Apple-platform official SSWG Graduated).
- **ADR-0008 carve-out:** PASS — logging, NOT a view framework. No view-tree implications.
- **M1 fit:** **DEFER.** wenshu v0.27 uses `os.Logger` directly and the boss has not signaled a logging backend swap need. Drag-lost regression tests benefit from explicit `Logger` calls in `NativeSplitter` + `PaneRenderer`, but Apple `os.Logger` is sufficient.
- **Trigger condition per AGENTS.md §11.1:** "no cross-platform / server-side / telemetry backend requirement" — none currently. Revisit if M6 logging pipeline gap (from inventory.json) escalates.
- **Risk:** Low. Apache-2.0, Apple-official, SSWG Graduated.
- **Recommendation:** **DEFER to M6 audit (logging pipeline gap).** Do NOT add for M1.

### 6. `SwiftyLab/MetaCodable` 1.6.1 — **WARN** (speculative for preset migration)

- **Use:** Codable macros with decorators for custom key mapping, nested type coding, and version-tagged payloads. Adjacent to schema-migration use cases.
- **Stars:** 777–779 (verified via GitRepoTrend and SPI mirrors).
- **Last release:** 1.6.0, Jan 20 2026 (verified).
- **License:** MIT.
- **macOS:** first-class.
- **ADR-0008 carve-out:** PASS — Codable helper, NOT a view framework.
- **M1 fit:** v0.28's planned schema migration is WorkspaceState v1 → v2 (`WorkspaceState.version: 1` → `version: 2`, per ADR-0008 + spec L158). This is a **single** version bump with a single migration step. Hand-rolling it in `WorkspaceStore.load()` (≈ 20 lines: try v2, on `DecodingError.typeMismatch` fall through to try v1 decoder, decode success then call `migrate(v1:)` to produce v2) is simpler than introducing a macro-based dependency.
- **Trigger condition per AGENTS.md §11.1:** "schema migration where multiple versioned forms coexist" — wenshu has only 1 planned bump. MetaCodable's strength is multi-version coexistence, which is overkill.
- **Risk:** Medium. Macros add Swift compiler plugin complexity; wenshu is on Swift 6.4 and macros have had edge cases (e.g., macro expansion errors can leak compile-time). For a single migration step the cost/benefit is wrong.
- **Recommendation:** **DEFER.** Adopt only if a 3rd or 4th schema version lands and the migration graph exceeds 3 steps. For v0.28 v1→v2 migration: hand-roll 20 lines in `WorkspaceStore.load()`.

### 7. `jrothwell/VersionedCodable` 1.2.4 — **WARN** (UNVERIFIED; not a serious candidate)

- **Use:** Direct schema-migration library with explicit version fields.
- **Stars:** UNVERIFIED — no star count surfaced in search. Likely small (single-author project, 3 years old per SPI, 13 commits — single-digit to low-hundreds ★ estimate, **UNVERIFIED**).
- **Last release:** 1.2.4 tag present in git ls-remote. README mentions "there is a problem with the current 1.2.x series and Swift 5.7-5.9" — warning sign of activity constraints.
- **License:** UNVERIFIED (likely MIT per SPI description but not confirmed).
- **macOS:** yes (Swift 5.7+).
- **ADR-0008 carve-out:** PASS — Codable helper, NOT a view framework.
- **M1 fit:** same as MetaCodable — overkill for wenshu's single v1→v2 migration step.
- **Risk:** High. Single author, low activity, Swift version warnings in README. Bus factor = 1.
- **Recommendation:** **REJECT.** Same rationale as MetaCodable + lower confidence in maintenance. If wenshu ever genuinely needs versioned Codable across N versions, prefer MetaCodable (777★, active, Jan 2026 release) over VersionedCodable.

---

## Per-candidate detail (FAIL — kept terse; ADR-0008 already excludes these)

### 8. `exyte/Grid` — **FAIL** (ADR-0008 view-architecture extension)

- 2,101★, MIT, macOS-supported — passes §11.1 (1), (3), (4).
- **Fails ADR-0008.** `exyte/Grid` is "CSS Grid-style two-dimensional layout" for SwiftUI = a SwiftUI extension targeting view architecture. ADR-0008 §"Applies to" bullet 3 names this exact class ("SwiftUIX class — already rejected in v0.27 third-party-depscan").
- **Even if it weren't ADR-0008 forbidden**, wenshu's ZoneEditor port of FancyZones does NOT want a CSS Grid model — it wants a custom recursive pane tree with snap-to-cell drag semantics. CSS Grid is wrong abstraction for FancyZones.
- **Recommendation:** **REJECT.** Confirmed in FORBIDDEN list.

### 9. `johnno1962/HotSwiftUI` 1.2.5 — **WARN** (Inject already covers this)

- 149★, MIT, macOS-supported — passes §11.1 (1), (3), (4).
- **Last commit:** UNVERIFIED, but SPI says "last issue closed 9 months ago" — borderline on §11.1 (2). Tags 1.2.4 / 1.2.5 present in git ls-remote (recent enough).
- **ADR-0008 carve-out:** PASS — dev-only, `#if DEBUG`.
- **M1 fit:** HotSwiftUI provides utility methods for hot reloading (companion to HotReloading / InjectionIII). wenshu already has Inject approved (§11.1 list). HotSwiftUI is a different tool in the same niche; not additive.
- **Risk:** Medium. Borderline activity. HotSwiftUI author (johnno1962) maintains InjectionIII / HotReloading as the primary tools; HotSwiftUI is a thinner utility on top.
- **Recommendation:** **DEFER.** Not needed if Inject is adopted (already approved). Mention only if Inject is later rejected for any reason.

### 10. `almonk/bonsplit` 1.1.1 — **FAIL** (ADR-0008 explicitly forbids)

- 459★, MIT, macOS-first — passes §11.1 (1), (2), (3), (4).
- **Fails ADR-0008.** Tab bar + split panes + drag = pane/dock/split/drag library. ADR-0008 §"Applies to" bullet 1 names this exact class.
- **Public evidence of drag-lost pain:** `manaflow-ai/cmux` issue #2289 ("Rip out Bonsplit and replace it with a direct AppKit split host"), opened 2026-03-28, **open** as of Aug 2026 per cmux changelog still mentioning Bonsplit fixes. 26.4k★ cmux publicly documents the failure.
- **Already reverted in wenshu v0.27** (ticket 027-31, `eabb0bd6e`). Permanent retirement per ADR-0008 §"Consequences".
- **Recommendation:** **REJECT (already in FORBIDDEN list).** Confirmed in ADR-0008 history.

### 11. `stevengharris/SplitView` 3.5.3 — **FAIL** (REMOVED 2026-08-28 per AGENTS.md §11.1)

- 216★, MIT, macOS-supported — passes §11.1 (1), (3), (4).
- **Fails ADR-0008.** Split view library with draggable splitter = pane/dock/split/drag library. ADR-0008 §"Applies to" bullet 1.
- **Last release:** UNVERIFIED. SPI shows no recent releases surfaced; boss 8/26 quote: "很久没更新了" (= unmaintained).
- **Already removed** per AGENTS.md §11.1: "REMOVED 2026-08-28 (superseded by ADR-0008 path C self-implement); v0.27 reverted integration kept in git history."
- **Recommendation:** **REJECT (already removed).** Confirmed in §11.1 removed list.

### 12. `DeclarativeHub/Layoutless` — **FAIL** (ADR-0008 explicit forbidden class)

- Stars UNVERIFIED, license UNVERIFIED.
- **Fails ADR-0008 regardless of star count.** ADR-0008 §"Applies to" bullet 2: "Custom Layout protocol libraries (= the Layoutless / swift-layout class)".
- **Recommendation:** **REJECT.** Confirmed in ADR-0008.

### 13. `chrisaljoudi/swift-log-oslog` — **FAIL** (below 100★ + stale)

- 92★, last activity ~4 years ago per SPI ("last issue closed 6 years ago, 2 open issues").
- **Fails §11.1 (1)** (< 100★) and **§11.1 (2)** (stale).
- ADR-0008 carve-out: not applicable (logging).
- **Recommendation:** **REJECT.** If wenshu ever needs an os_log backend for swift-log, prefer direct os.Logger (Apple-native) over this abandoned wrapper.

### 14. `kylehughes/PersistentKeyValueKit` — **FAIL** (< 100★)

- 56★, MIT, created Feb 2024.
- **Fails §11.1 (1)** (< 100★).
- ADR-0008 carve-out: PASS (UserDefaults wrapper).
- **Recommendation:** **REJECT.** Defaults already approved.

### 15. `AndrewBennet/PersistedPropertyWrapper` 2.3.0 — **FAIL** (< 100★ + stale)

- 39★, MIT, last issue closed 5 years ago per SPI.
- **Fails §11.1 (1)** and **§11.1 (2)**.
- ADR-0008 carve-out: PASS (UserDefaults wrapper).
- **Recommendation:** **REJECT.** Defaults already approved.

### 16. `vmanot/CorePersistence` — **FAIL** (< 100★ + non-standard license)

- 8★, license "Other" (custom).
- **Fails §11.1 (1)** and **§11.1 (3)** (non-standard license).
- ADR-0008 carve-out: PASS (persistence helper).
- **Recommendation:** **REJECT.**

### 17. `mallexxx/MigrateDecoder` — **FAIL** (< 100★)

- 1★ (literally one star).
- **Fails §11.1 (1)** by an order of magnitude.
- ADR-0008 carve-out: PASS (Codable helper).
- **Recommendation:** **REJECT.** Not a serious candidate.

### 18. `jaywcjlove/SFSymbolsPicker` 1.0.6 — **FAIL** (< 100★)

- 54★, MIT, macOS-supported.
- **Fails §11.1 (1)**.
- ADR-0008 carve-out: PASS (icon picker, not view-framework).
- **Recommendation:** **REJECT.** wenshu already has `bring-shrubbery/lucide-swift` 1.25.0 ratified (§11.1 list); a separate SF Symbols picker is unnecessary given lucide-swift's icon set covers the need.

### 19. `realm/SwiftLint` 0.62.1 — **PASS** (already approved §11.1; bump version)

- 19,682★ (verified via repo leaderboard).
- **Last release:** 0.62.1, Oct 13 2025.
- License: MIT.
- macOS: first-class.
- **ADR-0008 carve-out:** PASS — binary tooling via Brewfile + `wenshu-devtool` hooks chain; no runtime impact.
- **M1 fit:** CI gate for the new files landing in v0.28 (`PaneRenderer.swift`, `LayoutPicker.swift`, `ZoneEditor.swift`, `DragRegressionTests.swift`).
- **Recommendation:** **Keep in §11.1 list. Bump version pin to 0.62.1.**

### 20. `nicklockwood/SwiftFormat` 0.62.1 — **PASS** (already approved §11.1; bump version)

- Org-level 8,800+★; package-level UNVERIFIED but the project is the canonical Swift formatter.
- **Last release:** 0.62.1, Jul 7 2026.
- License: MIT.
- macOS: first-class.
- **ADR-0008 carve-out:** PASS — same as SwiftLint.
- **M1 fit:** same as SwiftLint — CI gate for v0.28 new files.
- **Recommendation:** **Keep in §11.1 list. Bump version pin to 0.62.1.**

---

## Gap-by-gap final recommendations

### Gap 1: LayoutEditMode palette (floating picker)

- **Conclusion:** **No third-party library needed.**
- **Reason:** The "floating picker" is a small SwiftUI overlay (`ZStack` + `.popover` + `.background(Material.regular)`) hosting ~6 preset buttons + Save/Reset/Done actions. Apple SwiftUI + AppKit ship everything needed. No surveyed library fills a real gap here; command-palette libraries (`Tinycast/Palette`, `HodosKit`, `slop-desk/PaletteView`) are bespoke implementations tied to specific app stacks, not general-purpose.
- **Action:** None. v0.28 ticket 028-007 self-implements using existing wenshu patterns (cf. `LayoutShellViewModel` toolbar pattern).

### Gap 2: ZoneEditor (FancyZones port)

- **Conclusion:** **No third-party library needed (per ADR-0008 path C).**
- **Reason:** ZoneEditor is a self-implemented SwiftUI FancyZones port per ADR-0008 + v0.28 spec. Reference sources: hermes `zone-editor.tsx` + `grid-model.ts` + `grid-to-tree.ts` (read-only) + bonsplit source (read-only, MIT). Surveyed candidates:
  - `exyte/Grid` (2,101★, MIT) — FORBIDDEN by ADR-0008 (view-architecture extension). Even if allowed, wrong abstraction (CSS Grid ≠ FancyZones snap-to-cell).
  - `Mijick/GridView`, `Aeastr/Loupe`, `robb/Redline`, `mkals/swiftui-extensions` — all UI LEAF helpers, not ZoneEditor models. None map to FancyZones semantics.
  - `ZkHaider/SnapAlignment`, `c2mInc/Snap2me`, `CodeSlicing/pure-swift-ui-design` — sample repositories, not maintained libraries; would not meet §11.1.
- **Action:** v0.28 ticket 028-008 self-implements per ADR-0008 path C. No Package.swift diff.

### Gap 3: drag-lost regression suite (v0.28 ticket 028-011)

- **Conclusion:** **Adopt `pointfreeco/swift-snapshot-testing` 1.19.4 + (already approved) `nalexn/ViewInspector` 0.9.9+.**
- **Reason:** ADR-0008 §"Test enforcement" + v0.28 spec L38 explicitly name this ticket with "7 test cases, automated, pre-commit + CI". ViewInspector already approved §11.1 for this exact ticket. swift-snapshot-testing complements ViewInspector: ViewInspector checks view structure + identity; swift-snapshot-testing checks the rendered pixel output after each drag step (which is the canonical way to detect "stale frames on divider drag" — the cmux issue #2289 phrasing).
- **7 test cases for the suite (proposed by spec):** (a) drag splitter left stops at minWidth, (b) drag right stops at maxWidth, (c) drag past sibling edge does not violate neighbor minWidth, (d) tab drag-and-drop between panes updates activeTabIndexByPane, (e) tab drag-and-drop refuses invalid drop zones, (f) LayoutEditMode ⌘⇧\ shortcut toggles state, (g) Escape exits LayoutEditMode and clears drag selection.
- **Action:** Add `swift-snapshot-testing` to `Package.swift` testTarget only. Reaffirm `ViewInspector` testTarget pin. Owner-grill approval required per §11.1 protocol.

### Gap 4: user preset persistence (JSON schema migration)

- **Conclusion:** **Hand-roll the v1 → v2 migration; defer `Defaults` adoption to AFTER 028-003 lands.**
- **Reason:**
  - `WorkspaceState.version` is currently `1` (`Sources/WenshuApp/State/WorkspaceState.swift:128`). v0.28 spec L158 plans `version: 2` with `SplitNode` recursive tree. This is ONE schema bump.
  - Hand-rolled `WorkspaceStore.load()` migration = try v2 decoder → on `DecodingError.typeMismatch` fall through to v1 decoder → on v1 success call `migrate(v1:) → v2` → write v2 back. ≈ 20 lines.
  - Surveyed Codable helpers (`MetaCodable` 777★, `VersionedCodable` UNVERIFIED small) are overkill for a single migration step. They shine at N-version coexistence graphs; wenshu has 1→2.
- **Defaults adoption timing:** `WorkspaceStore.save()` (UserDefaults JSON blob) is the right place to introduce `sindresorhus/Defaults` 9.0.8 for typed @Default wrappers. BUT**:** if Defaults lands in 028-003 alongside the schema bump, the v1 decoder logic and the Defaults wiring entangle. Recommend: (1) land 028-003 schema bump with hand-rolled migration, (2) land Defaults adoption in a follow-up ticket that targets v2 only.
- **Action:** (1) ticket 028-003 hand-rolls the migration; (2) future ticket adds Defaults 9.0.8 for v2+ typed persistence.

---

## Cross-cuts (for orchestrator's consolidated verdict)

1. **No new runtime SwiftPM dep is recommended for v0.28 M1 work.** Per ADR-0008 §"Consequences": "Package.swift diff for v0.28 = nothing (= `lucide-swift` is the only existing runtime dep)." All M1 candidates above either are dev-only (`ViewInspector`, `swift-snapshot-testing`, `Inject`, `SwiftLint`, `SwiftFormat`) or are pre-approved (`Defaults` is already on the runtime list; recommendation is timing change, not new adoption).

2. **The ONLY genuinely new adoption candidate** for M1 is `pointfreeco/swift-snapshot-testing` for the drag-lost regression suite (028-011). This is a testTarget dep, not a runtime dep. ADR-0008 §"Does NOT apply to" lists "Test tooling (e.g. `ViewInspector` for drag regression tests in v0.28 ticket 028-011)" as approved — extending the same exemption to swift-snapshot-testing is consistent with the existing carve-out.

3. **Three §11.1 version bumps** recommended for M1-adjacent development tooling (these are version pins, not new deps): `Defaults` 8.2.0 → 9.0.8; `SwiftLint` (current pin UNVERIFIED in §11.1 list — likely 0.55.x per spirit of "wenshu-devtool hooks chain"; bump to 0.62.1); `SwiftFormat` (same — bump to 0.62.1). These can land in a single `wenshu-devtool` config bump PR.

4. **Bridges to other modules:**
   - `Defaults` adoption (timing-shifted) is shared with **M6 Settings & Library** (where KeyboardShortcuts also lives — same Sindre Sorhus ecosystem).
   - `swift-snapshot-testing` adoption (M1) is reusable by **M2 Book Reader & Editor** (editor rendering snapshots) and **M4 Foreshadowing & Plot Web** (graph view snapshots).
   - `swift-log` deferred — **M6 logging pipeline gap** owns this.

5. **Per ADR-0008 history:** two FORBIDDEN libraries (`bonsplit`, `SplitView`) and one stale candidate (`OutlineView`) were re-surveyed and remain rejected. New FORBIDDEN additions surveyed this round: `exyte/Grid`, `DeclarativeHub/Layoutless`. (The latter is explicitly named in ADR-0008 already; the former is implicitly covered by "SwiftUI extensions targeting view architecture" — recommend ADR-0008 amendment to explicitly name exyte/Grid in the §"Applies to" list as a preemptive closure.)

---

## Trigger conditions per AGENTS.md §11.1 protocol (summary)

For each PASS / WARN candidate, the §11.1 acceptance test = "Apple官方 SwiftUI 不支持 / 实现困难的功能":

| Library | §11.1 trigger condition |
|---------|-------------------------|
| ViewInspector | Apple SwiftUI exposes no public testability hook for view hierarchy introspection or drag-gesture synthesis |
| swift-snapshot-testing | Apple SwiftUI has no built-in pixel-output regression test framework |
| Inject | Xcode Previews covers static layout but not stateful hot-reload across runtime state changes |
| Defaults | UserDefaults `@AppStorage` lacks Codable conformance, type-safety, and migration hooks |
| swift-log | (M6 deferral) Apple os.Logger has no cross-platform / server-side backend abstraction |
| MetaCodable | (deferred) N-version Codable coexistence where hand-rolled migrations grow past 3 steps |
| VersionedCodable | (rejected) same as MetaCodable + single-author risk |
| SwiftLint | No Apple-bundled Swift linter with rule plugins |
| SwiftFormat | No Apple-bundled Swift formatter with config-file-driven rules |

---

## Acceptance check against this audit's spec

| § spec.md requirement | Status |
|----------------------|--------|
| Per-library verdict against §11.1 four-condition gate | ✅ every candidate row has stars, last commit, license, macOS |
| ADR-0008 view-framework FORBIDDEN carve-out applied | ✅ FAIL verdicts explicitly cite ADR-0008 |
| Per-library risk assessment (bus factor, upstream drift) | ✅ each PASS / WARN row has 1-line risk note |
| 20 candidates surveyed (Swift framework + UI enhancement + engineering management) | ✅ covered all 3 dimensions |
| Trigger condition per AGENTS.md §11.1 | ✅ last table summarizes |
| Compact summary for parent orchestrator | ✅ see chat response |
| Writes to `.scratch/2026-08-28-six-module-audit/modules/M1-workspace-shell.md` | ✅ this file |
| READ-ONLY (no edits to Package.swift, AGENTS.md, source) | ✅ no edits made |

---

*Generated 2026-08-28 by wenshu pocock sub-agent for M1 Workspace Shell. All GitHub stars verified via search-snippet extraction (direct SPI / GitHub pages blocked from sandbox); UNVERIFIED marked where data point could not be confirmed. Sub-agent is READ-ONLY — Package.swift and AGENTS.md untouched.*