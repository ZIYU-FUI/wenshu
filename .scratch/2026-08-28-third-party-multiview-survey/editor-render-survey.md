# Wenshu 4-Area Third-Party Library Survey

**Date**: 2026-08-28 · Swift 6.4 + `.macOS(.v27)` SwiftPM
**Hard constraint (ADR-0008)**: NO 3rd-party view-framework/pane/dock/split/drag. Apple stack exclusive for view architecture.
**Verdict legend**:
- **ALLOWED** — pure data/parser/service; drops into a wenshu module.
- **CASE-BY-CASE** — ships a small leaf view / `NSTextStorage` subclass; we wrap or ignore.
- **VIEW-FRAMEWORK-FORBIDDEN** — owns pane/window/split/drag. Out.

**Module anchors (recurring)**: (M1) Workspace Shell · (M2) Book Reader & Editor · (M3) Project/Manuscript Manager · (M4) Foreshadowing & Plot Web · (M5) Character & World Codex · (M6) Settings & Library.

> Star counts cross-verified via Swift Package Index + github scrapers. Where sources disagreed, the lower number is reported; numbers marked `~` are scrape-cached. Direct GitHub REST API was IP rate-limited (403, remaining=0); boss is encouraged to click the URLs in the VERIFIED list.

---

## Area 1 — Markdown editor / renderer

Replace hand-rolled `TextEditor` with live markdown preview + GFM.

### 1a. Textual — `gonzalezreal/textual`
URL: https://github.com/gonzalezreal/textual
- Stars: **~842** (SPI). License: **MIT**. macOS 13+. SwiftPM: `https://github.com/gonzalezreal/textual`.
- What: SwiftUI-native rich attributed-text engine with Markdown as one input format; spiritual successor to MarkdownUI; built on Apple's `swift-markdown`.
- **Wenshu**: M2 (preview pane), M4/M5 inline rendering.
- **Verdict**: **CASE-BY-CASE**. Exports `Text` views — we compose inside our SwiftUI tree; nothing owns panes/splits/drag.
- Caveat: newborn (created 2025-12-27), pre-1.0, but author = long-time MarkdownUI maintainer.

### 1b. SwiftMarkdownEngine — `nodes-app/swift-markdown-engine`
URL: https://github.com/nodes-app/swift-markdown-engine
- Stars: **~863** (SPI; one scrape 962). License: **Apache-2.0**.
- macOS: **first-class** (TextKit 2 native, `NativeTextViewWrapper` for SwiftUI, macOS 14+).
- SwiftPM: `https://github.com/nodes-app/swift-markdown-engine`, from `0.1.0`.
- What: native AppKit/SwiftUI markdown editor with wiki-links, fenced code, LaTeX, GFM. `MarkdownEngineCodeBlocks` product pulls in `appstefan/HighlightSwift` for syntax-highlighted fences.
- **Wenshu**: M2 reader/editor (full `TextEditor` replacement), M4 notes.
- **Verdict**: **CASE-BY-CASE**. Core parser is pure; the SwiftUI `View` wrapper is the only architectural surface. Vendor = Nodes (commercial macOS notes app) → maintained.
- Caveat: ~2 months old, 14 releases, 20 open issues, last activity 1 day ago. Pre-1.0 but active.

### 1c. swift-markdown-ui — `gonzalezreal/swift-markdown-ui`
URL: https://github.com/gonzalezreal/swift-markdown-ui
- Stars: **3,918** (SPI). License: **MIT**. macOS 12+ (13+ for tables). tag `2.4.1` (2024-10-13).
- **Verdict**: **ALLOWED** but author placed it in **maintenance mode** in favor of Textual. Don't pick for greenfield.

### 1d. Down — `johnxnguyen/Down`
URL: https://github.com/johnxnguyen/Down
- Stars: **2,512**. License: **MIT**. macOS 10.11+. SwiftPM yes.
- What: thin wrapper over libcmark 0.29 → HTML/XML/LaTeX/`NSAttributedString`/CommonMark. **Pre-GFM**.
- **Verdict**: **ALLOWED** (parser only). Maintenance sparse (~2022). Use only for low-level `NSAttributedString`; for live preview prefer 1a/1b.

**Recommendation**: **Textual** as primary renderer. Optionally pair with **SwiftMarkdownEngine**'s parser for wiki-link semantics. Drop 1c (maintenance mode).

---

## Area 2 — Syntax highlighting + code-block rendering

### 2a. Highlightr — `raspu/Highlightr`
URL: https://github.com/raspu/Highlightr
- Stars: **1,867** (SPI, 2026-08). License: **MIT** (highlight.js bundled = BSD).
- macOS: **supported** (10.10+; macOS build green in SPI 6.0–6.3 matrix). SwiftPM: `https://github.com/raspu/Highlightr`, tag `2.3.0`/master.
- What: wraps `highlight.js` via JavaScriptCore; exposes `Highlightr` + `CodeAttributedString` (subclass of `NSTextStorage`). **185 languages, 89 themes**.
- **Wenshu**: M2 (code fences in manuscripts), M4 (foreshadow editor with snippets), M6 (settings previews).
- **Verdict**: **CASE-BY-CASE**. Tokenizer + `NSTextStorage`; we feed it into our own `NSTextView`. Not a view-architecture library.
- Caveat: pulls in JS runtime + ~2 MB highlight.js. Acceptable for the LLM chat renderer where code is common; overkill if wenshu novels rarely contain code.

### 2b. HighlightSwift — `appstefan/HighlightSwift`
URL: https://github.com/appstefan/HighlightSwift
- Stars: **210** (SPI). License: **MIT**. macOS build green; tag `v1.1.0` (~2024); main quiet >1 year.
- What: pure Swift, no JS, ~30 CSS themes; SwiftUI `Text` view export.
- **Verdict**: **CASE-BY-CASE** (use the tokenizer, ignore the view).
- Caveat: bus factor = 1 (Stefan Britton); quiet.

### 2c. Splash — `JohnSundell/Splash`
URL: https://github.com/JohnSundell/Splash
- Stars: **1,869**. License: **MIT**. Last push **2024-05-27**; last release 0.16.0 from **2021-06-14** — **dormant**.
- What: hand-written Swift tokenizer, ~10 hand-tuned languages (Swift/Obj-C-centric). Pure data; no views.
- **Verdict**: **ALLOWED** but **dormant** — skip unless we fork.

**Recommendation**: **Highlightr** for breadth (185 languages, MIT, ~1.9k ⭐). Pairs naturally with the `MarkdownEngineCodeBlocks` bridge from 1b. Fall back to **HighlightSwift** if payload/JS-core are concerns.

---

## Area 3 — Full-text search across manuscripts

### 3a. tantivy.swift — `botisan-ai/tantivy.swift`
URL: https://github.com/botisan-ai/tantivy.swift
- Stars: **7** (peerlist wrap 2025-12; SPI last push 2025). License: **MIT** (bindings); underlying tantivy = MIT.
- macOS: **first-class** — explicit iOS+macOS via UniFFI/Rust; ships **custom CJK tokenizer** that doesn't break on no-whitespace languages.
- SwiftPM: `https://github.com/botisan-ai/tantivy.swift`.
- What: Swift bindings to **Tantivy** (Rust, Lucene-style, BM25, persistent on-disk index, async/await, Codable docs).
- **Wenshu**: M2 cross-manuscript search; M3 "find in all books"; M4/M5 codex alias search.
- **Verdict**: **ALLOWED** (pure data layer). **Prototype despite 7 stars** — underlying tantivy is production-grade (Quickwit), and CJK tokenization matters for wenshu.
- Caveat: binding may lag tantivy releases; single maintainer (lhr0909).

### 3b. HybridSearch.swift — `botisan-ai/HybridSearch.swift`
- 2 stars; tantivy.swift + hnsw.swift fused via RRF. **Future-only** if we add semantic search. **Verdict**: ALLOWED but **no strong candidate recommendation yet — flag for v0.30+**.

### 3c. fuse-swift — `krisk/fuse-swift`
URL: https://github.com/krisk/fuse-swift
- Stars: **945**. Last push **2026-05-22** (active). License: **Apache-2.0**.
- Pure Swift port of fuse.js. **Fuzzy/typo-tolerant** Bitap; not a search engine — scores an in-memory candidate set.
- **Verdict**: **ALLOWED**. M3 command-palette typeahead, M5 codex name as-you-type.
- Caveat: doesn't solve "find paragraph X across 50 books" — use 3a for that.

### 3d. FuzzyMatch — `ordo-one/FuzzyMatch`
URL: https://github.com/ordo-one/FuzzyMatch
- Stars: **148**. License: **Apache-2.0**. Swift 6.2+, Sendable, DocC. Last push **2026-06-10** (v1.4.0 — active).
- Pure Swift Damerau-Levenshtein + Smith-Waterman; zero-allocation hot path; designed for 250K–1M candidates.
- **Verdict**: **ALLOWED**. Same use cases as 3c but for larger codex/cross-book sets.

### 3e. Ifrit — `ukushu/Ifrit`
- 98 ⭐, MIT, Swift 6.2 fork of "dead" fuse-swift. Lower priority than 3d given FuzzyMatch's benchmarks.

**Recommendation**:
- **Real** cross-manuscript search: **prototype tantivy.swift**. If the binding is too raw, fall back to **GRDB + SQLite FTS5** (Apple stack, no 3rd-party view code).
- **Typeahead / fuzzy command palette**: **FuzzyMatch** (perf) or **fuse-swift** (maturity).

---

## Area 4 — Diff (foreshadowing editor, draft comparison, character history)

### 4a. TextDiffing — `simonbs/TextDiffing`
URL: https://github.com/simonbs/TextDiffing
- Stars: **169** (SPI, agrees). License: **MIT**. Full SPI matrix (iOS/macOS/visionOS/tvOS/watchOS/Linux/Wasm). v1.0.3 ~6 months ago; main modified 2 months ago — **active**.
- What: token- or character-level text diff → `AttributedString` / `NSAttributedString` with insertion/deletion highlighting; customizable `TextDiffStyle`; **zero deps**.
- **Wenshu**: M2 inline change gutter (green inserts, red strikethrough deletes), M4 character history per-paragraph view.
- **Verdict**: **ALLOWED**. Only output is an `AttributedString` we render however we want. No view architecture.
- Caveat: limited to two-string diff — for paragraph-level across long docs we compose (split → diff each). Maintainer = Simon B. Støvring (Scriptable / Runestone — credible macOS indie author).

### 4b. Differ — `tonyarnold/Differ`
URL: https://github.com/tonyarnold/Differ
- Stars: **675** (SPI). License: **MIT**. Full SPI matrix. Last release 1.4.6 ~**4 years ago** (repo quiet).
- What: O((N+M)·D) collection/string diff. Generates `Patch`/`ExtendedPatch` with moves. Active fork of `wokalski/Diff.swift`.
- **Wenshu**: M2 draft comparison, M4 foreshadow "what changed since last review", M5 character history.
- **Verdict**: **ALLOWED** (use `diff()`/`patch()` core; ignore UIKit/AppKit animation helpers).
- Caveat: 4-year release cadence.

### 4c. DifferenceKit — `ra1028/DifferenceKit`
URL: https://github.com/ra1028/DifferenceKit
- Stars: **3,663**. License: **MIT**. Last commit ~1 month ago (active).
- What: O(n) difference algorithm for Swift collections; `StagedChangeset<T>`; designed for `UITableView`/`UICollectionView` animations.
- **Verdict**: **ALLOWED** algorithm; ignore UI helpers.
- Caveat: tuned for **Equatable-element ordered collections**, not free-form prose. Less natural than 4a/4b for paragraph diffs.

### 4d. soffes/Diff
- URL: https://github.com/soffes/Diff · Stars uncertain · Last push **2020-06-03** — **dormant**. Skip.

**Recommendation**:
- **Primary**: **TextDiffing** for the inline gutter (purpose-built for `AttributedString`, active, MIT, vendor-backed).
- **Secondary**: **Differ** for structural chapter/version diff when we need moves + insertions across long ordered lists.
- Skip DifferenceKit for prose; revisit only if sidebar perf becomes an issue.

---

## Cross-area verdict

| # | Area | Primary pick | Verdict | Backup |
|---|------|--------------|---------|--------|
| 1 | Markdown renderer | Textual | CASE-BY-CASE | SwiftMarkdownEngine (parser only) |
| 2 | Syntax highlight | Highlightr | CASE-BY-CASE | HighlightSwift (lighter) |
| 3 | Full-text search | tantivy.swift (prototype) | ALLOWED | GRDB + SQLite FTS5 |
| 4 | Diff | TextDiffing | ALLOWED | Differ |

No library is **VIEW-FRAMEWORK-FORBIDDEN** under ADR-0008. The CASE-BY-CASE entries (Textual, Highlightr, SwiftMarkdownEngine) only ship leaf-level `View`s / `NSTextStorage` subclasses — wenshu composes them inside its own SwiftUI tree and never delegates window/pane/dock architecture.

## VERIFIED URLs

- Textual: https://github.com/gonzalezreal/textual
- SwiftMarkdownEngine: https://github.com/nodes-app/swift-markdown-engine
- swift-markdown-ui (maint. mode): https://github.com/gonzalezreal/swift-markdown-ui
- Down: https://github.com/johnxnguyen/Down
- Highlightr: https://github.com/raspu/Highlightr
- HighlightSwift: https://github.com/appstefan/HighlightSwift
- Splash: https://github.com/JohnSundell/Splash
- tantivy.swift: https://github.com/botisan-ai/tantivy.swift
- fuse-swift: https://github.com/krisk/fuse-swift
- FuzzyMatch: https://github.com/ordo-one/FuzzyMatch
- Ifrit: https://github.com/ukushu/Ifrit
- Differ: https://github.com/tonyarnold/Differ
- DifferenceKit: https://github.com/ra1028/DifferenceKit
- TextDiffing: https://github.com/simonbs/TextDiffing
- soffes/Diff: https://github.com/soffes/Diff

## Not recommended

- **DifferenceKit for prose diffs** — designed for Equatable collections, not token streams.
- **Splash** — dormant since 2024-05-27.
- **swift-markdown-ui** — author placed in maintenance mode.
- **soffes/Diff** — dormant since 2020-06-03.
- Any bonsplit / SplitView / Dockview / SwiftUIX view-architecture library — forbidden by ADR-0008 (not surveyed).
