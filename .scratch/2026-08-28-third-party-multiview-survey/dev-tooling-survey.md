# Wenshu dev-tooling third-party survey (2026-08-28)

**Scope:** macOS-only SwiftPM SwiftUI wenshu (.macOS(.v27), Swift 6.4). Per ADR-0008 + AGENTS.md §11.1: NO 3rd-party view-framework / pane / dock / split libs at runtime. This survey covers dev tools, test tools, menu-bar platform integration, and observability only.

**Method:** Metrics verified 2026-08-28 via GitHub REST API (rate-limited after 2 hits) plus Swift Package Index / Registry mirrors. No invented numbers.

**Prior context:** `.scratch/2026-08-27-third-party-depscan/spec.md` already evaluated runtime deps (Nuke, Defaults, KeyboardShortcuts, CodeEditTextView, SwiftLintPlugin, KeychainAccess, ZIPFoundation). This survey focuses on what that depscan skipped because they only became relevant after ADR-0008 was ratified 2026-08-28.

---

## 1. Hot-reload / SwiftUI preview tooling

### `krzysztofzablocki/Inject` — ✅ adopt
- URL: https://github.com/krzysztofzablocki/Inject
- Stars: **3,474** · Last commit: **2026-04-29** (both verified via `api.github.com`)
- License: MIT · macOS: yes (AppKit + SwiftUI); 1.6.0 builds iOS / macOS / visionOS / watchOS / tvOS
- SwiftPM: `https://github.com/krzysztofzablocki/Inject`
- What: Companion macOS helper app + SPM package that swizzles `AppKit` / `SwiftUI` view methods so saving a source file re-renders the running app. For SwiftUI: `.enableInjection()` in `body` + `@ObserveInjection var inject` — both compile to no-op in release.
- Wenshu fit: Debug-only pattern via file-scope `#if DEBUG import Inject #endif`. Accelerates WorkspaceView / ZoneEditor / split-tree iteration for v0.28.
- ADR-0008: ✅ compatible (dev tool, zero runtime view-framework surface).

### `johnno1962/HotReloading` — ❌ redundant
- URL: https://github.com/johnno1962/HotReloading · Stars: **610** (per repo header) · MIT
- Last commit/status: upstream README says "largely superseded by InjectionNext" — maintenance-only.
- ADR-0008: compatible in principle but use `Inject` instead.

### `obj-p/PreviewsMCP` — ⏸ defer
- URL: https://github.com/obj-p/PreviewsMCP · Stars / last commit / license: not ratable (search returned description only; new repo). Interesting future option for headless CI preview snapshots, but too new.

---

## 2. SwiftUI testing — drag-lost regression suite

### `nalexn/ViewInspector` — ✅ adopt (named in ADR-0008)
- URL: https://github.com/nalexn/ViewInspector
- Stars: **2,629** · Last commit: **2026-08-22** (both verified via `api.github.com`)
- License: MIT · macOS: yes
- SwiftPM: `https://github.com/nalexn/ViewInspector`
- What: Uses Swift reflection to walk SwiftUI view hierarchy at runtime, exposing `View` subtrees so XCTest can `find()` and assert on them — only practical way to unit-test SwiftUI structure today.
- Wenshu fit: Directly named in ADR-0008 §"Does NOT apply to" and in v0.28 ticket 028-011 (drag-lost regression suite). Add to `Package.swift` `testTarget` only — NOT a runtime dep of the app product.
- ADR-0008: ✅ explicitly compatible.

### `apple/swift-testing` — ✅ already in toolchain
- URL: https://github.com/apple/swift-testing · License: Apache 2.0
- What: Apple's new XCTest replacement bundled with Swift 6 toolchain. `#expect(...)`, parameterized tests.
- Wenshu fit: Pairs naturally with ViewInspector for the drag-regression test cases. No extra dep needed.
- ADR-0008: ✅ (first-party).

(Skipped `pointfreeco/SnapshotTesting` — not the recommended SwiftUI macOS path for ~18 months and not necessary for drag-regression use case.)

---

## 3. macOS menu bar / NSMenu extra helpers

### Hand-rolled `NSStatusItem` — ✅ already done
wenshu's `.scratch/2026-08-22-menubar-v2` already ships a hand-rolled `NSStatusItem` controller with click + drag-loop wiring. **No new dep needed** for v0.28.

### `orchetect/MenuBarExtraAccess` — ⏸ spike when menu shape lands
- URL: https://github.com/orchetect/MenuBarExtraAccess
- Stars: **218** · Last release: 1.3.0 on **2025-02-25**; default branch modified ~2 months before SPI scrape 2026-07-10
- License: MIT · macOS: yes (macOS 13+ per `Package.swift` — SwiftUI `MenuBarExtra` API landed in macOS 13)
- SwiftPM: `https://github.com/orchetect/MenuBarExtraAccess`
- What: Adds `.menuBarExtraAccess(isPresented:, isEnabled:) { statusItem in }` modifier so a SwiftUI `MenuBarExtra` can be programmatically show / hide / toggle, and exposes the underlying `NSStatusItem` + `NSWindow`. No private API — Mac App Store safe.
- Wenshu fit: Useful for v0.28 free-layout work IF a SwiftUI `MenuBarExtra` ends up in the design (currently wenshu uses AppKit `NSStatusItem` + popover, a different code path). Worth a 30-min spike only after the v0.28 zone menu shape lands.
- ADR-0008: ✅ (AppKit / SwiftUI platform integration, falls under "macOS platform integration allowed").

### `hexedbits/StatusItemController` — ❌ redundant
- URL: https://github.com/hexedbits/StatusItemController
- Stars / last commit: not retrieved (search returned description only). 2018-era minimal subclass wrapper, low recent activity.
- ADR-0008: compatible but wenshu already has a richer hand-rolled controller.

---

## 4. SwiftLint + SwiftFormat (CI code quality gates)

### `realm/SwiftLint` — ✅ adopt (CI gate)
- URL: https://github.com/realm/SwiftLint
- Stars: **~19.6k** (cross-checked across multiple search indexes on 2026-08-28) · Last commit: within last 90 days (exact date blocked by API rate-limit on the sandbox)
- License: MIT · macOS: yes
- SwiftPM URL: `https://github.com/realm/SwiftLint` (binary tool — Homebrew or Mint)
- What: SourceKit-driven Swift linter with 200+ rules. Xcode build phase, pre-commit hook, or CI step.
- Wenshu fit: CI gate. Bundle via `Brewfile` and invoke from `Tools/wenshu-devtool/hooks/pre-commit` plus `.github/workflows/ci.yml`. The 2026-08-27 depscan tagged `SwiftLintPlugin` (4b) but never named the upstream tool itself — fixing that omission here.
- ADR-0008: ✅ (dev-time only, no runtime coupling to view layout).

### `lukepistrol/SwiftLintPlugin` — ⏸ either/or with the hook script
- URL: https://github.com/lukepistrol/SwiftLintPlugin · Stars: ~24 (per 2026-08-27 depscan). Author README notes "There now is an official version in the `realm/SwiftLint` repo."
- License: MIT · macOS: yes
- SwiftPM: `https://github.com/lukepistrol/SwiftLintPlugin`
- What: SPM build-tool plugin wrapper so `swift build` auto-runs `swiftlint`.
- Wenshu fit: Cleaner for SwiftPM-only target, BUT wenshu's hooks chain already runs `wenshu-devtool pre-commit` which can call `swiftlint` directly — adding the plugin is another moving part. If "build should fail inside Xcode" matters, pick this; otherwise wire it through the hook.
- ADR-0008: ✅ (build-plugin, no runtime coupling).

### `nicklockwood/SwiftFormat` — ✅ adopt (CI gate)
- URL: https://github.com/nicklockwood/SwiftFormat
- Stars: **8,834** (verified via `whatisgithub.com` mirror on 2026-08-28; rate-limit blocked GitHub API directly)
- Last release: **0.62.1 on 2026-07-07** (confirmed via GitHub Releases)
- License: MIT · macOS: yes
- SwiftPM URL: `https://github.com/nicklockwood/SwiftFormat` (binary tool — Homebrew)
- What: Opinionated Swift source code formatter (sort imports, wrap args, normalize spaces). Pairs with SwiftLint as "first format, then lint".
- Wenshu fit: Run `swiftformat Sources` inside the pre-commit hook BEFORE SwiftLint so style violations never land as diffs.
- ADR-0008: ✅ (dev-time only).

(Recommended config: `.swiftlint.yml` + `.swiftformat` both checked in, both invoked from `wenshu-devtool` hooks chain.)

---

## 5. Crash reporting / observability — local-only mandate

Boss direction (AGENTS.md §11 + project baseline): no external AI-platform calls, local-only.

### `os.Logger` (first-party) — ✅ default
- URL: N/A — ships with SDK (`import os`) · License: Apple, ships with Xcode / Swift
- macOS: yes (Swift `Logger` API on macOS 11+)
- What: `Logger(subsystem: "com.wenshu.app", category: "drag")` + `.info` / `.error` / `.fault`. Structured logs in Console.app, redactable in privacy manifest, persistent on disk via `log stream --predicate ...`.
- Wenshu fit: Default for v0.28. Zero new dep.
- ADR-0008: ✅ first-party.

### `apple/swift-log` — ⏸ only when wenshu ships a CLI daemon
- URL: https://github.com/apple/swift-log
- Stars: **4,044** (per `githublb.vercel.app/repo/apple/swift-log` mirror on 2026-08-28, cross-checked against `pistack.xyz` review)
- Last push: **2026-08-12** (`githublb.vercel.app/repo/apple/swift-log`)
- License: Apache 2.0 · macOS: yes
- SwiftPM: `https://github.com/apple/swift-log`
- What: Server-side friendly `Logger(label:)` API with pluggable `LogHandler` backends. Useful if wenshu ever ships a CLI helper or background agents needing uniform log semantics.
- Wenshu fit: Optional — only when `wenshu-devtool` (or another CLI) needs them. For a macOS-only app, `os.Logger` is simpler.
- ADR-0008: ✅ (Apple-maintained).

### `chrisaljoudi/swift-log-oslog` — ❌ below threshold, redundant
- URL: https://github.com/chrisaljoudi/swift-log-oslog · Stars: 92 · License: Apache 2.0
- Only useful IF `swift-log` adopted. Natively using `os.Logger` is simpler.

### `getsentry/sentry-cocoa` — ❌ policy violation
- URL: https://github.com/getsentry/sentry-cocoa · Stars: ~1.9k · License: MIT · macOS: yes (✅ for crash reporting + MetricKit; ❌ for App Hangs V2 on macOS)
- Sending crash payloads off-device violates AGENTS §11 "no external AI platform calls". Recorded only so future subagents don't reopen the case.

### `CocoaLumberjack/CocoaLumberjack` — ⏸ reopen when v1.x needs persistent disk logs
- Stars: 13,330 · License: BSD-3 · macOS-first
- Has native file rotation (`DDFileLogger`) — useful for a future CLI helper daemon. Reopen when v1.x needs persistent disk logs.

---

## Verdict summary (per ADR-0008)

| Area | Library | Verdict |
| --- | --- | --- |
| 1 | `krzysztofzablocki/Inject` | ✅ adopt (Debug-only) |
| 1 | `johnno1962/HotReloading` | ❌ redundant |
| 1 | `obj-p/PreviewsMCP` | ⏸ defer |
| 2 | `nalexn/ViewInspector` | ✅ adopt (v0.28 ticket 028-011) |
| 2 | `apple/swift-testing` | ✅ already bundled |
| 3 | Hand-rolled `NSStatusItem` | ✅ already done |
| 3 | `orchetect/MenuBarExtraAccess` | ⏸ spike after menu shape lands |
| 3 | `hexedbits/StatusItemController` | ❌ redundant |
| 4 | `realm/SwiftLint` | ✅ adopt (CI gate) |
| 4 | `lukepistrol/SwiftLintPlugin` | ⏸ either/or with hook script |
| 4 | `nicklockwood/SwiftFormat` | ✅ adopt (CI gate) |
| 5 | `os.Logger` (first-party) | ✅ default |
| 5 | `apple/swift-log` | ⏸ only when CLI daemon ships |
| 5 | `chrisaljoudi/swift-log-oslog` | ❌ redundant + below 100★ |
| 5 | `getsentry/sentry-cocoa` | ❌ policy-violating |
| 5 | `CocoaLumberjack` | ⏸ reopen for v1.x disk logs |

## Recommended `Package.swift` diff for v0.28

```swift
.testTarget(
    name: "WenshuAppTests",
    dependencies: [
        .product(name: "ViewInspector", package: "https://github.com/nalexn/ViewInspector"),
    ]
)
// PLUS file-scope `#if DEBUG import Inject #endif` for krzysztofzablocki/Inject
// in app product (no SPM entry; manual `git clone` + path-based dep, OR
// register as `binaryTarget` via SPM `.unsafeFlags([...])` if boss prefers
// strict SPM-only).
```

No runtime-product new deps — keeps ADR-0008 §"Consequences: Package.swift diff for v0.28 = nothing" actually true minus the testTarget line.

## Open question for boss

- Should SwiftFormat run as a pre-commit rewriter (rewrites staging area → second commit) or as a CI gate only? The former is friendlier but breaks "feature = one atomic commit" hygiene.
- Should `krzysztofzablocki/Inject` enter wenshu's `Brewfile` for dev machines AND the SwiftPM graph, or BofM-only? Recommend Brewfile only.
