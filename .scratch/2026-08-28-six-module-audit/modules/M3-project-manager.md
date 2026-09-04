# M3 Project / Manuscript Manager — library survey

**Date:** 2026-08-28 · **Module:** M3 · **Author:** wenshu pocock M3 sub-agent
**Spec:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/spec.md`
**Inventory:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/modules/inventory.json`
**Gate:** `AGENTS.md §11.1` (stars ≥100 / last commit ≤12 mo / MIT-Apache-BSD-PD / macOS-first OR macOS-supported) + `ADR-0008` view-framework FORBIDDEN carve-out

## Module scope

Library + Bookshelf + Book + Kanban + Todo + Search + Templates + Bases + QuickSwitcher + Bookmarks. Five gaps per inventory.json: ranked FTS, thumbnail pipeline, PDF import, EPUB import, .ws bundle ZIP export/import.

## Existing in-package surface (verified against `Package.swift` 2026-08-28)

| Lib | Version pin | Role in M3 |
|---|---|---|
| `groue/GRDB.swift` 7.11.1 | P0 | SQLite toolkit + FTS5 (currently **unused** — M3 uses raw `import SQLite3` via `FullTextSearch.swift`) |
| `weichsel/ZIPFoundation` 0.9.20 | P1 unblocked 2026-08-28 | Pure-Swift ZIP read/write — covers .ws export/import gap natively |
| `kean/Nuke` 13.2.0 | P0 | Async image pipeline + SwiftUI `LazyImage` — already adopted for bookshelf thumbnails |
| `bring-shrubbery/lucide-swift` 1.25.0 | — | Icon set for QuickSwitcher cells, library cards |

## Gap-by-gap evaluation

### Gap 1 — Ranked full-text search (FTS5 / tantivy)

**Verdict: NO NEW LIBRARY. Gap is closable by migrating from raw `SQLite3` to already-adopted `GRDB.swift`.**

Evidence:
- `Sources/WenshuApp/Core/Search/FullTextSearch.swift` (164 LOC) currently hand-rolls FTS5 via `import SQLite3` — `CREATE VIRTUAL TABLE … USING fts5(…, tokenize='trigram')` + `snippet()` + `bm25()` (`ORDER BY rank`). Engine and ranking are already there.
- `groue/GRDB.swift` 7.11.1 (8,623★, pushed 2026-08-08, MIT) ships first-class FTS5 wrappers (`FTS5`, `FTS5Pattern`, `FTS5TokenizerDescriptor`, `Column.rank`, `matching(_:)`, `synchronize(withTable:)`, `bm25()`-aware ORM). Verified via source: `GRDB/FTS/FTS5.swift`, `Documentation/FullTextSearch.md`.
- `tantivy` (Rust full-text engine) considered as the SPEC mentions — **REJECTED**: wenshu is "Apple stack exclusive" (AGENTS.md §11 default) + SwiftPM-only, no Rust bindings. FTS5 in SQLite is sufficient for the corpus (per-book `indexes.sqlite` + library `chat.sqlite` per AGENTS.md).

§11.1 gate on the proposed refactor target (`groue/GRDB.swift`): **PASS** (already adopted).

**Action:** migration ticket to replace `FullTextSearch.swift`'s hand-rolled SQLite3 C-binding with GRDB's `FTS5` virtual table wrapper. Same engine, better ergonomics, removes ~100 LOC of pointer-juggling. Same query language, same `bm25()` ranking, same `snippet()` output. Migration is internal — no `Package.swift` change, no new approval gate.

### Gap 2 — Thumbnail generation pipeline (cover/portrait/asset)

**Verdict: NO NEW LIBRARY. Apple's first-party QuickLook + PDFKit + Nuke cover this.**

Evidence:
- macOS 27 first-party: `QLThumbnailGenerator` (`import QuickLookThumbnailing`) ships `generateBestRepresentation(for:)` + `saveBestRepresentation(for:to:as:)` — handles PDF, images, video, plain text out-of-box. Per `QLThumbnailGenerator.Request(fileAt:size:scale:representationTypes:)`. No third-party needed.
- PDF cover extract: `import PDFKit` → `PDFDocument(url:).page(at: 0)?.thumbnail(of:for:)` → NSImage → write to disk. ~20 LOC of first-party code, no dep.
- Image load + cache: already covered by `kean/Nuke` 13.2.0 (8,656★, MIT, P0, `LazyImage` SwiftUI view). Boss anchor already approved this for the bookshelf card thumbnails path.
- EPUB cover: `ZIPFoundation` (already adopted) → unzip `.epub` → read `OEBPS/content.opf` → first `<meta name="cover">` reference → extract image file. ~30 LOC, no third-party EPUB parser strictly needed for *cover-only* extraction (see Gap 4 for full import).

§11.1 gate (no new lib): **N/A** — first-party only.

Caveat: if v0.28+ ticket ever wants EPUB cover *with metadata* (title, author, TOC) auto-applied to the new book entry, that crosses into Gap 4 (EPUB import) and the EPUB parser is the right tool.

### Gap 3 — PDF import

**Verdict: NO NEW LIBRARY. `PDFKit` (Apple first-party) covers this.**

Per the inventory.json note and boss anchor: "PDF import (PDFKit first-party = no dep needed)". Same approach as Gap 2: `PDFDocument(url:)` → iterate `page(at:)` → write text to `.ws/chapters/<n>.md` per the FCP layout. No §11.1 survey needed.

### Gap 4 — EPUB import

**Verdict: ONE NEW LIBRARY RECOMMENDED. `witekbobrowski/EPUBKit` 0.5.0.**

Candidates evaluated:

| Candidate | Stars | Last push | License | macOS | §11.1 verdict |
|---|---|---|---|---|---|
| **`witekbobrowski/EPUBKit`** | 316★ | 2026-03-26 (~5 mo ago) | MIT | macOS 10.10+ supported | **PASS** |
| `readium/swift-toolkit` | 546★ | 2026-08-26 (2 d ago) | BSD-3-Clause | macOS supported | PASS but **REJECTED** — full Readium LCP ebook reader toolkit (audiobook, CBZ, OPDS, PDF viewer, Readium LCP DRM), 50+ Swift files, includes its own publication model + navigator stack + zip + SQLite bindings. Pulling it in just to import one EPUB file is the same kind of "framework bloat" that ADR-0008's pane/dock/split ban was designed to prevent at the Swift level. Latest tag `4.0.0-alpha.1` is alpha; stable `3.9.0` is large but stable. Use only if v0.28 ticket later wants full EPUB *reader* in-wenshu. |

EPUBKit specifics (verified via `git ls-remote --tags` 2026-08-28 + GitHub API):
- Latest tag = `0.5.0`. `Package.swift` declares platforms `[macos 10.10, ios 9.0, tvos 9.0]`, depends on `AEXML` 4.6.0 + `Zip` 2.1.1.
- Reads OCF container (ZIP), parses `META-INF/container.xml` → OPF spine → NCX navigation → Dublin Core metadata.
- AEXML + ZipFoundation-style API surface — but `Zip` dep is the older `wxyyxc1992/SwiftZip` fork (different from wenshu's `weichsel/ZIPFoundation`). Conflict-resolvable: both coexist at SPM level but it pulls a second ZIP engine into the dep graph.

§11.1 four-condition gate:
1. **Stars ≥100**: 316 — PASS
2. **Last commit ≤12 mo**: 2026-03-26 (≈5 months) — PASS
3. **License MIT**: — PASS
4. **macOS-supported**: yes (10.10+) — PASS

Risk note: EPUBKit hasn't had a release in 5 months. Last release 0.5.0 was 2021; commits are sporadic maintenance. Bus factor = 1 (sole maintainer). Recommended adopt only behind a thin wenshu-side adapter (`EPUBImportService` protocol) so a future migration to Readium or self-implemented parser (ZIPFoundation + AEXML) is a 1-file swap.

**Adopt-list entry:**
```
witekbobrowski/EPUBKit 0.5.0  · M3 Project Manager · Swift framework (parser) · P1
  Trigger: EPUB import ticket lands (.epub file → wenshu book shell with chapters + cover + metadata)
```

### Gap 5 — `.ws` bundle export/import (ZIP)

**Verdict: NO NEW LIBRARY. `weichsel/ZIPFoundation` 0.9.20 (already adopted) covers this.**

Verified against `git ls-remote --tags` 2026-08-28 + GitHub API:
- Stars: 2,725 — PASS
- Last push: 2026-07-13 (1.5 months) — PASS
- License: MIT — PASS
- macOS-first: yes (10.11+, pure-Swift via Apple `libcompression`) — PASS
- ADR-0008 view-framework FORBIDDEN: not applicable (ZIP engine, not UI)

`FileManager.unzipItem(at:to:)` + `Archive` class + `Archive.addEntry(with:relativeTo:)` cover the export/import round-trip. The earlier "last push 2024-09" worry (per Ecosyste.ms sync) was stale — fresh push 2026-07-13 confirms active maintenance. macOS 27 / Swift 6.4 clean (already compiled in the v0.27 baseline).

**Implementation note for the wiring ticket:** ZIPFoundation has no streaming support for archives > available RAM. For wenshu's typical `.ws` bundle (single book = ≤10 MB chapters + assets) this is a non-issue. Library-level `.ws` bundles with reference-library media may push toward ZIP64 — verify `compressionMethod` + `Archive` API during implementation.

## UI enhancement dimension (QuickSwitcher cells)

QuickSwitcher inventory has a UI-enhancement gap (fuzzy-match cells, syntax-aware highlights). Evaluated `krisk/fuse-swift`:

| Candidate | Stars | Last push | License | macOS | §11.1 verdict |
|---|---|---|---|---|---|
| `krisk/fuse-swift` | 945★ (SPI) / 944★ (GH) | 2026-05-22 (~3 mo ago) | Apache-2.0 | macOS 12+ | **PASS** |

However, wenshu already has a self-implemented `QuickSwitcherIndex.fuzzyScore` (Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherIndex.swift, 112 LOC) that handles ASCII case-insensitive prefix/substring + CJK char-order. Adding fuse-swift is **NOT recommended** for M3 — the corpus is bounded (one library, single-machine), the in-house implementation already covers the Chinese-novel-author use case, and a 945★ Bitap algorithm is overkill for ≤10k items. **Mark as P3 — defer unless benchmark shows the hand-rolled fuzzy is too slow at >50k items.**

If M5 (Character codex fuzzy) survey wants it, the cross-cut orchestrator should assign it there — not M3.

## Engineering management dimension (test for FTS5)

`ViewInspector` (already adopted in `testTarget` only) + `GRDB`'s in-memory `DatabaseQueue` + the v0.19 `FullTextSearch` bootstrap is sufficient to write FTS5 tests:
- index known fixture strings → search with known query → assert ranked results + snippet correctness
- regression test for the trigram tokenizer (3-char CJK match floor)
- regression test for `bm25()` ordering with bm25-weighted columns (per FTS5 §5.1.1)

No new engineering-management dep needed. **Action:** attach to the GRDB migration ticket above.

## ADR-0008 view-framework FORBIDDEN check

None of the recommended libs (`EPUBKit`, `ZIPFoundation`, `GRDB`, `Nuke`, `fuse-swift`) qualify as pane/dock/split/drag libraries. All are leaf-level (parser / engine / image pipeline). FORBIDDEN carve-out not triggered.

## Cross-module bridge candidates

- **`kean/Nuke`** — already adopted, used by M1 (Workspace drag preview), M2 (book cover in chat), M3 (bookshelf cards), M5 (portrait in codex). Single dep with multi-module consumers → de-dupe handled by single `Package.swift` row.
- **`groue/GRDB.swift`** — currently zero consumers in source (despite Package.swift dep). Once M3 migrates `FullTextSearch.swift` to GRDB, this dep becomes load-bearing for M3 (search) and unlocks future M6 (chat.sqlite, backup diff) + M2 (chapter revisions). Single dep with future-multiple-consumer.

## Final adopt-list delta for M3

| Lib | Version | Dimension | Priority | §11.1 | Notes |
|---|---|---|---|---|---|
| `witekbobrowski/EPUBKit` | 0.5.0 | Swift framework (parser) | P1 | **PASS** | New. Triggers on EPUB import ticket. Sole-maintainer risk → wrap behind `EPUBImportService` protocol. |

No other new libraries required for M3. GRDB migration is an internal refactor (no Package.swift change). ZIPFoundation / Nuke / PDFKit / QLThumbnailGenerator are all already adopted or first-party.

## Risk summary

1. **EPUBKit maintenance drift** — 5 months since last release, sole maintainer. Mitigation: thin adapter protocol.
2. **EPUBKit Zip vs ZIPFoundation dual-zip** — pulls a second ZIP engine (`wxyyxc1992/SwiftZip` `Zip` package) into SPM graph. Mitigation: acceptable cost for the import path; doesn't affect .ws export/import (which uses wenshu's own ZIPFoundation dep).
3. **GRDB migration risk** — touches the v0.19 FullTextSearch which is already in the Obsidian-replica feature surface. Mitigation: feature-flag the migration behind `WENSHU_USE_GRDB_FTS` env, ship behind the door for one v0.28 cycle.
4. **QuickSwitcher fuzzy decision** — *deliberate non-action*. In-house implementation suffices; re-evaluate at >50k items.

## Out of scope (deferred per spec)

- Per-feature wiring of each lib (lands with the ticket that consumes it).
- M1 / M2 / M4 / M5 / M6 surveys — covered by sibling sub-agent reports.
- Bonsplit (rejected 2026-08-27 per ADR-0008).
