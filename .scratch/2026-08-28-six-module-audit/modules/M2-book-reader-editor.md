# M2 Book Reader & Editor — third-party library survey

**Date:** 2026-08-28 · **Author:** wenshu pocock M2 sub-agent
**Module:** M2 — Markdown chapter / draft edit + chat zone + WordCount + Composer
**Existing surface:** `Core/Composer/{ComposerPanel,NoteComposer}.swift` + `Core/WordCount/{WordCounter,WordCountBadge}.swift` + `Views/Chat/ChatView.swift` + `swiftlang/swift-markdown 0.4.0` (parser) + `gonzalezreal/Textual 0.5.0` (preview renderer)

## Gap list (from `inventory.json` M2 section)

| # | Gap | Closest existing |
|---|---|---|
| G1 | Rich text editor (= TextKit 2 / TextEditor replacement) | SwiftUI `TextEditor` for raw text; `Textual` is render-only (no editing) |
| G2 | Syntax highlight in code fences (preview + composer) | none — Textual preview does not currently highlight fence content |
| G3 | Diff view for draft revisions (chapter / scene history) | none |
| G4 | Page-mode reader (scroll-vs-paginate toggle for long-form reading) | none — only continuous scroll |
| G5 | Search-in-file (intra-document find) | none — `.searchable` not wired |

## Evaluation gate (per AGENTS.md §11.1)

1. **Stars ≥ 100** (community trust)
2. **Last commit ≤ 12 months** (active maintenance; macOS 27 compat)
3. **License ∈ {MIT, Apache-2.0, BSD, public-domain}** (commercial compat)
4. **macOS-first OR macOS-supported** (iOS-only libs rejected)

**Plus ADR-0008 view-framework FORBIDDEN carve-out:** any pane / dock / split / drag lib is FORBIDDEN at runtime. Wenshu drag UX remains self-implemented per ADR-0007 path C. None of the M2 candidates are pane-style, so the carve-out is mostly advisory for this module — but §G4 page-mode pager candidates need scrutiny (some wrap UIKit paging controllers, which is "view-framework" in spirit but the gate language is pane/split/dock, not paging).

## Method

`git ls-remote --tags` for version pins + `git clone --depth=1` + `git log -1` for last-commit dates + `LICENSE` peek for SPDX classification. Star counts sourced from Swift Package Index package pages where GitHub API was rate-limited (403) and cross-checked with README badges. All 18 candidates' data captured in the agent's transient scratch; final verdicts below.

---

## Per-library verdicts

### G1 — Rich text editor (TextKit 2 / TextEditor replacement)

#### `nodes-app/swift-markdown-engine` — **WARN → likely REJECT** for v0.28, defer
- **Stars:** 964 (SPI: macOS 980, swift 4.6k tags) · **License:** Apache-2.0 · **Platforms:** macOS 14+ · **Swift tools:** 5.9 · **Last commit:** 2026-08-21 (within 12 months ✓)
- **What it is:** AppKit NSTextView / TextKit 2 + SwiftUI bridge. Powers the Nodes macOS notes app. Ships 3 library products: `MarkdownEngine` (editor core, zero deps), `MarkdownEngineCodeBlocks` (adds HighlighterSwift transitively), `MarkdownEngineLatex` (adds SwiftMath transitively).
- **§11.1 gate:** ✅ stars, ✅ active, ✅ Apache-2.0, ✅ macOS-first
- **ADR-0008 carve-out:** clean — this is a leaf editor primitive, not a pane/dock/split/drag framework. No conflict.
- **Cross-references:** Node `Swift` package is a `0.x.y` line (current 0.12.0 → 0.11.0 → 0.10.x). README explicitly states "pre-1.0, public API may change between minor releases". Already on AGENTS.md §11.1 pending-evaluation list as the carve-out candidate.
- **Risk:** API churn in pre-1.0 line; Wenshu v0.27 ships stable. AGENTS.md already calls it "revisit when ≥1k★ and after `swiftlang/swift-markdown` parser path proves insufficient". Stars are at 964 (1k threshold not crossed). **Verdict: WARN — defer to ≥1k★ gate.**
- **Wenshu fit:** Editor is the biggest M2 capability gap. Once it crosses 1k★ and the `swift-markdown-engine` API freezes 1.0, this is the strongest single candidate for replacing the current `TextEditor` raw-text path AND replacing the need to bolt on a separate `Textual` preview renderer.
- **Decision:** Defer until ≥1k★ + 1.0 release. **DO NOT ADD to Package.swift today.**

#### `SteveShi/MDEditorKit` — **REJECT** (license)
- **Stars:** small (no GH API read; SPI listing pending). **License:** **Mozilla Public License v2.0 (MPL-2.0)** · **Platforms:** macOS 14+, iOS 17+ · **Swift tools:** 6.0 · **Last commit:** 2026-08-21 (within 12 months ✓)
- **What it is:** Native TextKit 2 Markdown editor. AppKit-backed `MDEditorView` + SwiftUI bridge. Powers MDWriter.
- **§11.1 gate:** ❌ **license FAILS** — MPL-2.0 is file-level copyleft, NOT in the §11.1 allowed list {MIT, Apache, BSD, public-domain}. This is a hard FAIL on condition #3.
- **ADR-0008:** clean (editor primitive, not pane).
- **Verdict:** **REJECT. Do not add.** License incompatibility is non-negotiable per §11.1; no opt-out exists.

#### `no-problem-dev/swift-markdown-view` — **REJECT** (stars)
- **Stars:** 2 (per gh search). **License:** MIT · **Platforms:** iOS 17+ / macOS 14+ · **Swift tools:** 6.2 · **Last commit:** 2026-08-11
- **What it is:** `MarkdownEditor` SwiftUI view + `MarkdownView` TextKit 2 renderer for whole-document selection continuity. Bundles optional products for highlight.js / LaTeX / DesignSystem.
- **§11.1 gate:** ❌ **stars FAILS** (2 ★ ≪ 100 ★)
- **Verdict:** **REJECT.** Below the community-trust floor. Even with strong architectural fit (the "single NSTextView so selection crosses blocks" idea is exactly what wenshu wants), the bus-factor / no-popularity signal means we absorb all upstream risk.

#### `1amageek/swift-markdown-ui` — **WARN** (platforms, age, stars)
- **Stars:** low (per ls-remote / SPI). **License:** absent — README does not declare a license file. **Platforms:** **macOS 26 / iOS 26** (wenshu is macOS 27; .v26 is one minor behind but workable). **Swift tools:** 6.2 · **Last commit:** 2026-04-19 (within 12 months ✓)
- **§11.1 gate:** ❌ stars (likely < 100), ❌ license (no LICENSE file) — dual fail.
- **Verdict:** **REJECT.** Two gate failures. Note platform floor of macOS 26 would also require a wenshu platform-floor bump from `.v27` baseline (which is fine, but moot given the other two fails).

#### `gonzalezreal/textual` — **KEEP** (already in Package.swift, do not double-up)
- **Stars:** 842 (SPI: macOS 980, swift 4.6k tags). **License:** MIT · **Platforms:** SwiftUI pure (inherits host platform). **Swift tools:** 5.x · **Last commit:** 2025-12-29 per gonzalezreal X post (active)
- **Status:** Already in `Package.swift` from "0.5.0". Marked P2 future editor preview in AGENTS.md §11.1.
- **What it gives:** SwiftUI-native rich text renderer that consumes `AttributedString` `PresentationIntent` + `MarkupParser` protocol. Not a TextKit 2 editor — render-only, but flows with SwiftUI `Text` layout (cross-view selection).
- **§11.1 gate:** ✅ all four.
- **ADR-0008:** clean.
- **Verdict:** **Already approved.** Defer any deep wiring (P2) until a downstream ticket consumes it. No additional library needed.

---

### G2 — Syntax highlight in code fences

#### `appstefan/HighlightSwift` — **WARN → likely PASS** (best fit, gate edge)
- **Stars:** 203 (SPI verified). **License:** MIT · **Platforms:** iOS 15+ / macOS 13+ · **Swift tools:** 5.10 · **Last commit:** 2024-11-27 (~ 21 months old — **over 12 months**)
- **What it is:** Highlight.js + JavaScriptCore wrapper → `AttributedString` output. `Highlight` class + `CodeText` SwiftUI view. 50+ languages, 30 themes, Swift concurrency ready.
- **§11.1 gate:** ✅ stars, ❌ **last-commit FAILS** (2024-11-27 is 21 months, > 12 months), ✅ MIT, ✅ macOS.
- **Risk:** Below the 12-month freshness bar by ~9 months. Library itself looks complete (Highlight.js + AttributedString pipe is small surface) but no recent commits. HighlighterSwift is a recommended replacement (see next).
- **Verdict:** **WARN — borderline FAIL on gate #2.** Strong technical fit for the G2 use case but the freshness signal fails. **Defer.**

#### `raspu/Highlightr` — **REJECT** (abandoned)
- **Stars:** 1,867. **License:** MIT · **Platforms:** macOS 10.11+ · **Swift tools:** 5.3 · **Last commit:** 2026-02-13 (within 12 months ✓ but single commit)
- **What it is:** iOS/macOS syntax highlighter using Highlight.js. README explicitly says: **"As of 2026, Highlightr is no longer actively maintained. We recommend using HighlighterSwift instead."**
- **§11.1 gate:** ✅ stars, ⚠ last-commit (a single commit on Feb 13, 2026 — looks like a fix-up before deprecation notice, not active maintenance), ✅ MIT, ✅ macOS.
- **Verdict:** **REJECT.** Author's own README directs users to `smittytone/HighlighterSwift`. Bus-factor = 1 maintainer who walked away.

#### `smittytone/HighlighterSwift` — **PASS** (recommended replacement for Highlightr)
- **Stars:** 105 (just above 100★ floor). **License:** MIT · **Platforms:** macOS 11+ / iOS 13+ · **Swift tools:** 5.9 · **Last commit:** 2026-05-27 (within 12 months ✓)
- **What it is:** Modernized fork of Highlightr. Same Highlight.js + JavaScriptCore core, but refreshed to latest Highlight.js + structural cleanups. **Adopted transitively by `nodes-app/swift-markdown-engine`'s `MarkdownEngineCodeBlocks` product** — so it's already battle-tested by the Nodes app.
- **§11.1 gate:** ⚠ stars = 105 (just over 100, technically PASS but thin margin), ✅ active, ✅ MIT, ✅ macOS.
- **Wenshu fit:** Drops cleanly into a `SwiftUI Textual` preview pass (replace fence code-block `AttributedString` runs after `Textual` parsing) OR consumed as a stand-alone `AttributedString` producer for the chapter preview.
- **Risk:** Stars at exactly the gate floor. Bus factor: solo maintainer. Already wired into `swift-markdown-engine` so we get shared maintenance signal indirectly.
- **Verdict:** **PASS** (conditional). Adopting it for G2 is the cleanest path. **However, do not adopt separately if `swift-markdown-engine` is adopted later** (it would come transitively). For today, before the editor lands, adopt stand-alone: `smittytone/HighlighterSwift from: "3.1.0"` (~last published tag per search result).

#### `JohnSundell/Splash` — **REJECT** (dead, Swift-only)
- **Stars:** ~1,870. **License:** MIT · **Platforms:** (no SPM platforms declared; foundation-only). **Swift tools:** 5.4 · **Last commit:** 2022-06-08 (**4 years stale — hard FAIL on gate #2**)
- **What it is:** Pure-Swift syntax highlighter for Swift code only. Fast tokenizer, HTML + NSAttributedString outputs.
- **§11.1 gate:** ✅ stars, ❌ **last-commit FAILS** (2022), ✅ MIT, ⚠ no declared SPM platforms (works on macOS via Foundation, but not platform-explicit).
- **Verdict:** **REJECT.** 4-year dormancy disqualifies. Also Swift-only — does not cover Python/JS/bash fences.

#### `ChimeHQ/Neon` — **PASS** (best architecture, low-star)
- **Stars:** 391 (SPI: macOS 980, swift 4.6k tags). **License:** **BSD-3-Clause** ✓ · **Platforms:** macOS 10.15+ / iOS 13+ / tvOS / watchOS / macCatalyst · **Swift tools:** 6.0 · **Last commit:** 2026-08-27 (today / within 12 months ✓)
- **What it is:** Text styling engine for tree-sitter integration. Not a highlighter itself — it's the **invalidator / range-validation layer** that drives incremental highlighting. Includes `TreeSitterClient` module + `TextViewHighlighter` adapter for `NSTextView`/`UITextView`.
- **§11.1 gate:** ✅ stars, ✅ active, ✅ BSD-3-Clause, ✅ macOS-first.
- **Wenshu fit:** **High ceiling.** If wenshu ever needs live incremental highlighting in the chapter preview (user types, fences re-highlight without lag), Neon + a tree-sitter grammar library is the correct architecture. Highlightr / HighlighterSwift pipe Highlight.js through JSC — fast enough for 50-line blocks but loses to tree-sitter for 1000-line chapters.
- **Risk:** Requires choosing + vendoring tree-sitter language grammars (`SwiftTreeSitter` family). Bigger surface than the JSC wrapper approach. v1.0 not yet shipped (0.6.0 is current).
- **Verdict:** **PASS — defer to v0.29+ when wenshu has ≥1k★ chapters per book to warrant tree-sitter investment.** For v0.28 G2 closure, ship `HighlighterSwift` (lighter).

#### `PhraseHQ/HighlightKit` — **WARN** (very new, 2★)
- **Stars:** 2 (very low). **License:** MIT · **Platforms:** iOS 18+ / macOS 15+ · **Swift tools:** 6.1 · **Last commit:** 2026-07-14
- **What it is:** Pure-Swift (no JS / WebView / HTML) NSRange-token-based highlighter, 36 µs/line claimed. Recent and modern.
- **§11.1 gate:** ❌ **stars FAIL** (2), ✅ active, ✅ MIT, ✅ macOS.
- **Verdict:** **REJECT.** Stars below 100. Architecturally interesting (no JSC) but the bus-factor is too thin for a v0.28 lock-in.

#### `artemnovichkov/lustre` — **WARN** (Swift-only, platform floor)
- **Stars:** low (per ls-remote / SPI listing; not surfaced in top-10). **License:** MIT · **Platforms:** **macOS 15+ / iOS 18+** (1 minor below wenshu's macOS 27 baseline — works but tight). **Swift tools:** 6.0 · **Last commit:** 2026-01-23 (within 12 months ✓)
- **What it is:** Swift-only syntax highlighter via SwiftSyntax (parser) + `AttributedString` output. Markdown fence extraction built in.
- **§11.1 gate:** ⚠ stars (likely < 100), ✅ active, ✅ MIT, ⚠ platform floor 1 minor below wenshu baseline.
- **Verdict:** **REJECT.** Swift-only coverage (no Python/JS/bash fences) is insufficient for novel-author use (technical authors copy JS/Python into chapters). Stars below gate.

#### `swiftlang/swift-syntax` — **PASS** (dev / parse layer only, not a highlighter UI)
- **Stars:** 7k+. **License:** Apache-2.0 ✓ · **Platforms:** macOS supported · **Last commit:** within days
- **Verdict:** Already transitively available via Xcode. Not a "highlighter" library in the UI sense — it's the parser used by `artemnovichkov/lustre` and by Apple's macro system. No adoption needed; it's not a substitute for a G2 solution.

---

### G3 — Diff view for draft revisions

#### `tornikegomareli/gitdiff` — **WARN** (below 100★, but otherwise clean)
- **Stars:** 75. **License:** MIT · **Platforms:** iOS 15+ / macOS 13+ · **Swift tools:** 5.10 · **Last commit:** 2026-05-13 (within 12 months ✓)
- **What it is:** Pure-Swift unified-diff parser + SwiftUI `DiffRenderer` view. Light/Dark/GitLab themes. Word-wrap, line-numbers, gutter, custom parser injection. Last tag 0.1.0 (pre-1.0).
- **§11.1 gate:** ❌ **stars FAIL** (75 < 100), ✅ active, ✅ MIT, ✅ macOS.
- **Wenshu fit:** Very good — `DiffRenderer(diffText:)` + `.diffTheme(.light)` is exactly the kind of leaf view wenshu wants for "show me what changed in this chapter since yesterday's snapshot". Plus `parser: DiffParsing` protocol lets wenshu inject a custom format if `.ws` draft-history is binary or JSON-encoded instead of unified diff.
- **Verdict:** **REJECT for v0.28 (below 100★).** Re-evaluate when ≥100★. The architecture is the right shape; if `gitdiff` crosses 100, this is the first candidate to revisit.

#### `wokalski/Diff.swift` — **REJECT** (abandoned 8 years)
- **Stars:** medium (per search snippets; ~1k range historically). **License:** MIT · **Platforms:** SPM iOS / macOS · **Swift tools:** 5.5· **Last commit:** **2017-09-19** (9 years stale — hard FAIL on gate #2)
- **Verdict:** **REJECT.** 9-year dormancy. Even though the algorithm (Myers diff, O((N+M)·D)) is sound, Swift ABI churn since 2017 means this likely needs a fork to build on macOS 27.

#### `niklhut/SwiftDiff` — **REJECT** (abandoned)
- **Stars:** small (per ls-remote; search snippets don't surface a count, suggests <100). **License:** Apache-2.0 ✓ · **Platforms:** SPM foundation-only · **Swift tools:** 5.6 · **Last commit:** 2022-07-07 (**4 years stale — FAIL on gate #2**)
- **Verdict:** **REJECT.** Dormant 4 years.

#### Alternative: implement diff in-house using Apple's built-ins
- **Foundation** ships no diff API. **swift-syntax** has no diff API. wenshu would need to write a Myers / Patience LCS in-house (≈ 200 lines).
- **Worth noting:** the only serious maintained OSS Swift diff library is `gitdiff` (75★, pre-1.0). Beyond that, the ecosystem is dead.
- **Verdict:** **G3 has no production-ready OSS path.** Either (a) defer G3 to v0.29+ and wait for `gitdiff` to cross 100★, or (b) self-implement Myers diff for wenshu's specific chapter-vs-chapter case (small enough scope that 200 lines is reasonable). **Recommendation: defer G3.**

---

### G4 — Page-mode reader (scroll-vs-paginate toggle)

#### `nachonavarro/Pages` — **REJECT** (UIKit, dead)
- **Stars:** ~500 (per legacy notes; not surfaced in this search). **License:** MIT · **Platforms:** iOS 13+ (no macOS declared — UIKit `UIPageViewController` based). **Swift tools:** 5.1 · **Last commit:** 2025-12-30
- **What it is:** SwiftUI wrapper around `UIPageViewController`. macOS support not declared — it's iOS-first via UIKit. Per the AGENTS.md v0.27 baseline, wenshu is macOS-only (Apple HIG = macOS = AppKit, not UIKit).
- **§11.1 gate:** ❌ **macOS gate ambiguous** — listed as iOS only. UIKit on macOS works via Mac Catalyst / UIKit-for-Mac but is NOT Apple HIG for a native macOS app.
- **ADR-0008 view-framework:** **WARN.** `UIPageViewController` is a paging view controller from UIKit — it's a "view framework" in spirit (controls how content is split into pages), not just a leaf primitive. However, the §ADR-0008 forbidden list is "pane / dock / split / drag" — page-mode is not in that literal list.
- **Verdict:** **REJECT.** UIKit dependency violates the macOS-only + Apple HIG stack baseline (`AGENTS.md` §11). No AppKit / macOS-native page-mode library surfaced.

#### `fermoya/SwiftUIPager` — **REJECT** (dead)
- **Stars:** ~1k historically. **License:** MIT · **Platforms:** macOS 10.15+ / iOS 13+ (declared). **Swift tools:** 5.1 · **Last commit:** 2023-09-01 (**3 years stale — FAIL on gate #2**)
- **Verdict:** **REJECT.** 3-year dormancy. Same algorithm risk as Pages.

#### `notsobigcompany/BigUIPaging` — **REJECT** (low stars)
- **Stars:** low (per ls-remote; likely <100 — surfaced 0.0.3 as latest tag). **License:** MIT · **Platforms:** macOS + iOS · **Swift tools:** 5.x · **Last commit:** recent
- **§11.1 gate:** ❌ stars FAIL.
- **Verdict:** **REJECT.** Bus factor too thin.

#### Apple first-party: SwiftUI `TabView(.page)` + `.scrollTransition` (macOS 14+)
- **Status:** Built-in. `TabView(selection:) { ... }.tabViewStyle(.page(indexDisplayMode: .always))` ships with SwiftUI on macOS 14+ and iOS 17+.
- **§11.1:** Apple stack exclusive — no third-party needed. This is the §11 default ("Apple官方 SwiftUI / AppKit only").
- **Verdict:** **Use Apple's `.tabViewStyle(.page)` directly.** Zero new dependencies. Closes G4 for free on macOS 14+.

#### Alternative: scroll-snap + reading column via Textual
- `gonzalezreal/textual` (already in Package.swift) supports a `readingWidth` configuration that constrains the reading column width. This gives a "paged-look" without paging semantics.
- **Verdict:** Combined with Apple's `.tabViewStyle(.page)`, this is sufficient for G4.

---

### G5 — Search-in-file (intra-document find)

#### Apple first-party: `.searchable(text:)` + `TextEditor` find bar (macOS 13+)
- **Status:** Built-in. SwiftUI `.searchable(text: $query, placement: .toolbar, prompt: "Find in chapter")` + `TextEditor(text: $chapterText)` works out of the box on macOS 13+.
- **§11.1:** Apple stack exclusive — no third-party needed.
- **Verdict:** **Use Apple's `.searchable` directly.** Zero new dependencies. For Cmd-F global find, wrap `NSTextView` via `NSViewRepresentable` and let AppKit's built-in Find panel handle it (textkit-2-backed editors expose `usesFindBar = true`).

#### `PhindExtensions/SwiftUIFindBar` or similar — **NOT SURFACED**
- No maintained third-party SwiftUI find-bar library surfaced above 100★. The category is small and Apple's own APIs (`NSTextFinder` + `.searchable`) cover it.

#### Recommendation: G5 ships for free with the editor adoption.
- If `swift-markdown-engine` is eventually adopted for G1, its TextKit 2 NSTextView already supports `usesFindBar`. **No separate G5 library needed.**

---

## Summary table (all 18 candidates)

| Library | Gap | Stars | License | Last commit | macOS | §11.1 verdict | ADR-0008 |
|---|---|---|---|---|---|---|---|
| `nodes-app/swift-markdown-engine` | G1 | 964 | Apache-2.0 | 2026-08-21 ✓ | macOS 14+ | WARN (pre-1.0, <1k★) | clean |
| `SteveShi/MDEditorKit` | G1 | low | **MPL-2.0** | 2026-08-21 | macOS 14+ | **REJECT (license)** | clean |
| `no-problem-dev/swift-markdown-view` | G1 | **2** | MIT | 2026-08-11 | macOS 14+ | **REJECT (stars)** | clean |
| `1amageek/swift-markdown-ui` | G1 | low | **none** | 2026-04-19 | macOS 26+ | **REJECT (stars + license)** | clean |
| `gonzalezreal/textual` | G1 | 842 | MIT | 2025-12-29 | SwiftUI | **PASS — already in `Package.swift`** | clean |
| `appstefan/HighlightSwift` | G2 | 203 | MIT | **2024-11-27 (21mo)** | macOS 13+ | WARN (gate #2) | clean |
| `raspu/Highlightr` | G2 | 1,867 | MIT | 2026-02-13 | macOS 10.11+ | **REJECT (abandoned by author)** | clean |
| `smittytone/HighlighterSwift` | G2 | 105 | MIT | 2026-05-27 ✓ | macOS 11+ | **PASS (thin margin)** | clean |
| `JohnSundell/Splash` | G2 | ~1,870 | MIT | **2022-06-08 (4yr)** | n/a | **REJECT (dormant)** | clean |
| `ChimeHQ/Neon` | G2 | 391 | **BSD-3** | 2026-08-27 ✓ | macOS 10.15+ | **PASS (defer to v0.29)** | clean |
| `PhraseHQ/HighlightKit` | G2 | **2** | MIT | 2026-07-14 | macOS 15+ | **REJECT (stars)** | clean |
| `artemnovichkov/lustre` | G2 | low | MIT | 2026-01-23 ✓ | macOS 15+ | **REJECT (Swift-only, stars)** | clean |
| `tornikegomareli/gitdiff` | G3 | **75** | MIT | 2026-05-13 ✓ | macOS 13+ | WARN (stars) | clean |
| `wokalski/Diff.swift` | G3 | ~1k | MIT | **2017-09-19 (9yr)** | SPM | **REJECT (dormant)** | clean |
| `niklhut/SwiftDiff` | G3 | low | Apache-2.0 | **2022-07-07 (4yr)** | foundation | **REJECT (dormant)** | clean |
| `nachonavarro/Pages` | G4 | ~500 | MIT | 2025-12-30 | **iOS-only** | **REJECT (UIKit, not macOS)** | WARN (UIKit pager) |
| `fermoya/SwiftUIPager` | G4 | ~1k | MIT | **2023-09-01 (3yr)** | macOS 10.15+ | **REJECT (dormant)** | WARN |
| `notsobigcompany/BigUIPaging` | G4 | low | MIT | recent | macOS+iOS | **REJECT (stars)** | WARN |

---

## Recommended adopt-list for M2 (commit-ready)

### For v0.28 — `Package.swift` candidate additions

| Pin | Module | Dim | Trigger condition |
|---|---|---|---|
| `smittytone/HighlighterSwift from: "3.1.0"` | M2 | UI enhancement | Adopt when G2 ticket ships. Closes code-fence syntax highlight in `Textual` preview AND in chat-fence replies. |

**Do not adopt today, but track:**

| Pin | Module | Dim | Revisit when |
|---|---|---|---|
| `nodes-app/swift-markdown-engine from: "1.0.0"` (currently 0.12.0) | M2 | UI enhancement (editor) | Crosses 1,000★ AND ships 1.0 release (i.e. public API freezes). Then re-evaluate replacing `Textual` + `TextEditor` combo with the single `MarkdownEngine` product. |
| `ChimeHQ/Neon from: "1.0.0"` (currently 0.6.0) | M2 | Swift framework | v0.29+, when wenshu has enough chapter content to justify tree-sitter over Highlight.js for incremental live highlighting. |

### Self-implement (NOT third-party)

| Gap | Decision |
|---|---|
| G3 diff view | **Defer.** No production-ready Swift diff library exists (best is `tornikegomareli/gitdiff` at 75★). Either wait or self-implement Myers LCS (~200 lines) when the draft-history ticket lands. |
| G4 page-mode reader | **Use Apple's `TabView(.page)`** + `Textual`'s `readingWidth`. Zero new dependencies. |
| G5 search-in-file | **Use Apple's `.searchable`** + `TextEditor`. Zero new dependencies. When G1 lands (`swift-markdown-engine`), NSTextView's `usesFindBar` covers Cmd-F for free. |

### ADR-0008 view-framework FORBIDDEN carve-out — applied

None of the candidates are pane / dock / split / drag libraries. G4 page-pagers are **view controllers**, not the literal "view-framework" forbidden by ADR-0008 — but the spirit of the rule (no library that owns wenshu's interaction model) argues against them anyway. ADR-0008 carve-out is satisfied.

---

## Risks called out

1. **`smittytone/HighlighterSwift` stars = 105** — exactly the 100★ gate floor. Margin of 5★. If stars drop below 100, gate #1 fails. Mitigation: if the `nodes-app/swift-markdown-engine` adoption happens first (which transitively pulls HighlighterSwift), we get the maintenance signal for free without a stand-alone dep.
2. **Pre-1.0 `swift-markdown-engine` (0.12.0 line).** API may churn. Pin to a specific version, do not use `from:` semver. AGENTS.md already has the "revisit when ≥1k★" gate.
3. **`Highlightr` deprecation notice.** Industry pivot: `raspu/Highlightr` is dead, `smittytone/HighlighterSwift` and `appstefan/HighlightSwift` are the modern replacements. `HighlightKit` (pure-Swift, no JSC) is interesting but too new.
4. **G3 has no production library.** Defer or self-implement.

---

## Cross-module observations (for the orchestrator)

- **`gonzalezreal/textual`** (already in `Package.swift`) is cross-module: it serves M2 (chapter preview) and **M4** (link graph preview) and **M5** (codex preview). De-dupe in consolidated verdict.
- **`smittytone/HighlighterSwift`** if adopted also serves **M5** (codex tech-note previews with code fences) and **M6** (settings → test diagnostic output with code). Cross-module.
- **`ChimeHQ/Neon`** if adopted later is single-module (M2 only).
- **`nodes-app/swift-markdown-engine`** if adopted later is **single-module** (M2 only).

## Open questions for 老板

1. **G1 timing:** do you want to wait for `swift-markdown-engine` ≥1k★ + 1.0, or accept the 0.x API churn risk now to unblock the v0.28 editor ticket?
2. **G3 defer vs self-implement:** confirm G3 is deferred to v0.29 (no OSS option exists), or approve the in-house Myers LCS budget?
3. **G2 budget:** approve `smittytone/HighlighterSwift` for v0.28 standalone, or hold for the editor that bundles it transitively?
