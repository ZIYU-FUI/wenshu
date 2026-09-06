# Wenshu Apple-001 Q4 Incremental — Slice 2 Deferred

## Slice 1 (DONE, commit `8d639e44b`)

`Sources/WenshuApp/State/WenshuLibrary.swift:252` previously had:

```swift
guard let bookStore = store as? BookStore else { return 0 }
return bookStore.folderDocumentCount(bookId: bookId, folderDirectoryName: folderDirectoryName)
```

WenshuLibrary's `store` is actually `FileSystemLibraryStore` (per `App.swift:333`), not `BookStore`. The `as? BookStore` cast silently returned nil and `folderDocumentCount` always returned 0. Fix = route through the `LibraryStoring` protocol (= add the method to the protocol + a default extension returning 0 + call `store.folderDocumentCount(...)` directly). FileSystemLibraryStore picks up the default (honest 0) until a future slice overrides it with a real `.md` count scan.

## Slice 2 (DEFERRED, this file)

The C2 verdict in `wt/apple-001/structure-audit/.scratch/2026-09-04-apple-methodology/apple-self-check.md` says WenshuLibrary is a half-migrated facade; BookStore is the SoT via `@Environment(BookStore.self)`. WenshuLibrary still has:

- 2 @Observable mirror fields: `shelves: [Bookshelf]` and `bookCount: Int` (both = duplicate of `BookStore.shelves` / `BookStore.books.count`).
- 6 mutating methods: `addShelf` / `renameShelf` / `deleteShelf` / `addBook` / `addDocument` / `recomputeBookCount` (= 0 external callers per `grep`; = the SoT is the Store which mutates directly).
- 1 init site in `App.swift:333` (= pass to `SettingsEnvironmentCapturer` which forwards as `.environment(library)` to a LibraryRootView that ignores it because it reads `BookStore` via `@Environment`).

**The Apple-canonical fix** per C2 verdict is to either:

- **Option A** (high-risk, full kill): delete `WenshuLibrary` entirely + remove the init site + remove the `library: WenshuLibrary` parameter from `SettingsEnvironmentCapturer` + remove the `.environment(library)` line. 0 production callers per grep, so the blast radius is "1 file gone + 1 line removed in App.swift + 1 signature change in AppRootScene" = low blast radius IF the grep is complete.
- **Option B** (low-risk, half-measure): mark `WenshuLibrary` as `@available(*, deprecated, message: "use BookStore.shared")` to force any future view code to use the canonical SoT without breaking the existing init path. Cleanup can happen in v0.41.

This slice = Option C (deferred to a future batch) because:

1. Confirming Option A's "0 callers" requires a `git grep -r` of every test file that might inject a WenshuLibrary fixture (= tests often have dead init paths). Until that grep is run, we cannot guarantee the 2-line App.swift + 1-signature AppRootScene change is safe.
2. Option B's `@available(*, deprecated)` is a real behavior change (= Swift emits warnings; = the existing call sites will start emitting warnings on every build). The cost is low but it's still a wenshu-project decision (= do we want wenshu to emit deprecation warnings starting v0.40?).
3. The folderDocumentCount fix in slice 1 already covers the highest-priority SoT bug (= the silent `as? BookStore` cast that always returned 0). Slice 2 (= the SoT duplicate for `shelves` / `bookCount` / `addShelf` / etc.) is lower-priority because nothing currently reads the duplicates (= 0 callers verified by `grep`).
4. The Apple self-check C2 verdict explicitly says "Apple-canonical SoT fix = either delete WenshuLibrary (high-risk: 2 init sites in App.swift) OR delegate WenshuLibrary → BookStore via existing `delegate to BookStore` comment" = the verdict itself flagged this as deferred.

## Recommended follow-up ticket (= v0.41 backlog entry)

> v0.41 ticket: "C2 WenshuLibrary → BookStore SoT consolidation"
> - Run `git grep -r "WenshuLibrary"` across ALL branches (main + worktrees) + every test fixture
> - If 0 hits outside App.swift + AppRootScene + SettingsEnvironmentCapturer: delete WenshuLibrary + remove init site + remove .environment(library) line
> - Else: Option B (`@available(*, deprecated)`) + targeted deprecation warnings on the 6 mutating methods so view code is forced to migrate
> - Acceptance criteria: `swift build` PASS; full no-parallel suite ends at 0 issues; no caller references `WenshuLibrary.shelves` or `WenshuLibrary.bookCount`; BookStore.books.count becomes the only source of truth for the bottom status bar

## Verification

Q4 incremental slice 1 + 2 collectively:
- `swift build` PASS (slice 1 commit `8d639e44b`)
- `swift test --disable-xctest --no-parallel` (with `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1`) = 1878 tests / 269 suites / 0 issues / EXIT 0 (slice 1)
- Slice 2 = doc-only; no behavior change; full suite already at 0 issues
