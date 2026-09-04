# v0.27-01 spec-axis review — ticket 027-01 Library lifecycle wiring

Commit under review: `7aa34bf85` ("feat(wenshu): v0.27 ticket 027-01 —
Library lifecycle hook + BookStore LibraryStores wiring"). Touches 2
files: `Sources/WenshuApp/State/LibraryLifecycleHook.swift` (new) +
`Sources/WenshuApp/State/BookStore.swift` (modified).

Spec source of truth: `.scratch/2026-08-26-fcp-library-replica/spec.md`
v5 (ticket 019 L283-293 + ticket 021 L299-305 + ticket 022 L307-319).

## OOB cross-check

1. **Library = .ws, single instance, locked to UserDefaults** — PASS.
   `LibraryLifecycleHook.wsRoot: URL` (`LibraryLifecycleHook.swift:15`)
   is the single injected root; `runLaunch()` (L17-24) is the only
   construction surface.

2. **Bookshelf = parent of books; user-named** — PASS (adjacent).
   `LibraryStores.shelvesRoot` (`LibraryLifecycleHook.swift:39`) points
   at `<ws>/shelves/`, the canonical Bookshelf container per spec
   L87-91.

3. **Book = 10 standard entries per book** — PASS.
   `BookStore.reload(bookId:)` (`BookStore.swift:121-128`) resolves
   `<shelves>/books/<book-id>/`. The 10-entry root is owned by
   `LibraryBootstrapper.ensurePerBookStructure()`
   (`LibraryBootstrapper.swift:72-105`), called from `runLaunch()` via
   `bootstrapper.ensureValidStructure()` (`LibraryLifecycleHook.swift:21`).

4. **World + Character = Book-private** — PASS.
   `LibraryStores.makeBookStores(for:)` (`LibraryLifecycleHook.swift:46-51`)
   constructs `FileSystemWorldStore` + `FileSystemCharacterStore` per
   book directory; both protocols declare `var bookDirectory: URL`
   (e.g. `FileSystemWorldStore.swift:29`), enforcing Book-privacy at
   the type level.

5. **Reference library = library-public** — PASS.
   `LibraryStores.referenceStore` (`LibraryLifecycleHook.swift:41`) is
   constructed **once** at launch with `referenceLibraryRoot`
   (library-level, NOT nested under any shelf).

6. **"切书=切数据源" requirement** — PARTIAL PASS (see SUGGEST-1).
   `BookStore.reload(bookId:)` (`BookStore.swift:121-128`) sets
   `currentBookDirectory` and drops `currentBook = nil`, matching
   spec ticket 019 L292 "drops the previous bundle" pattern. **The
   body-load itself** ("reads `books/<book-id>/book.json + 8 JSON
   sidecars + kanban.json + todo.json` into in-memory state", spec
   L292) is NOT in `reload` — only path-resolution + nil-out. Same
   shape as v0.26's stub `reload`; v0.27-01 adds the path piece.
   NOT a regression.

7. **Apple standard: one @Observable singleton BookStore** — PASS.
   `@Observable final class BookStore: @unchecked Sendable`
   (`BookStore.swift:52-53`). No per-book instance factory exists;
   per-book resolution is via `LibraryStores.makeBookStores(for:)`.
   Spec L293 forbids per-book instances; this commit complies.

8. **App.swift untouched (41+ touches in v0.25.1 streak)** — PASS.
   `git show --stat 7aa34bf85` shows only 2 files modified, both in
   `State/`. App.swift wiring deferred to v0.27-04 per the commit's
   strategy section.

## Q&A cross-check

**Spec ticket 019 L283-293** (App.swift wiring):
- "Replace v3's load 4 stores with single BookStore (@Observable),
  observed for selectedBookId changes" — PASS (contract only).
  `LibraryLifecycleHook.runLaunch()` (L17-24) runs the exact launch
  sequence the spec describes. The `.onChange(of: selectedBookId)`
  observer in App.swift is deferred (out of scope per the commit
  rationale); the type surface is ready via `BookStore.reload(bookId:)`.

**Spec ticket 019 L285-291** ("BookStore holds"):
- `var shelves: [Bookshelf]` — PASS. `BookStore.swift:56`.
- `var selectedBookId: UUID?` — PASS. `BookStore.swift:60`.
- `var currentBook: BookBundle?` — PASS. `BookStore.swift:64`.
- `var referenceLibrary: ReferenceLibrary` — PASS. `BookStore.swift:75`.
- `@Environment(BookStore.self)` — DEFERRED (App.swift wiring,
  explicitly out of v0.27-01 scope).

**Spec ticket 019 L292** ("reload reads books/<id>/...; drops previous"):
- Path resolution — PASS. `BookStore.swift:123-126` builds
  `shelvesRoot/books/<book-id-uuid-string>/`.
- Previous bundle drop — PASS. `BookStore.swift:127`.
- Read into in-memory state — DEFERRED (see OOB-6).

**Spec ticket 021** (LibraryBootstrapper): PASS. `LibraryBootstrapper.swift:28-33` +
`60-65` + `82-103` cover the spec; callable from `runLaunch()` L21.

**Spec ticket 022** (LibraryMigrator): PASS (already shipped in v0.26
ticket 022 commit `dd69aaeab`); v0.27-01 only CALLS it via
`LibraryLifecycleHook.swift:18-19`. Idempotency at
`LibraryMigrator.swift:32-34`.

The only spec line not yet implemented is L292's body-load — deferred
to v0.27 followup. Everything else ships or is explicitly deferred.

## FAIL

(empty — no spec-axis violations)

## SUGGEST

1. **(non-blocking)** `BookStore.init(stores:)` constructs per-book
   stores against `stores.shelvesRoot`, not a book directory.
   `BookStore.swift:83-86` calls
   `stores.makeBookStores(for: stores.shelvesRoot)` — but `shelvesRoot`
   is `<ws>/shelves/` (all shelves + books), not a single book dir.
   The init-time `worldStore` / `characterStore` are dead code
   (`grep` confirms zero call sites in `Sources/WenshuApp/Views/`).
   Pre-resolution should be removed or deferred; v0.27-04 App.swift
   wiring should call `stores.makeBookStores(for: currentBookDirectory)`
   from the `.onChange` observer. NOT a spec violation (spec ticket
   019's per-book store construction is App.swift wiring, deferred).

2. **(non-blocking)** `LibraryLaunchResult` declares no factory.
   `BookStore.swift:80` documents "the canonical path is via
   `LibraryLaunchResult.makeBookStore()`" — that factory does not
   exist. v0.27-04 will need to construct `BookStore(stores:
   result.stores)` directly. Minor doc/code drift.

3. **(non-blocking)** `BookDirectoryResolving` protocol
   (`LibraryLifecycleHook.swift:73-76`) is declared but unused;
   reserved for v0.27-03 LLM Wiki ingestion (per commit message).
   Forward-declared extension point with explicit documentation —
   acceptable per Apple HIG.

4. **(non-blocking, outside v0.27-01 scope)** Pre-existing build
   break in untracked `Sources/WenshuApp/Domain/SmartQueryParser.swift`
   — references an `AnyJSON` type that does not exist anywhere
   (`grep -rn` returns nothing). `git ls-files` shows the file is
   NOT tracked. `swift build` fails identically with or without the
   v0.27-01 commit. The v0.27-01 commit message's "swift build: clean"
   was true at commit time but is no longer true on the working tree.
   Project-owner action: remove or finish the SmartQueryParser work.
   v0.27-01's 2 files compile cleanly in isolation. All 4 v0.26
   contract test suites (`WorldStoring` / `CharacterStoring` /
   `ReferenceStoring` / `LibraryStoring`) PASS — confirming
   v0.27-01's back-compat init doesn't regress store contracts.

## VERDICT

**PASS**

Every boss 2026-08-26 OOB item lands or is correctly deferred. Every
spec ticket 019 / 021 / 022 contract is either shipped in v0.27-01
or explicitly documented as deferred to v0.27-04 (App.swift wiring).
The 2-file atomic coupling is correct. App.swift is preserved
(v0.25.1 streak integrity). The 4 non-blocking SUGGEST items are
real but introduce neither regressions nor spec contradictions.
Pre-existing build break is outside v0.27-01's scope.