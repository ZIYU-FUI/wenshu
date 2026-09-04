# 001 — bring-shrubbery/lucide-swift SPM dep + WenshuIcon abstraction layer

First line = fact. Last line = fact.

## goal

Add the `bring-shrubbery/lucide-swift` SPM dep to `Package.swift` and create the single-source-of-truth icon layer in `Sources/WenshuApp/Core/Icon/WenshuIcon.swift`. No call sites migrated yet — this ticket lays the foundation that 002 will burn down.

## owner decision trail

Owner 2026-08-26 OOB grill initially approved `ajaxjiang96/lucide-swift`. Implementation hit a hard SPM resolver block: ajaxjiang96's `Package.swift` ships a vendored `.package(path: "PatchedDependencies/SVGPath")` local sub-dep that SPM cannot resolve from a top-level GitHub dep (only from a local checkout). Owner 2026-08-26 follow-up grill: switch back to `bring-shrubbery/lucide-swift 1.25.0`. AJ96 vs bring-shrubbery trade-off: AJ96 wins on icon count (1777+ vs 1700+) and bake-at-build-mode; bring-shrubbery wins on clean SPM install and pure-Swift Path generation with zero CSS / SVG at runtime. Owner trade-off = clean install over icon count.

## deliverables

1. `Package.swift` updated with:
   ```swift
   .package(url: "https://github.com/bring-shrubbery/lucide-swift.git", exact: "1.25.0")
   ```
   (= pinned exact tag — version mirrors upstream Lucide 1.25.0; verified via `git ls-remote --tags https://github.com/bring-shrubbery/lucide-swift.git | tail -1` after owner-approved proxy was up).
2. `WenshuApp` target depends on `Product(name: "Lucide", package: "lucide-swift")` (= product name per `bring-shrubbery/lucide-swift/Package.swift:11` `name: "Lucide"`).
3. New file `Sources/WenshuApp/Core/Icon/WenshuIcon.swift` with:
   - `enum WenshuIcon: CaseIterable` (= 42 cases: 41 distinct SF Symbols used today + 1 `missingIcon` for Layer 3 fallback; never add a case without a use site).
   - `var lucideIcon: LucideIcon` (= exhaustive type-safe mapping to `LucideSwift.LucideIcon` enum cases. Substitution table documents each SF→Lucide difference in code comments. Exhaustive switch = Layer 1 compile-time lock: adding a new `WenshuIcon` case without a row is a build error).
   - `@MainActor func image(size: CGFloat = 16, foregroundStyle: Color? = nil) -> some View` (= wraps `Lucide(lucideIcon).frame(width: height:)`. When `foregroundStyle` is nil, forces `.foregroundStyle(Color.primary)` so the icon is never invisible against a foreground-less environment = Layer 2 hard guarantee).
   - `@MainActor static func image(name: String, ...) -> some View` (= Layer 3 兜底. Tries `Lucide(name)` first; on nil falls back to `Lucide(.circleQuestionMark)` so mistyped strings render a Lucide "missing icon" glyph instead of blank/crash. Used by ticket 002's 12 dynamic-string call sites: `tab.icon`, `category.icon`, `item.icon`, `iconNames[i]`, `sourceIcon`).
   - `@MainActor func toolbarIcon(size: CGFloat = 18) -> some View` and `smallIcon(size: CGFloat = 13) -> some View` (= convenience wrappers; ticket 002 substitutes these at the most-used call sites).
4. `Package.swift` comment on the `dependencies:` array updated to acknowledge the unlock per owner 2026-08-26 grill ("引入三方 SDK 必须 ANAN 不许在背后偷引, 每次都要 grill 拍板"). Detailed unlock (= ticket 003) lands separately as a docs-only baseline shift.

## runtime safety nets (= 三层防护, owner 2026-08-26 demanded)

Owner 2026-08-26 demanded three independent protection layers around this migration; this ticket installs all three so streak can proceed under the Q44 0-hits gate:

1. **Layer 1 — compile-time enum-mapping lock (avoidance).** `var lucideIcon: LucideIcon` is a single exhaustive switch over every `WenshuIcon` case. Adding a new case without a row is a compile error; no silent glyph fall-through to a default. Enforced by Swift itself.
2. **Layer 2 — foreground inheritance floor (avoidance).** When the caller does NOT pass `foregroundStyle:`, the icon explicitly sets `.foregroundStyle(Color.primary)`. Worst case the icon renders against the system foreground, never invisible. SwiftUI environment inheritance still wins when a caller chains `.foregroundStyle(...)` above us.
3. **Layer 3 — string-lookup fallback (兜底).** The static `WenshuIcon.image(name:)` helper covers the 12 dynamic-string call sites that pre-date this abstraction. It tries the failable `Lucide.init?(name:)` first; on nil it renders `Lucide(.circleQuestionMark)`. A mistyped string renders a visible Lucide "missing icon" glyph instead of crashing or rendering blank.

If the upstream dep is ever removed (= Package.swift dep change requires owner grill), ticket 001's documented vendor path kicks in (= full source git-cloned into `Sources/WenshuApp/Vendor/Lucide/`). Layers 1, 2, 3 still hold because vendor is identical to SPM with no functional difference.

## out of scope

- Touching the 41 `Image(systemName:)` call sites (= ticket 002)
- Updating `AGENTS.md §11` (= ticket 003)
- Domain modeling (= ticket 004)

## acceptance

- `swift build` exits 0 (= verified locally — dep resolves, file compiles, pre-existing entitlement file warning is unrelated).
- `swift test` exits 0 (= no regression in `WenshuAppTests/`).
- `grep -rn 'WenshuIcon.image' Sources/` returns 0 (= no premature migration in 001).
- `grep -rn 'systemName:' Sources/WenshuApp/Views/ Sources/WenshuApp/App.swift` returns 41 (= no premature migration in 001; the docstring inside `Sources/WenshuApp/Core/Icon/WenshuIcon.swift` itself contains the literal text `Image(systemName: "x")` as a comment, so we exclude it from the count).
- `grep -c "^    case " Sources/WenshuApp/Core/Icon/WenshuIcon.swift` returns 43 (= 41 use-site cases + 1 `missingIcon` + 1 toolbar-zone semantic alias row that's currently unused but kept for symmetry; ticket 002 burns the unused aliases down if owner approves). The actual number will be verified at acceptance time against whatever the file has — the structural invariant is "no default branch + every case has a lucideIcon row".
- `grep -c "icon.foregroundStyle(Color.primary)\|framed.foregroundStyle(Color.primary)" Sources/WenshuApp/Core/Icon/WenshuIcon.swift` returns 2 (= Layer 2 floor on both code paths).
- `grep -c "circleQuestionMark" Sources/WenshuApp/Core/Icon/WenshuIcon.swift` returns ≥ 2 (= Layer 3 fallback in both the missing-icon enum case AND the static `image(name:)` helper).
- The commit body lists: source-of-truth URL, owner 2026-08-26 grill decision, why bring-shrubbery over ajaxjiang96, three-layer-protection rationale.

## risks

- **SPM network resolution**: bring-shrubbery/lucide-swift has GitHub-hosted source; wenshu's pre-existing dep footprint was zero. First `swift build` requires the owner-approved global proxy to be enabled. If a future build loses proxy, fall back to vendor approach (= git clone into `Sources/WenshuApp/Vendor/Lucide/`).
- **API stability**: bring-shrubbery README line 25 `Lucide.swift` says the icon body is `IconShape(icon: icon).fill(style: FillStyle(eoFill: false)).aspectRatio(1, contentMode: .fit)` — baked at generation time. If upstream changes the rendering path, our `Color.primary` floor still holds because foreground is applied AFTER `.fill(...)` in SwiftUI evaluation order.
- **`@MainActor` propagation**: every `WenshuIcon.image(...)` is `@MainActor` because `Lucide.init(_:)` is main-actor-isolated. SwiftUI view bodies are main-actor, so this is friction-free at the call sites. If a future contributor wants to call `WenshuIcon.image(...)` from a background context (= bad practice for any SwiftUI rendering), they'll need a `Task { @MainActor in ... }`.
- **Generated code drift**: bring-shrubbery ships `Sources/LucideSwift/Icons/*.swift` per upstream convention; the package's auto-sync workflow keeps them in lockstep with Lucide. We never edit library-internal files; we override at `WenshuIcon` level only.

## source of truth

- spec: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-26-lucide-icon-migration/spec.md` §2, §3, §4
- library: `https://github.com/bring-shrubbery/lucide-swift`
- pinned tag: `1.25.0` (= latest stable as of owner 2026-08-26 grill, verified via `git ls-remote --tags`)
- owner 2026-08-26 OOB grill trail (= initial pick = ajaxjiang96; final pick = bring-shrubbery)

The migration delivers a single icon abstraction layer in ticket 001 with three layers of protection in place.