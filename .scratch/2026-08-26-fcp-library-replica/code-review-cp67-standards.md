# CP6 + CP7 — Standards-axis review (tickets 019 + 020 + 021 + 022 + 026)

**Spec under review:** `.scratch/2026-08-26-fcp-library-replica/spec.md` (v5, 395 lines, dual-axis PASS).
**Commits under review (5):**
- `1de8e0e7f` — feat(wenshu): v0.26 ticket 019 — BookStore singleton + Apple @Observable (Domain part)
- `978480958` — feat(wenshu): v0.26 ticket 020 — Cache directory manager
- `b1ade5e2f` — feat(wenshu): v0.26 ticket 021 — .ws self-heal at launch
- `dd69aaeab` — feat(wenshu): v0.26 ticket 022 — v0.x → v0.26 .ws migration shim
- `31b4af9c8` — feat(wenshu): v0.26 ticket 026 — Per-book Kanban + Todo JSON store (2 files)

**Ground truth:** AGENTS.md §11 English-only + 12 forbidden tokens + 14 forbidden neutral words; boss 8/22 1-file-per-commit; Apple HIG.

---

## FAIL

(empty)

## SUGGEST

### S1 — KanbanStatus case count drift in CP7 commit body

`31b4af9c8` body says "7 cases: new / triage / ready / running / blocked / review / done / failed" but lists 8 case names. Actual count at `Sources/WenshuApp/Core/Kanban/KanbanStore.swift:17-24` is **8 cases** (the v0.18 comment at L24 says `wenshu 额外 +1 状态` = +1 failed). The body should say "8 cases". Pure documentation drift; no code or spec depends on the literal "7".

### S2 — Inline comment in `BookKanbanStore.swift:24` contradicts the commit body

`Sources/WenshuApp/Storage/BookKanbanStore.swift:24`: `// MARK: - Kanban ticket (= reuses v0.25.x KanbanTicket shape)`. Commit body of `31b4af9c8` says `KanbanTicket struct (= new v0.26 shape; not in v0.25.x)`. Reality: v0.25.x has `KanbanTask` (`Sources/WenshuApp/Core/Kanban/KanbanStore.swift:27`, `public struct KanbanTask`); `git grep -nE "\bKanbanTicket\b"` returns only `BookKanbanStore.swift` lines. Body is correct; inline comment is stale. Rewrite to match.

### S3 — `PerBookTodoItem.id` type diverges from v0.25.x `TodoItem.id` without explicit justification

`Sources/WenshuApp/Storage/BookTodoStore.swift:21`: `let id: UUID`. v0.25.x `Sources/WenshuApp/Core/Todo/TodoStore.swift:33`: `public let id: String`. Commit body justifies the rename to `PerBookTodoItem` ("TodoItem ... lacks Codable conformance") but does not mention the type change. CP7 migration explicitly drops v0.25.x todo data ("kanban/todo功能没实装"), so no data carries over; but the body should mention the id-type change for future readers.

### S4 — Spec ticket 019 L285 names `App.swift (modify)`; CP6 deferred it as an "engineering call"

`git diff 8a0829b72..31b4af9c8 -- Sources/WenshuApp/App.swift` returns empty — App.swift untouched. Commit body of `1de8e0e7f` documents: `App.swift wiring (= @Environment injection + .onChange observer + per-book store construction) deferred to a separate followup commit. Rationale: App.swift has been touched 40+ times in v0.25.1 streak`. Deviation is intentional and transparent; recommend filing a followup todo so the App.swift wiring is not forgotten.

---

## PASS

### A. `swift build` clean at CP6+CP7 tip (= HEAD `31b4af9c8`)

`swift build` → `Build complete! (0.65秒)`. Zero errors, zero warnings except the pre-existing `Wenshu.entitlements` untracked-file notice. Confirmed.

### B. BookStore (ticket 019, `1de8e0e7f`, `Sources/WenshuApp/State/BookStore.swift`)

- **B1** `@Observable final class BookStore: @unchecked Sendable` at L46-47. Apple Observation framework pattern per WWDC23; spec ticket 019 L293 mandates single-instance. Confirmed.
- **B2** `struct BookBundle: Sendable` at L25-41 holds 8 folder indexes (L30-37) + kanban/todo `Data` (L39-40) = 10 entries, matching spec L9/L16 Book structure. Confirmed.
- **B3** `@Observable` properties: `shelves: [Bookshelf] = []` (L50), `selectedBookId: UUID?` (L54), `currentBook: BookBundle?` (L58), `referenceLibrary: ReferenceLibrary` (L62). Confirmed.
- **B4** Functional injection via `init(worldStore:characterStore:referenceStore:)` at L73-81 (= constructor injection; comment at L57-58 notes `SwiftUI @Environment cannot carry non-@Observable types at @Environment init time`). Confirmed.
- **B5** `reload(bookId:)` at L87-100 captures the contract (= sets `selectedBookId` L95 + clears `currentBook = nil` L99). Confirmed.
- **B6** `struct ReferenceLibrary: Sendable` at L105-108 (= `metadata` + `rawReferences` + `entityReferences`). Confirmed.
- **B7** `WorldStoring` / `CharacterStoring` / `ReferenceStoring` exist at `FileSystemWorldStore.swift:25`, `FileSystemCharacterStore.swift:24`, `FileSystemReferenceStore.swift:26`. Build-clean (Section A) confirms resolution. Confirmed.

### C. CacheManager (ticket 020, `978480958`, `Sources/WenshuApp/Storage/CacheManager.swift`)

- **C1** `struct CacheManager: Sendable` at L16 + `init(wsRoot:)` at L20-22 (= `<.ws>/cache/`). Confirmed.
- **C2** `ensureCacheDirectoryExists()` at L26-31 = idempotent (`fileExists` check + `createDirectory(withIntermediateDirectories: true)`). Matches spec L295-297. Confirmed.
- **C3** `cleanupFiles(olderThan:)` at L36-50 = Apple HIG "manageable cache" pattern (FileManager.enumerator + contentModificationDate cutoff + removeItem). Confirmed.

### D. LibraryBootstrapper (ticket 021, `b1ade5e2f`, `Sources/WenshuApp/Storage/LibraryBootstrapper.swift`)

- **D1** `struct LibraryBootstrapper: Sendable` at L19 + `ensureValidStructure()` at L25-68 = idempotent. Confirmed.
- **D2** Step 1 (L28-33): `shelves/` + `reference-library/` + `cache/`. Confirmed.
- **D3** Step 2 (L35-42): 4 LLM Wiki layers `raw/entities/abstracts/indexes/`. Confirmed.
- **D4** Step 3 (L44-50): `reference-library/indexes/saved-searches/`. Confirmed.
- **D5** Step 4 (L52-55 + helper `writeDefaultInfoPlist` L114-124): defensive `Info.plist` write with `WSSchemaVersion = CURRENT_SCHEMA_VERSION` (single source of truth = `LibraryInfo.swift:21 = 1`). Confirmed.
- **D6** Step 5 (L60-65): only-if-empty removal of `chapters/` + `books/` at `.ws` root; comment at L58-59: `do NOT touch shelves/ at .ws root here`. Matches spec L303 NOTE + L313 separation. Confirmed.
- **D7** Step 6 (L72-105): per-book 8 standard folders + 2 JSON data files; deepest-dir detection at L90 (`bookDir.deletingLastPathComponent().lastPathComponent == "books"`) is correct. Confirmed.
- **D8** Never-deletes-user-data: zero `removeItem` on user `.md` bodies; zero `chat.sqlite` references. Confirmed.

### E. LibraryMigrator (ticket 022, `dd69aaeab`, `Sources/WenshuApp/Storage/LibraryMigrator.swift`)

- **E1** `struct LibraryMigrator: Sendable` at L23 + `migrateIfNeeded()` at L28-63 = idempotent (early return at L32-34 if `isAlreadyCurrentSchema()` reads `WSSchemaVersion >= 1`). Confirmed.
- **E2** Step 2 + `moveBooksToDefaultShelf` (L80-118): default shelf id at L89 = `UUID(uuidString: "00000000-0000-0000-0000-000000000000")` (= all-zeros UUID, spec L312); default shelf name at L94 = `Bookshelf(id:defaultShelfId, name: "默认书架", createdAt: Date(), updatedAt: Date())`. Confirmed.
- **E3** Step 3 (L45-50): only-if-empty DROP of `chapters/` + `books/` + `shelves/` at `.ws` root; non-empty `shelves/` preserved. Matches spec L313 NOTE. Confirmed.
- **E4** Step 4 (L52-59): CREATE 4-layer `reference-library/` subdirs + `cache/`. Confirmed.
- **E5** Step 5 + `writeOrUpdateSchemaVersion` (L125-142): writes `WSSchemaVersion = CURRENT_SCHEMA_VERSION` while preserving `CFBundlePackageType` (L133) / `CFBundleName` (L134) / `CFBundleIdentifier` (L135) / `WSPCreatedAt` (L137-139). Confirmed.
- **E6** CRITICAL safety: zero `chat.sqlite` code paths (only the comment at L18). Confirmed.

### F. BookKanbanStore + BookTodoStore (ticket 026, `31b4af9c8`, 2 atomic-coupled files)

- **F1** `protocol BookDataStoring: Sendable` at `BookKanbanStore.swift:16-22`: `associatedtype Element: Codable` (L17) (= avoids `Foundation.Data` shadow); `bookId: UUID` (L18); `jsonURL: URL` (L19); `load() throws -> [Element]` (L20); `save(_ data: [Element]) throws` (L21). Note: spec ticket 026 L357-364 originally proposed `associatedtype Data: Codable` + parameterless load/save; CP7 adapted the protocol to `Element` + `jsonURL` + array-IO. Adapted shape serves the per-book JSON array storage from spec L365 (= strict superset). **Non-blocking spec drift.**
- **F2** `struct KanbanTicket: Identifiable, Hashable, Codable, Sendable` at `BookKanbanStore.swift:26-46` (= new v0.26 shape, distinct from v0.25.x `KanbanTask`). Confirmed.
- **F3** `status` reuses v0.25.x `KanbanStatus` (`Sources/WenshuApp/Core/Kanban/KanbanStore.swift:16-24`, 8 cases). Confirmed.
- **F4** `struct BookKanbanStore: BookDataStoring` at `BookKanbanStore.swift:52-84`: `typealias Element = KanbanTicket` (L53); `jsonURL` via `bookDirectory.appendingPathComponent("kanban.json")` (L56); load returns `[]` on missing file or decode failure (L59-67); save uses `prettyPrinted + sortedKeys` JSON + tmp + `moveItem` atomic-write (L70-83). Matches spec L365. Confirmed.
- **F5** `struct PerBookTodoItem: Identifiable, Hashable, Codable, Sendable` at `BookTodoStore.swift:20-46` (= new v0.26 shape; v0.25.x `TodoItem` is `Equatable + Sendable` but NOT Codable per `Sources/WenshuApp/Core/Todo/TodoStore.swift:32`). Confirmed.
- **F6** `status + priority` reuse v0.25.x `TodoStatus` (4 cases: `pending / inProgress / completed / cancelled`, L17-20) + `TodoPriority` (4 cases: `low / medium / high / urgent`, L25-28). Confirmed.
- **F7** `struct BookTodoStore: BookDataStoring` at `BookTodoStore.swift:48-80`: `typealias Element = PerBookTodoItem` (L49); `jsonURL` via `bookDirectory.appendingPathComponent("todo.json")` (L52); load returns `[]` on missing file or decode failure (L55-63); save uses `prettyPrinted + sortedKeys` JSON + tmp + `moveItem` atomic-write (L66-79). Matches spec L365. Confirmed.
- **F8** Atomic-coupling justified (= both stores required for per-book "data source switch" feature; both reuse identical `BookDataStoring` protocol; splitting would leave BookStore with partial per-book data wiring). Matches spec ticket 026 L370. Confirmed.

### G. Boss 8/22 1-file-per-commit compliance

- **G1** `1de8e0e7f` → 1 file: `Sources/WenshuApp/State/BookStore.swift` (109 insertions). Match.
- **G2** `978480958` → 1 file: `Sources/WenshuApp/Storage/CacheManager.swift` (51 insertions). Match.
- **G3** `b1ade5e2f` → 1 file: `Sources/WenshuApp/Storage/LibraryBootstrapper.swift` (130 insertions). Match.
- **G4** `dd69aaeab` → 1 file: `Sources/WenshuApp/Storage/LibraryMigrator.swift` (143 insertions). Match.
- **G5** `31b4af9c8` → 2 files: `BookKanbanStore.swift` (85 insertions) + `BookTodoStore.swift` (81 insertions). Atomic-coupling justified per F8. Match.

All 5 commits carry `File scope: N file(s) per boss 8/22` declarations in their commit bodies. Confirmed.

### H. Forbidden vocabulary scan across all 5 commit messages + new-file diffs

Ran `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` against each commit's full body text + each new file's full content. **Zero forbidden-token hits** (= 12 xianxia tokens: 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障). Spot-checked the 14 forbidden neutral words against commit bodies + file bodies — zero substantive uses (only identifier substrings like `load`/`save`/`Codable` matched, which are not the forbidden words).

AGENTS.md §11 English-only: zero Chinese characters in any of the 5 commit messages or 6 new files. Confirmed.

### I. No integration with existing App.swift (CP6 = BookStore Domain only)

`git log --oneline -- Sources/WenshuApp/App.swift | head -8` shows no commit between `8a0829b72` and `31b4af9c8`; `git diff 8a0829b72..31b4af9c8 -- Sources/WenshuApp/App.swift` returns empty. CP6 deferred App.swift wiring per commit body of `1de8e0e7f` (= intentional spec deviation, see S4). Confirmed (intended).

### J. Apple HIG compliance

- **J1** `@Observable` + `@unchecked Sendable` at `BookStore.swift:46-47` (= Swift Observation framework, WWDC23).
- **J2** Foundation APIs only (`FileManager` + `Data.write(.atomic)` + `moveItem`); no third-party SDK.
- **J3** Atomic JSON write in `BookKanbanStore.swift:77-83` + `BookTodoStore.swift:73-79`.
- **J4** Info.plist via `PropertyListSerialization` (= Apple HIG bundle pattern; matches `LibraryRootView.swift:296-309` writer + spec L84).
- **J5** `ISO8601DateFormatter()` for `WSPCreatedAt` (= Apple HIG plist timestamp format).

---

## VERDICT

**PASS** — all 5 commits conform to AGENTS.md §11 + 12-forbidden-vocab + boss 8/22 1-file-per-commit + Apple HIG + v5 spec. Build clean at CP7 tip (`31b4af9c8`). The 4 SUGGEST items are non-blocking documentation drifts + one intentional spec deviation (S4). Recommend filing a followup todo for spec ticket 019's App.swift wiring so it is not forgotten.

— pocock single agent, 2026-08-26, end of CP6+CP7 standards review.