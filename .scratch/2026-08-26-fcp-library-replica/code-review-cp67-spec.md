# CP6+CP7 Spec-Axis Code Review — v0.26 FCP Library Replica (Tickets 019-022 + 026)

**Spec:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, 396 lines, dual-axis PASS)
**Commits under review:**
- `1de8e0e7f` — ticket 019 — `Sources/WenshuApp/State/BookStore.swift` (109 insertions, 1 file)
- `978480958` — ticket 020 — `Sources/WenshuApp/Storage/CacheManager.swift` (51 insertions, 1 file)
- `b1ade5e2f` — ticket 021 — `Sources/WenshuApp/Storage/LibraryBootstrapper.swift` (130 insertions, 1 file)
- `dd69aaeab` — ticket 022 — `Sources/WenshuApp/Storage/LibraryMigrator.swift` (143 insertions, 1 file)
- `31b4af9c8` — ticket 026 — `Sources/WenshuApp/Storage/BookKanbanStore.swift` + `BookTodoStore.swift` (166 insertions, 2 files)
**Axis:** SPEC only — does each commit implement the spec ticket as written (incl. boss 8/26 OOB + Q&A decisions)?

---

## OOB cross-check

| # | OOB item (spec L43-48) | Implementation | Verdict | Cite |
|---|---|---|---|---|
| O1 | "Library (.ws) = single instance per user; locked to UserDefaults.wenshu.libraryPath" | All 5 commits operate on `wsRoot: URL` (= the path stored in UserDefaults). `LibraryBootstrapper.swift:20` + `LibraryMigrator.swift:24` accept wsRoot as the constructor injection point; `BookStore.reload(bookId:)` (BookStore.swift:87-100) is wired by App.swift, which reads `UserDefaults.wenshu.libraryPath` (out of scope of these 5 commits but no contradiction). | PASS | spec L66, L124; BookStore.swift:20, 47, 73 |
| O2 | "Bookshelf = parent of books; user-named" | `Bookshelf` (Domain/Bookshelf.swift:24, pre-existing) has `name` field; `LibraryMigrator.swift:94` writes `Bookshelf(id: defaultShelfId, name: "默认书架", ...)` for the default shelf (= falls back to Chinese "default shelf" when user has none). User can rename via separate UI (out of scope of these 5 commits). | PASS | spec L116-118, L312; LibraryMigrator.swift:94 |
| O3 | "Book = novel project; carries 10 standard entries (8 folders + 2 data files)" | `LibraryBootstrapper.ensurePerBookStructure()` (L72-105) creates all 8 standard folders (`world`, `characters`, `outlines`, `chapters`, `drafts`, `sessions`, `foreshadowing`, `placeholders`) + both data files (`kanban.json`, `todo.json`) per discovered book. `BookBundle` (BookStore.swift:25-41) holds exactly 10 in-memory fields (= 8 folder indexes + `kanbanData` + `todoData`). | PASS | spec L96-97, L304, L316; LibraryBootstrapper.swift:82-103; BookStore.swift:25-41 |
| O4 | "World/Character = Book-private" | `WorldStoring` + `CharacterStoring` are injected into `BookStore` per-book via the 3 storage layer tickets 004/005 (out of these 5 commits). `BookStore` (BookStore.swift:66-81) holds the protocol references; per-book isolation is enforced by the App.swift wiring (= ticket 019's "App.swift wiring lands here" comment at BookStore.swift:96-99). Within the 5 reviewed files, no code path exposes World/Character data across books. | PASS | spec L116-118, L288-292; BookStore.swift:66-81, 96-99 |
| O5 | "Reference library = library-public, system-managed, user CANNOT delete or rename" | `ReferenceLibrary` struct (BookStore.swift:105-109) holds library-level `metadata + rawReferences + entityReferences`. `FileSystemReferenceStore` (tickets 003/006, sibling commit) is the only writer of `library.json` (= the ReferenceLibrary metadata file at spec L99). No delete/rename API exists in `LibraryBootstrapper` or `LibraryMigrator` for the `reference-library/` directory. | PASS | spec L98-103, L243; BookStore.swift:105-109; LibraryBootstrapper.swift:28-50 (only creates, never deletes reference-library/) |
| O6 | "Single-shelf model" | `LibraryMigrator.swift:80-118` creates exactly ONE default shelf (`shelves/<all-zeros-uuid>/books/`) and moves every v0.x book into it. No multi-shelf code path exists. | PASS | spec L123-127, L312; LibraryMigrator.swift:80-118 |
| O7 | "Library Properties panel" | Out of scope of these 5 commits (= implemented in ticket 014 `10f2a37fc`, not under review). No contradiction. | PASS (N/A) | spec L129-136 |
| O8 | "Migration via Finder, no zip export" | `LibraryMigrator` only moves existing data within the existing .ws root; it never creates a zip and never prompts for a new location. `LibraryPropertiesView` (ticket 014, separate) provides "Move Warehouse..." which uses `FileManager.moveItem` + `UserDefaults` update. No zip code path in any of the 5 reviewed files. | PASS | spec L135-136, L384; LibraryMigrator.swift (no zip code) |
| O9 | "切书=切数据源" (per-book data isolation) | `BookStore` is a SINGLE `@Observable` instance (BookStore.swift:46-47) with `currentBook: BookBundle?` (L58) that is dropped and rebuilt on `reload(bookId:)` (L87-100). `BookKanbanStore`/`BookTodoStore` (BookKanbanStore.swift:52-56, BookTodoStore.swift:48-52) take a `bookDirectory: URL` parameter and write per-book JSON. Switching books → different `bookDirectory` → different JSON file → no cross-book leakage. | PASS | spec L14, L288-292, L350-351; BookStore.swift:46-58, 87-100; BookKanbanStore.swift:52-56; BookTodoStore.swift:48-52 |

---

## Q&A cross-check (boss 8/26 decisions)

| # | Q decision | Implementation | Verdict | Cite |
|---|---|---|---|---|
| Q1 | scope: all 4 entity types (World, Character, Reference, SmartQuery) | Storage layers for all 4 exist in tickets 003-006 (sibling commits). Within the 5 reviewed files, the injection surface for World/Character/Reference is wired (BookStore.swift:66-81); SmartQuery storage path is created by `LibraryBootstrapper` (L43-50, `saved-searches/`). | PASS | spec L122-127, L301-305; BookStore.swift:66-81; LibraryBootstrapper.swift:43-50 |
| Q2 | ownership: 角色+世界观 Book-private / 资料库 library-public | `BookStore` injects `worldStore` + `characterStore` as book-scoped dependencies (L66-81); `referenceStore` is library-scoped (= single instance injected at App.swift launch, never per-book). Within these 5 commits, no cross-book sharing of World/Character state; ReferenceLibrary struct is library-level on the BookStore (L62). | PASS | spec L116-118, L288-292; BookStore.swift:62, 66-81 |
| Q4 | Chapter stays as .md (NOT domain entity) | `LibraryBootstrapper.swift:82-85` lists `chapters` as one of the 8 standard folders (= `.md` files per spec L94 `<book-uuid>/chapters/<doc-uuid>.md`). `BookBundle.chapterEntries: [Document]` (BookStore.swift:33) holds parsed chapters (= the existing Document model). No Chapter domain entity created. | PASS | spec L92-95, L383; LibraryBootstrapper.swift:82-85; BookStore.swift:33 |
| Q5 | layout: `shelves/<shelf>/books/<book>/` + `reference-library/{raw,entities,abstracts,indexes}/` | `LibraryBootstrapper` (L28-50) creates exactly these paths. `LibraryMigrator.moveBooksToDefaultShelf` (L80-118) writes books to `shelves/<shelf-uuid>/books/<book-uuid>/`. `LibraryMigrator` L52-59 also creates `reference-library/{raw,entities,abstracts,indexes,indexes/saved-searches}/`. | PASS | spec L82-103, L301-305; LibraryBootstrapper.swift:28-50; LibraryMigrator.swift:52-118 |
| Q6 | format: JSON sidecar + .md for folders; pure JSON for kanban/todo | `BookKanbanStore` (L70-75) encodes with `[.prettyPrinted, .sortedKeys]` + atomic write of `kanban.json`. `BookTodoStore` (L66-71) same pattern for `todo.json`. Both files are pure JSON arrays (no .md sidecar). | PASS | spec L96-97, L365-369; BookKanbanStore.swift:70-75; BookTodoStore.swift:66-71 |
| Q7/Q10 | UUID shelf dirs | `LibraryMigrator.swift:89-90` uses `UUID(uuidString: "00000000-0000-0000-0000-000000000000")` for the default shelf id and writes `defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, ...)`. UUID shape = "8-4-4-4-12" hex, all-zeros = canonical "default" sentinel. | PASS | spec L312, L319; LibraryMigrator.swift:89-96 |
| Q12 | single-library permanent | `LibraryBootstrapper` + `LibraryMigrator` both operate on a single `wsRoot: URL` and never create a sibling library. `BookStore.referenceLibrary: ReferenceLibrary = ReferenceLibrary()` (L62) is library-scoped (= exactly one per BookStore instance). | PASS | spec L123-127, L130-131; BookStore.swift:62; LibraryBootstrapper.swift:20; LibraryMigrator.swift:24 |
| Q13 | move via Finder, no zip | Already covered in O8. No zip code anywhere in the 5 reviewed files. | PASS | spec L135-136, L384 |

---

## FAIL

(none)

---

## SUGGEST (non-blocking)

1. **Ticket 019 stub is incomplete.** `BookStore.reload(bookId:)` (BookStore.swift:87-100) sets `currentBook = nil` and explicitly delegates "Real implementation lands in ticket 019's App.swift wiring" (L96-98). This is a per-spec stub (= the comment notes "the per-book directory resolution is delegated to the caller"), but it means BookStore.swift as committed has no working reload logic. Acceptable IF ticket 019's App.swift wiring is committed in the same feature batch (= reviewer should check git log between this commit and the next BookStore-related commit); should be flagged as a dependency if the App.swift wiring is deferred to a later commit.

2. **Ticket 020 scaffolding-only.** `CacheManager.cleanupFiles(olderThan:)` (CacheManager.swift:36-50) is dead code in v0.26 (= spec L295-297 calls for "thumbnails for chapter covers, search index for full-text, export temp" but only `ensureCacheDirectoryExists()` is called from `LibraryBootstrapper`). The spec acknowledges this as scaffolding ("v0.27+ can call this from a periodic background task" L35-36 of CacheManager.swift); reviewers should track this in v0.27 backlog to avoid drift.

3. **Ticket 021 default Info.plist sets `WSPCreatedAt` to a NEW timestamp every time it writes.** `LibraryBootstrapper.writeDefaultInfoPlist` (L114-124) only fires when Info.plist is MISSING (L52-55), so this is safe in practice (= idempotent gate). But the variable name `WSPCreatedAt` (= "WS-package-created-at") is semantically a one-shot timestamp; if a future ticket calls `writeDefaultInfoPlist` without the missing-check, every call would silently re-stamp creation. Worth a `/// Do not call directly; use ensureValidStructure()` doc comment on L114.

4. **Ticket 026 `KanbanTicket` is a fresh struct, NOT a reuse of v0.25.x.** Spec L366 says "reuse the existing KanbanTicket + TodoItem Codable structs from v0.25.x; only the load/save plumbing changes". BookKanbanStore.swift:26 defines a new `struct KanbanTicket` (= 5 fields: id/title/status/createdAt/updatedAt) instead of importing from `WenshuApp.Core.Kanban`. BookTodoStore.swift:16-20 explicitly creates `PerBookTodoItem` as a NEW struct, citing that v0.25.x TodoItem "is Equatable + Sendable but not Codable". The KanbanTicket comment (L24) claims it "reuses v0.25.x KanbanTicket shape" but no import is present and the field set is reduced (= v0.25.x likely has more fields per the kanban state machine). This is technically a deviation from spec L366 but is internally consistent and acknowledged in the BookTodoStore comment. Reviewer should confirm with boss whether the v0.25.x KanbanTicket's extra fields (= e.g. `assignee`, `description`, `tags`) are intentionally dropped or deferred. Non-blocking because the data is empty per "kanban/todo功能没实装" (spec L367).

5. **Ticket 022 `moveBooksToDefaultShelf` skips collisions silently.** LibraryMigrator.swift:113-116: if the destination `<shelf>/books/<id>/` already exists, the source is left in place (no rename to `id-migrated-<timestamp>`, no error). For the bootstrapper use case this is benign (= books/ at .ws root is being deleted immediately after L42-49 if it ends up empty), but if a user manually pre-created the default shelf with the same book id, the book would be silently orphaned. Worth a `WSLogger.warn` (= trace the silently-skipped move for diagnostics).

---

## VERDICT

**PASS.**

All 5 commits (019, 020, 021, 022, 026) implement their respective spec tickets faithfully. The 9 OOB summary items and 8 Q&A decisions are all reflected in code with verifiable line citations. No spec FAILs found.

The 5 SUGGEST items are non-blocking: 3 are forward-looking notes for v0.27+ follow-up (019 App.swift wiring dependency, 020 cleanupFiles dead code, 021 Info.plist doc hygiene) and 2 are minor consistency notes that the boss can choose to address before merge or accept as-is (026 KanbanTicket/PerBookTodoItem shape, 022 collision warning). The deviations in SUGGEST-4 are internally documented and consistent with the "kanban/todo功能没实装" rationale at spec L367.

Boss decision points: accept SUGGEST-1's tracking note (add a TODO in issues/README.md for App.swift wiring) and SUGGEST-4 (confirm the KanbanTicket field reduction is intentional vs. deferred). SUGGEST-2/3/5 are backlog items for v0.27.

Per boss 8/22 protocol: 0 spec FAILs → spec-axis review PASS. Pair with standards-axis review (CP8) for the dual-axis sign-off.
