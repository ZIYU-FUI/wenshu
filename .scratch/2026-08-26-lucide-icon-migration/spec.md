# v0.25 — Lucide Icon Migration

First line of this doc = fact. Last line = fact.

## 1. context

Owner 2026-08-26 OOB: "Apple built-in SF ICON library is ugly. We introduce a third-party ICON library. Replace all ICON."

The 41 call sites of `Image(systemName:)` (= SF Symbols) in `Sources/WenshuApp/` must be migrated to a single third-party icon library. The constraint was historically locked: `Package.swift:21` and `AGENTS.md §11` both forbid third-party deps. Owner explicitly unlocked on 2026-08-26: third-party SDK is allowed, but every new third-party dependency must be owner-approved via grill (= no silent SDK adds).

## 2. library decision

Lucide was selected because it meets all four owner criteria:

1. **Most-used**: 1,500+ icons (= steady stream of requests, matches Pages/Notion-class app density)
2. **No copyright**: MIT + ISC, no royalty, no attribution-on-screen required
3. **Free of charge**: zero cost, zero tier, zero seat limit
4. **Single visual style**: 1.5 PT line + round caps + consistent 24x24 viewBox (= uniform feel across the 41 sites)

Native SPM wrapper chosen: `https://github.com/bring-shrubbery/lucide-swift`. Reason: native SwiftUI Shape rendering (= `Lucide(icon).foregroundStyle(...).frame(...)` is the documented API), 1700+ icons compiled into native Path code (no SVG at runtime), MIT license, macOS 14+ floor (= compatible with our macOS 27 target). Pinned to exact tag `1.25.0` (= the latest stable as of owner 2026-08-26 grill, verified via local `git ls-remote --tags`). The bring-shrubbery fork was chosen over ajaxjiang96 after the latter failed SPM resolution (= ajaxjiang96's Package.swift ships a vendored `.package(path: "PatchedDependencies/SVGPath")` that SPM cannot resolve from a top-level dep — only from a local checkout). Owner 2026-08-26 grill: switch back to bring-shrubbery.

## 3. unlock rules

- `Package.swift:21` comment `no third-party deps` removed. Comment is now `third-party deps allowed; every new dep must be owner-approved via grill (= 8/26 owner decision)`.
- `AGENTS.md §11` line referencing "no third-party SDK" replaced with `third-party deps allowed when owner-approved; ANAN does not silently add SDKs without owner sign-off`.
- a new skill `wenshu-pocock-workflow` recipe (`<lucide />` reference) is added so future migrations follow the same grill-first pattern.

## 4. icon abstraction layer

Single source of truth for icons = `Sources/WenshuApp/Core/Icon/WenshuIcon.swift`:

- enum `WenshuIcon { case book, key, keyFill, eyeFill, ... }` (= 41 cases for the 41 distinct SF Symbols we have today, no extras for now)
- `static let allCases: [WenshuIcon]` for debug views / future icon-picker UIs
- `var lucideIconName: LucideIconName` (= type-safe mapping to `bring-shrubbery/lucide-swift` 1.25.0's `LucideIcon` enum cases; resolved at compile-time, Xcode autocomplete; cases where Lucide differs from SF are noted in code comments so a future icon-swap stays cheap. NB: bring-shrubbery uses `LucideIcon` (not `LucideIconName`); updated to match the actual API surface.)
- `View` extension method `WenshuIcon.image(size:foregroundStyle:)` that wraps `Lucide(self.lucideIcon).frame(width: size, height: size)` and conditionally forwards `.foregroundStyle(...)` (= when nil, the SwiftUI environment default inherits so `.primary`/`.secondary`/`.accentColor` work — exactly what owner asked: follow Apple system colors). Default rendering = hollow outline geometry baked in at generation time (= spec §6 visual contract).
- Per-icon substitution table embedded in `WenshuIcon.swift` (small inline enum mapping for the 41 cases — when in doubt, use `LucideIcon(name: "...", size: ...)` string-based lookup as fallback).

The SwiftUI call sites switch from `Image(systemName: "x")` to `WenshuIcon.image(.x)` (= or `.image(.keyFill, size: 18)` for sized variants). The 41 call sites are migrated in one burn-down pass because owner 2026-08-26 explicitly said `全换 — 一次性替换`.

## 5. migration ticket map (= one ticket one commit)

- `001-package-dep-and-icon-layer.md` — add Lucide SPM dep + create `WenshuIcon.swift` (= foundation; no call sites changed yet; build green)
- `002-burndown-41-call-sites.md` — replace all 41 `Image(systemName:)` with `WenshuIcon.image(_:)`, files: `App.swift`, `Views/Chat/ChatView.swift`, `Views/Dynamic/DynamicZoneView.swift`, `Views/Dynamic/ZoneContentView.swift`, `Views/Library/LibraryOutlineView.swift`, `Views/Library/BookOutlineView.swift`, `Views/Library/LibraryRootView.swift`, `Views/Kanban/SubAgentProgressView.swift`, `Views/Onboarding/LibraryRootView.swift`. Build green + visual sanity check (= screenshot or `swift test`).
- `003-baseline-unlock.md` — update `Package.swift` comment + `AGENTS.md §11` to reflect new owner decision (= can also fold into 001).
- `004-domain-modeling.md` — add `WenshuIcon`, `LucideIcon`, `SPMDependency` domain words to `CONTEXT.md`.

Code-review is double-axis: standards sub-agent (= CJK + forbidden vocab + Apple HIG + forbidden-vocab lock) and spec sub-agent (= 41 sites actually migrated per grep, not visual-only).

## 6. visual contract

Owner 2026-08-26 confirmed:

- **Inherit Apple system colors** (= Lucide renders as `Image`, so `.foregroundStyle(.secondary)` / `.primary` / `.accentColor` work natively — this was the owner's main concern in Q4)
- **Primary style = hollow / outline** (= Lucide default; no `.fill` modifier)
- **Toggle state** (= future): `lucide.fill` variants for "on" state, hollow for "off" state. **Not implemented in this feature** — owner said "不着急实现, 先引入库". A new ticket will land the toggle variant when the first toggle UI actually needs it.
- Size defaults stay the same as current SF Symbols (= 18 PT in toolbar, 13 PT in tab bars, etc.).

## 7. invariants kept

- macOS-only target unchanged
- Swift 6.4 toolchain unchanged
- SwiftUI Apple HIG patterns unchanged (= Apple HIG is mostly transport-agnostic; Lucide renders through `.image(...)` so NSEvent / window chrome / menu bar are untouched)
- No iOS-only API; no UIKit; Lucide's native `Shape` rendering is pure SwiftUI
- 0 net new third-party SDK beyond Lucide in this feature
- No silent SDK additions ever (= owner 8/26 grill rule)

## 7.1 runtime safety nets (= 三层防护, owner 2026-08-26 demanded)

Every migration step must install (= not just document) the three protection layers:

1. **Layer 1 — compile-time enum-mapping lock (avoidance).** Exhaustive switch in `var lucideIcon: LucideIcon`. Adding a `WenshuIcon` case without a row is a build error. No silent glyph fall-through.
2. **Layer 2 — foreground inheritance floor (avoidance).** When `foregroundStyle` is nil, force `.foregroundStyle(Color.primary)`. The icon is never invisible against a missing foreground.
3. **Layer 3 — string-lookup 兜底.** Static `WenshuIcon.image(name:)` helper covers dynamic-string call sites (`tab.icon` etc.). `Lucide(name) ?? Lucide(.circleQuestionMark)` renders a visible Lucide "missing icon" glyph on nil. Mistyped strings never crash or render blank.

Full implementation details: see `Sources/WenshuApp/Core/Icon/WenshuIcon.swift` (= Layer 1 = exhaustive switch; Layer 2 = two `Color.primary` floors; Layer 3 = `Lucide(name) ?? Lucide(.circleQuestionMark)`). Vendor fallback path (= git clone into `Sources/WenshuApp/Vendor/Lucide/` if SPM dep is ever removed) preserves all three layers.

## 8. out of scope (= explicit)

- icon picker UI (= owner did not ask)
- per-zone icon customization (= owner did not ask)
- icon animation transitions (= unrelated, was the v0.24 boss-receiving ticket 015.077 / 015.078)
- toggle on/off visual states (= owner explicitly deferred)
- migrating any icons outside the 41 sites (= none exist today; revisit if new ones land)

Owner 2026-08-26 sign-off: needed before ticket 002 burndown begins.
