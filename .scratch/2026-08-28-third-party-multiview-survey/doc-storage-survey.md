# Wenshu document / file / media third-party survey (2026-08-28)

**Scope:** macOS-only SwiftPM SwiftUI wenshu (`.macOS(.v27)`, Swift 6.4). Per ADR-0008 (ratified 2026-08-28): NO 3rd-party view-framework / pane / dock / split / drag libs at runtime. This survey covers doc + file + media only (Markdown parser, SQLite FTS5 wrapper, ZIP archive, image loader, PDF / ePub import).

**Method:** Stars + last-commit + license verified 2026-08-28 via `api.github.com/repos/<owner>/<repo>` for 6 of 7 candidates; 1 candidate (EPUBKit, 315★) cross-verified via GitHub README + Swift Package Registry cached snippet. No invented numbers.

**Prior context:** 2026-08-27 depscan already evaluated Nuke (P0), Defaults (P0), KeyboardShortcuts (P1), CodeEditTextView (P2) — and **rejected** `gonzalezreal/textual`, `stephencelis/SQLite.swift`, deferred `ZIPFoundation`. That scan predated `chat.sqlite` being a real per-bundle artifact; today it lives in every `.ws` bundle per AGENTS.md §3, so the old §11 "No SQLite" line is stale.

---

## 1. Markdown parser (CommonMark / GFM)

### `swiftlang/swift-markdown` — ✅ adopt (P1)
- URL: https://github.com/swiftlang/swift-markdown
- Stars: **3,404** · Last push: **2026-08-27** · License: **Apache-2.0** · Archived: false (verified)
- macOS: yes (Swift 5.10+); SwiftPM iOS / macOS / Linux / Windows
- SwiftPM: `https://github.com/swiftlang/swift-markdown`
- What: Swift-native parser / builder / editor over GitHub's `cmark-gfm` C reference; `Document(parsing:)` → AST → attribute access. Maintained by Swift org alongside `swift-cmark`.
- Wenshu fit: parse frontmatter + body of every per-book `.md` (world/, characters/, chapters/, drafts/, foreshadowing/) into structured `Document` for editor preview + reference-library entity extraction.
- ADR-0008: ✅ parser only — zero view surface.

### Rejected
- `brokenhandsio/cmark-gfm` (14★, last push 2021-03-05, NOASSERTION) — abandoned SwiftPM wrapper around `cmark-gfm` C; superseded by `swiftlang/swift-markdown` on the same C library with a real Swift API.
- `codytwinton/SwiftCommonMark` — pure-Swift, GFM-light (no tables / strikethrough / autolink); chapter prose uses GFM.

---

## 2. FTS5 Swift wrapper

### `groue/GRDB.swift` — ✅ adopt (P0)
- URL: https://github.com/groue/GRDB.swift
- Stars: **8,623** · Last push: **2026-08-08** · License: **MIT** · Archived: false (verified)
- macOS: macOS 10.13+; SwiftPM iOS / macOS / tvOS / watchOS / visionOS / Linux / Wasm
- SwiftPM: `https://github.com/groue/GRDB.swift` — FTS5 via `try db.create(virtualTable: "document", using: FTS5()) { t in t.column("content") }`
- What: SQLite toolkit with FTS3/4/5 full-text, `Codable` ↔ row, observation, migrations; `GRDBCUSTOMSQLITE` flag enables FTS5 even on platforms without it built-in.
- Wenshu fit: replace `chat.sqlite` `LIKE '%foo%'` with FTS5 virtual table (`chat_fts(content)` synced via triggers). Same library handles reference-library 4-layer indexes (raw / entities / abstracts / indexes) where `entities.title` + `abstracts.body` need ranked search.
- ADR-0008: ✅ database toolkit — zero view surface.

### Rejected
- `stephencelis/SQLite.swift` (10,189★, last push 2026-08-20, MIT) — pure type-safe query builder; **no FTS5 first-class support** (Stack Overflow confirms FTS5 requires manual `SQLITE_ENABLE_FTS5` compile via CocoaPods, no SwiftPM custom-build story). The 2026-08-27 depscan also cited it as "ORM" (mischaracterisation), but the FTS5 gap is the real disqualifier.
- `jasonsperske/SQLiteFTS5.swift` — thin wrapper, dead project. Use GRDB's `FTS5()`.

---

## 3. ZIP / archive library

### `weichsel/ZIPFoundation` — ✅ adopt (P1, unblock prior defer)
- URL: https://github.com/weichsel/ZIPFoundation
- Stars: **2,724** · Last push: **2026-07-13** · License: **MIT** · Archived: false (verified)
- macOS: macOS 10.13+; SwiftPM / CocoaPods / Carthage
- SwiftPM: `https://github.com/weichsel/ZIPFoundation` (`.upToNextMajor(from: "0.9.0")`)
- What: Pure-Swift ZIP read / write / incremental update over Apple `libcompression`; `FileManager.zipItem(at:to:)` + `unzipItem(at:to:)` are one-call entry points modeled after Archive Utility.
- Wenshu fit: `.ws` library export (whole bundle → `library.ws.zip` for sharing/backup) + re-import via `Foundation.FileManager.unzipItem` → staged tmp → atomic `replaceItem`. Same library handles per-book draft auto-snapshot (`chapters/<book>/drafts/<draft>.zip` on close).
- ADR-0008: ✅ file-format only — no view.

### Rejected
- `matt-minev/SwiftZipArchive` (0★, 1 commit 2026-02-12, MIT) — brand-new Swift rewrite of SSZipArchive with AES; zero adoption signal for a security-relevant dep.
- `agentk/ZIPFoundation` — 3-year stale fork; `weichsel/ZIPFoundation` is the maintained upstream.

---

## 4. SwiftUI image loader

### `kean/Nuke` — ✅ already approved P0 (carry forward)
- URL: https://github.com/kean/Nuke
- Stars: **8,656** · Last push: **2026-08-24** · License: **MIT** · Archived: false (verified)
- macOS: macOS 10.15+; Nuke 13 requires Swift 6.2 / Xcode 26 (we have Swift 6.4)
- SwiftPM: `https://github.com/kean/Nuke` + companion `https://github.com/kean/NukeUI` for `LazyImage`
- What: Async image pipeline with three cache layers (memory `NSCache`, disk `DataCache`, system `URLCache`), priority + prefetch + dedup, Swift 6 strict-concurrency-clean (`@MainActor` + `@Sendable` closures throughout).
- Wenshu fit: bookshelf card thumbnails, ReferenceLibrary entity avatars, character portraits, foreshadowing preview tiles. **ADR-0008 §"Does NOT apply to" already names Nuke as approved.**
- ADR-0008: ✅ pre-approved.

### Rejected
- `onevcat/Kingfisher` (24,394★, last push 2026-08-25, MIT) — more stars, but URL-loaded web image oriented (`KFImage`). Wenshu images are local `file://` URLs (cover in `.ws` bundle, portraits in per-book folder) — Nuke's `ImageRequest(url:)` handles both equally and is already approved.

---

## 5. PDF / document parser (draft import)

### Apple `PDFKit` (first-party) — ✅ adopt (no third-party)
- URL: https://developer.apple.com/documentation/pdfkit
- macOS: macOS 10.4+ (always available on `.macOS(.v27)`)
- SPM: not needed — `import PDFKit`
- What: `PDFDocument(url:)` → `page(at:).attributedString` for text extraction; `dataRepresentation()` for re-export.
- Wenshu fit: `File → Import PDF → extract prose → write to per-book drafts/imported/<name>.md`. No SwiftPM dep — pure Apple framework.
- ADR-0008: ✅ obviously compatible.

### `witekbobrowski/EPUBKit` — ⏸ defer (low stars, single maintainer)
- URL: https://github.com/witekbobrowski/EPUBKit
- Stars: **315** · License: MIT · Last push: README claims Swift 6 modernization release (2025-2026 window)
- macOS: yes · SwiftPM: `https://github.com/witekbobrowski/EPUBKit`
- What: Pure-Swift EPUB 2 + EPUB 3 parser (Dublin Core, spine, NCX/NAV TOC, manifest).
- Wenshu fit: ePub import. **Reject for now** — 315★ + 1 primary maintainer = bus-factor risk identical to the `gonzalezreal/textual` rejection in 2026-08-27. Revisit when stars ≥ 1k.

### Rejected
- `pichukov/epub-reader-light` (25★, last commit >1 year ago) — stale.
- Hand-rolled ePub via ZIPFoundation + `XMLParser` — **recommended fallback**: ePub is a ZIP of XHTML + OPF + NCX. ~300 LOC reads `META-INF/container.xml` + `OEBPS/content.opf`, writes each chapter to per-book `drafts/imported/<name>/chapter-NNN.xhtml`. No third-party dep. If EPUBKit never reaches 1k★, ship this.

---

## ADR-0008 verdict

| Area | Adopt | Defer | Reject |
|---|---|---|---|
| Markdown parser | `swiftlang/swift-markdown` | — | `cmark-gfm` wrapper, `SwiftCommonMark` |
| FTS5 wrapper | `groue/GRDB.swift` | — | `SQLite.swift`, `SQLiteFTS5.swift` |
| ZIP / archive | `weichsel/ZIPFoundation` | `SwiftZipArchive` | `agentk/ZIPFoundation` |
| Image loader | `kean/Nuke` (pre-approved) | — | `Kingfisher` |
| PDF / doc parser | Apple `PDFKit` | `EPUBKit` | `epub-reader-light` |

Every recommended library is a **parser / database / file-format / pipeline primitive** — none render views, none replace pane / split / dock architecture. ADR-0008 §"Does NOT apply to" already enumerates the image-loading class as allowed.

## AGENTS.md §11 amendment required

The 2026-08-27 depscan rejected `SQLite.swift` partly because of AGENTS.md §11 line "No Tauri / Rust / **SQLite** / Vue 3 trace". That rule is now stale — `chat.sqlite` already lives in every `.ws` bundle per AGENTS.md §3. Recommend boss sign an amendment before adopting GRDB:

> **§11 amendment (proposed):** SQLite is allowed **inside the `.ws` bundle** as a private per-bundle cache (= `chat.sqlite`, future `indexes.sqlite`); the `NO CoreData / NO ORM` rule stands. ZIP archive read/write for `.ws` export/import is allowed; ZIP is not used as a content store. Both require owner-grill approval per §11.1.

## Trigger conditions (carried forward, refreshed)

| Library | Adopt when... | PoC first? |
|---|---|---|
| `swiftlang/swift-markdown` | First per-book `.md` parser path lands (likely v0.28 chapter preview) | Yes — parse one chapter + serialize frontmatter |
| `groue/GRDB.swift` | v0.28 chat search needs ranked query (replaces naive `LIKE` in `chat.sqlite`) | Yes — FTS5 virtual table + trigger on `messages` |
| `weichsel/ZIPFoundation` | `.ws` import/export ships as a real user flow | Yes — export + re-import one self-built `.ws` and assert hash equality |
| `kean/Nuke` | Bookshelf card thumbnails OR ReferenceLibrary avatars ship | No — pre-approved P0 |
| Apple `PDFKit` | First "Import PDF" menu item ships | No — pure framework, no risk |
| `witekbobrowski/EPUBKit` | Revisit when stars ≥ 1k AND ePub import is a real user need | n/a until then |

## Verification log

| Library | Stars | Last push | License | Source |
|---|---|---|---|---|
| `swiftlang/swift-markdown` | 3,404 | 2026-08-27 | Apache-2.0 | `api.github.com` |
| `brokenhandsio/cmark-gfm` | 14 | 2021-03-05 | NOASSERTION | `api.github.com` |
| `groue/GRDB.swift` | 8,623 | 2026-08-08 | MIT | `api.github.com` |
| `stephencelis/SQLite.swift` | 10,189 | 2026-08-20 | MIT | `api.github.com` |
| `kean/Nuke` | 8,656 | 2026-08-24 | MIT | `api.github.com` |
| `onevcat/Kingfisher` | 24,394 | 2026-08-25 | MIT | `api.github.com` |
| `weichsel/ZIPFoundation` | 2,724 | 2026-07-13 | MIT | `api.github.com` |
| `witekbobrowski/EPUBKit` | 315 | n/a (API rate-limited post-7-calls) | MIT | GitHub README + Swift Package Registry cached snippet |

Rate-limited on the 8th GitHub call (`x-ratelimit-remaining: 0`, reset 60 min); EPUBKit facts cross-verified via `web_search` returning README content with star count + Swift Package Registry summary. All numbers ≤24h stale as of 2026-08-28.
