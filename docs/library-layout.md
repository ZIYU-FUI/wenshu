# The `.ws` library directory layout

Every `.ws` library is a macOS package directory the user picks once and
the app then owns. This file records what lives where, which directory is
the canonical home of what, and which directories are residue from an
older layout that no code reads any more.

Read the two-trap section first: two directories in a `.ws` look like
leftovers and are not, or look like live storage and are not.

## Where the library root comes from

The root is **not** a path string in `UserDefaults`. It is a
security-scoped bookmark, and the string key it replaced is gone.

| Step | Source | Symbol |
| ---- | ------ | ------ |
| Persist | `Sources/WenshuApp/Features/Library/Store/LibraryBookmark.swift` | `LibraryBookmark.make(for:)` writes `url.bookmarkData(options:)`; `LibraryBookmark.save(_:)` stores it under `LibraryBookmark.defaultsKey` (= `"wenshu.libraryBookmark"`) |
| Resolve | `Sources/WenshuApp/Features/Library/Store/LibraryBookmark.swift` | `LibraryBookmark.resolve()` calls `URL(resolvingBookmarkData:options:bookmarkDataIsStale:)`, refreshes the bookmark when it reports stale, and clears the key when it cannot be decoded |
| Canonical accessor | `Sources/WenshuApp/Features/Library/Store/ActiveLibrary.swift` | `ActiveLibrary.path` (= the only supported way to read the root), `ActiveLibrary.setActiveLibrary(at:)`, `ActiveLibrary.clear()` |
| Sandbox grant | `Sources/WenshuApp/Shared/UI/LibraryRootView.swift` | `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` around the launch I/O |
| Legacy key retired | `Sources/WenshuApp/App/WenshuAppDelegate.swift` | a one-shot cleanup removes `"wenshu.libraryPath"`; no production code reads it |

`LibraryBookmark.isSandboxedProcess` decides the option set: a sandboxed
build uses `.withSecurityScope`, a non-sandboxed build uses the empty set.
The two formats do not decode in each other's process class.

To find a library on disk, read the bookmark data at
`LibraryBookmark.defaultsKey` and resolve it with
`URL(resolvingBookmarkData:options:bookmarkDataIsStale:)`. Never
hard-code a path, and never assume any fixed location for the package:
the user picks it, and the bookmark is the only record of where.

## The directory tree

```
<library root>/
  Info.plist                     package marker + schema version
  Icon                           Finder custom icon for the package
  WenshuStore.store              SwiftData store (the warehouse)
  chat.sqlite                    chat history
  shelves/
    <shelf-uuid>/
      shelf.json                 shelf metadata
      books/
        <book-uuid>/
          book.json              book metadata
          world/                 per-book folder
          characters/            per-book folder
          outlines/              per-book folder
          chapters/              per-book folder
          drafts/                per-book folder
          sessions/              per-book folder
          kanban.json            board
          todo.json              todo list
          chapters.json          chapter index
          outlines.json          outline index
  reference-library/
    library.json                 reference-library metadata
    raw/                         layer: imported source material
      raw.json                   layer index
      <uuid>.md                  body copy
    entities/                    layer: extracted entities
      entities.json              layer index
      <uuid>.md                  body copy
  references/
    <uuid>.md                    canonical reference body
  assets/
    covers/
      <card-key>/                card cover art
        cover.heic               still image
        cover.mp4                video clip
        cover.json               cover record
  cache/                         scratch (chat uploads)
    chat-uploads/                pasted images
  .import-cache/                 import idempotency sidecar
    import-cache.json            the sidecar itself
  archives/                      archivist storage
  migration-backups/             pre-migration SwiftData snapshots
```

## Trap 1: `references/` is live, and `reference-library/` is a second copy

Both directories hold a reference document's markdown body, and both are
written by production code. This is deliberate, not residue.

`references/<uuid>.md` is the **canonical body**. The path comes from one
function:

```swift
// Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift
nonisolated static func referenceFileURL(
    id: UUID,
    referenceLibraryRoot: URL
) -> URL {
    let referencesRoot = referenceLibraryRoot
        .deletingLastPathComponent()          // from reference-library/ up to the .ws root
        .appendingPathComponent("references", isDirectory: true)
    return referencesRoot.appendingPathComponent(
        "\(id.uuidString).md", isDirectory: false
    )
}
```

Note the shape of that derivation: the function takes the
`reference-library/` root and walks **up** one level to reach the `.ws`
root, then down into `references/`. The result is a sibling of
`reference-library/`, not a child of it.

Who reads and writes it:

| Role | Source | Symbol |
| ---- | ------ | ------ |
| Read (first choice) | `Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift` | `loadReferenceBody(id:)` reads this path first and returns it when present |
| Read | `Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift` | `readReferenceFileFromFileSystem(id:referenceLibraryRoot:)` |
| Write | `Sources/WenshuApp/Features/Editor/Store/EditorPersistence.swift` | `EditorPersistence.save(tab:bookStore:)` writes the tab's `documentPath`, and for a reference tab that path is the one above; it creates the parent directory before the write (= the directory is created by the write, not by the bootstrapper) |
| Editor | `Sources/WenshuApp/Features/Editor/View/CardOpenOps.swift` | the reference tab's `documentPath` is `FileSystemReferenceStore.referenceFileURL(id:referenceLibraryRoot:)` |
| Editor | `Sources/WenshuApp/Features/Editor/Store/EditorPersistence.swift` | `referenceUUIDFromReferencePath(_:)` returns nil unless the **parent directory name** is exactly `"references"` (= that literal is how the editor tells a reference tab from a book chapter) |

The store also has a writer for this path,
`FileSystemReferenceStore.writeReferenceFileToFileSystem(id:bodyMarkdown:referenceLibraryRoot:)`.
It is **not** the live writer, and the reason is worth knowing: it is
called only from `saveReference` and `replaceReference`, and only on the
branch that runs when the store has a SwiftData container
(= `guard modelContainer != nil`). Every construction of
`FileSystemReferenceStore` in the app omits that container
(`Sources/WenshuApp/Shared/State/LibraryLifecycleHook.swift`,
`Sources/WenshuApp/Features/Agent/View/ImportSheet.swift`,
`Sources/WenshuApp/Features/Agent/Service/ReferenceLibraryTool.swift`,
`Sources/WenshuApp/Features/Agent/Service/BookManagerTool.swift`), so
`modelContainer` is always nil and the app always takes the file-system
branch.

`reference-library/<layer>/<uuid>.md` is the **second copy**. It is the
per-layer body, written by `saveReferenceToFileSystem`,
`replaceReferenceToFileSystem`, and `upsertReferenceToFileSystem` (all in
`Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift`),
next to the layer's index file `<layer>.json`. These are the paths the
live branch takes, so the layer copy is what the agent and the importer
write.

So the two copies divide as:

| | `references/<uuid>.md` | `reference-library/<layer>/<uuid>.md` |
| --- | --- | --- |
| Role | the canonical body | the layer copy |
| Written by | the editor (= `EditorPersistence.save`) | the agent and the importer (= the store's file-system branch) |
| Index | none (= the filename is the id) | `<layer>.json` next to it |
| Layer-specific | no (= flat across layers) | yes (= one directory per `ReferenceLayer`) |
| Read by | `loadReferenceBody` (first), the editor | `loadReferenceBody` (fallback, when the canonical file is absent), `loadReferenceBodyFromFileSystem` |

`loadReferenceBody` in `Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore.swift`
reads the canonical file first and only falls back to scanning the layer
directories when the canonical file is missing. Deleting `references/`
does not lose the text (= the layer copy still has it), but it moves the
library back to the fallback path and the editor's reference-tab
detection stops matching (= `referenceUUIDFromReferencePath` returns nil
for anything that is not under a directory named `references`).

**Both copies stay.** Deleting either one changes behaviour.

## Trap 2: `shelves/chapters/` is an old flat layout, and nothing reads it

The live chapter path is per-book:

```
shelves/<shelf-uuid>/books/<book-uuid>/chapters/<uuid>.md
```

`Sources/WenshuApp/Features/Library/Service/FileSystemChapterStore.swift`
derives it as `bookDirectory` + `"chapters"`, and
`Sources/WenshuApp/Features/Library/Service/FileSystemLibraryStore.swift`
resolves `bookDirectory` by scanning `shelves/<shelf>/books/<book-uuid>`.
`Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift`
(`createBook(input:)`) and
`Sources/WenshuApp/Features/Library/Store/BookStore+SidebarInline.swift`
(`bookDirectory(bookId:)`) use the same per-book shape.

The flat `shelves/chapters/` (= chapters directly under `shelves/`, with
no shelf and no book level) belongs to a **previous generation** of the
layout. Two independent facts show no code reaches it:

- `Sources/WenshuApp/Features/Library/Service/LibraryMigrator.swift`
  (`migrateIfNeeded`) drops the empty orphans `"chapters"`, `"books"`,
  `"shelves"` **at the `.ws` root** (= `wsRoot.appendingPathComponent(orphan)`),
  not at `shelves/chapters/`.
- `Sources/WenshuApp/Shared/UI/LibraryRootView.swift`
  (`LibraryOnboardingView.createWenshuWorkspace(at:)`) creates
  `["shelves", "books", "chapters", "assets", "backups"]` **at the `.ws`
  root**, not under `shelves/`.

The shelf scan confirms it: `FileSystemLibraryStore.loadShelves()` in
`Sources/WenshuApp/Features/Library/Service/FileSystemLibraryStore.swift`
keeps a directory only when it holds a `shelf.json`
(= `guard fm.fileExists(atPath: jsonURL.path) else { continue }`), so a
`shelves/chapters/` directory with no `shelf.json` is skipped as a shelf.
`loadBooks(shelfId:)` then looks under `<shelf>/books/`, which
`shelves/chapters/` is not.

**`shelves/chapters/` is safe to delete.** Nothing reads it.

One caveat, because the same string appears in live code:
`DraftPersistence.proposedPath(for:bookStore:)` in
`Sources/WenshuApp/Features/Editor/Service/EditorActions.swift` builds
`<shelvesRoot>/chapters/<tab-uuid>.md`, and `shelvesRoot` is the `.ws`
root's `shelves/` directory, so that path is `shelves/chapters/`. Its own
comment says it uses the shelves root as a stand-in for the active book
because there is no active-book-id surface yet. It is a **write** target
for a tab that has no `documentPath` yet, not a read target: the
per-book readers above never look there. A file that lands there is
written but not reloaded, which is a separate concern from this layout
record.

## Every directory, with its reader and its creator

"Canonical" means the location the app treats as the home of that data.

| Path | Purpose | Canonical | Read by | Created by |
| ---- | ------- | --------- | ------- | ---------- |
| `Info.plist` | package marker (`CFBundlePackageType` = `WSPC`) + `WSSchemaVersion` + `WSPCreatedAt` | yes | `Sources/WenshuApp/Features/Library/Service/LibraryInfo.swift`; `LibraryMigrator.isAlreadyCurrentSchema()` | `LibraryOnboardingView.createWenshuWorkspace(at:)` (`Sources/WenshuApp/Shared/UI/LibraryRootView.swift`); `LibraryBootstrapper.writeDefaultInfoPlist(to:)`; `LibraryMigrator.writeOrUpdateSchemaVersion()` |
| `Icon` | the Finder custom icon for the package | no (= a Finder artifact, not app data) | Finder | `LibraryOnboardingView.createWenshuWorkspace(at:)` (= `NSWorkspace.setIcon`) |
| `WenshuStore.store` | the SwiftData warehouse store | yes | `Sources/WenshuData/Sources/WenshuData/Container.swift` (`makeContainerForWarehouse(_:)`) | the same container factory |
| `chat.sqlite` | chat history | yes | `Sources/WenshuApp/App/WenshuAppDelegate.swift` | the same delegate (= the file is placed inside the warehouse) |
| `shelves/` | the book container | yes | `FileSystemLibraryStore.loadShelves()`; `BookStore+SidebarInline.bookDirectory(bookId:)` | `LibraryBootstrapper.ensureValidStructure()`; `LibraryMigrator.moveBooksToDefaultShelf(from:)`; `LibraryOnboardingView.createWenshuWorkspace(at:)` |
| `shelves/<shelf-uuid>/shelf.json` | shelf metadata | yes | `FileSystemLibraryStore.loadShelves()` | `FileSystemLibraryStore.saveShelf(_:)`; `LibraryMigrator.moveBooksToDefaultShelf(from:)` |
| `shelves/<shelf-uuid>/books/<book-uuid>/` | the book container | yes | `FileSystemLibraryStore.loadBooks(shelfId:)`; `BookStore+SidebarInline.bookDirectory(bookId:)` | `SidebarServiceMutation.createBook(input:)`; `FileSystemLibraryStore.saveBook(_:)` |
| `shelves/<shelf-uuid>/books/<book-uuid>/book.json` | book metadata | yes | `FileSystemLibraryStore.loadBooks(shelfId:)` | `SidebarServiceMutation.createBook(input:)`; `LibraryMigrator.seedDefaultHelpDoc(in:fm:)` |
| `.../world/` `characters/` `outlines/` `chapters/` `drafts/` `sessions/` | the standard per-book folders | yes | `Sources/WenshuApp/Features/Library/Model/BookFolderCatalog.swift` (= the SSOT for the folder set and their names) | `LibraryBootstrapper.ensurePerBookStructure()`; `LibraryMigrator.seedDefaultHelpDoc(in:fm:)`; `SidebarServiceMutation.createBook(input:)` |
| `.../kanban.json` | board items for the book scope | yes | `Sources/WenshuApp/Features/Library/Service/BookKanbanStore.swift` (scope `.book`) | `LibraryBootstrapper.ensurePerBookStructure()`; `LibraryMigrator.seedDefaultHelpDoc(in:fm:)`; `SidebarServiceMutation.createBook(input:)` |
| `.../todo.json` | todo items for the book scope | yes (= written, but the todo surface persists through SwiftData) | written by the three creators above; no reader in the app (`Sources/WenshuData/Sources/WenshuData/Repositories/WSTodoRepository.swift` is the todo store, and it is SwiftData-backed) | the three creators above |
| `.../chapters.json` | the chapter index for the book | yes | `Sources/WenshuApp/Features/Library/Service/FileSystemChapterStore.swift`; `Sources/WenshuApp/Features/Library/Service/BookExportEngine.swift` | `LibraryMigrator.seedDefaultHelpDoc(in:fm:)`; `Sources/WenshuApp/Features/Agent/Service/BookChapterTool.swift` |
| `.../outlines.json` | the outline index for the book | yes | `Sources/WenshuApp/Features/Library/Service/FileSystemOutlineStore.swift` | `Sources/WenshuApp/Features/Agent/Service/BookOutlineTool.swift` |
| `.../entities/` + `entities.json` | the per-book entity store (characters and world entries) | no (= not created by the app) | `Sources/WenshuApp/Features/Library/Service/FileSystemEntityStore.swift` resolves both under its `bookDirectory`; the only writer, `EntityMigration.migrateFromLegacyIfNeeded(bookDirectory:)` (`Sources/WenshuApp/Features/Library/Service/EntityMigration.swift`), has no caller in the app | `EntityMigration.migrateFromLegacyIfNeeded(bookDirectory:)` (= no app caller, so the directory does not appear in a fresh library) |
| `reference-library/` | the reference library root | yes | `Sources/WenshuApp/Shared/State/LibraryLifecycleHook.swift` (`constructStores(wsRoot:)`) builds the store on it | `LibraryBootstrapper.ensureValidStructure()`; `LibraryMigrator.migrateIfNeeded()` |
| `reference-library/library.json` | reference-library metadata | yes | `FileSystemReferenceStore.loadMetadataFromFileSystem(referenceLibraryRoot:)` | `FileSystemReferenceStore.saveMetadataToFileSystem(metadata:referenceLibraryRoot:)` |
| `reference-library/raw/` | layer: imported source material | yes | `FileSystemReferenceStore.loadReferencesFromFileSystem(referenceLibraryRoot:layer:)` | `LibraryBootstrapper.ensureValidStructure()`; `LibraryMigrator.migrateIfNeeded()` |
| `reference-library/entities/` | layer: extracted entities | yes | the same | the same |
| `reference-library/<layer>/<layer>.json` | the layer index | yes | `FileSystemReferenceStore.loadReferencesFromFileSystem(referenceLibraryRoot:layer:)` | `FileSystemReferenceStore.writeIndexToFileSystem(_:at:layer:)` |
| `reference-library/<layer>/<uuid>.md` | the layer's body copy | no (= a second copy; see trap 1) | `FileSystemReferenceStore.loadReferenceBody(id:)` (fallback) | `FileSystemReferenceStore.saveReferenceToFileSystem(reference:bodyMarkdown:referenceLibraryRoot:)` and its `replace` / `upsert` siblings |
| `references/<uuid>.md` | the canonical reference body | yes | `FileSystemReferenceStore.loadReferenceBody(id:)`; the editor via `referenceUUIDFromReferencePath(_:)` | the editor's `EditorPersistence.save` (= the store's own writer for this path is on its SwiftData branch, which the app never takes) |
| `assets/covers/<card-key>/` | card cover art | yes | `Sources/WenshuApp/Features/Cover/Model/CardCoverService.swift` (`coversRoot`, `directory(forKey:)`) | the same service, on first cover write |
| `cache/` | scratch space | no | `Sources/WenshuApp/Features/Chat/Service/LiveChatRepository.swift` (`copyChatUpload(sourceURL:intoLibraryAt:)` writes `cache/chat-uploads/`) | `LibraryBootstrapper.ensureValidStructure()`; `LibraryMigrator.migrateIfNeeded()` |
| `.import-cache/` + `import-cache.json` | import idempotency sidecar | yes | `Sources/WenshuApp/Features/Agent/Service/ImportTargets.swift` (`cacheRoot`); `Sources/WenshuApp/Features/Agent/Service/ImportService.swift` | the import service |
| `archives/` | archivist agent storage | yes | `Sources/WenshuApp/App/WenshuAppDelegate.swift` (`LiveArchivistStorage`) | the same delegate |
| `migration-backups/` | pre-migration SwiftData snapshots | yes | `Sources/WenshuApp/App/WenshuAppDelegateSwiftDataMigration.swift` (`writeMigrationBackup(wsRoot:)`) | the same |
| `books/` **at the `.ws` root** | onboarding leftover | no | nothing | `LibraryOnboardingView.createWenshuWorkspace(at:)` (= an empty root-level `books/`); `LibraryBootstrapper.ensureValidStructure()` and `LibraryMigrator.migrateIfNeeded()` delete it when empty |
| `chapters/` **at the `.ws` root** | onboarding leftover | no | nothing | same as `books/` above |
| `backups/` **at the `.ws` root** | onboarding leftover | no | nothing | `LibraryOnboardingView.createWenshuWorkspace(at:)` creates it; the backup service writes to Application Support instead (`Sources/WenshuApp/Features/Backup/Service/Backup.swift` uses `wenshu/backups` under Application Support) |
| `shelves/chapters/` | previous-generation flat layout | no | nothing (see trap 2) | an older build |

## The directory lists are hard-coded in several places

The directory lists are not derived from one source, so a change to one
copy does not reach the others. This is the maintenance hazard behind
every "the folder is missing" bug.

| List | Where it is written down | Sites |
| ---- | ------------------------ | ----- |
| reference-library layers | `LibraryBootstrapper.ensureValidStructure()` (`Sources/WenshuApp/Features/Library/Service/LibraryBootstrapper.swift`) writes the list literally; `LibraryMigrator.migrateIfNeeded()` (`Sources/WenshuApp/Features/Library/Service/LibraryMigrator.swift`) derives the same list from `ReferenceLayer.allCases` | 2 |
| standard per-book folders | `LibraryBootstrapper.ensurePerBookStructure()`; `LibraryMigrator.seedDefaultHelpDoc(in:fm:)`; `SidebarServiceMutation.createBook(input:)` (= `Sources/WenshuApp/Features/Library/View/SidebarServiceMutation.swift`) | 3 |
| `.ws`-root subdirectories | `LibraryOnboardingView.createWenshuWorkspace(at:)` (`Sources/WenshuApp/Shared/UI/LibraryRootView.swift`) | 1 |

Five sites, three lists, one source of truth that none of them reads:
`BookFolderCatalog.allBookFolders` names the per-book folders and the
layer list is `ReferenceLayer.allCases`, but no creation path derives
its directory list from either.

Two test suites pin the two lists that drifted before, and they are the
fastest way to check the layout after a change:

- `Tests/WenshuAppTests/Library/Service/ReferenceLibraryLayerLayoutTests.swift`
  (= the reference-library directories on disk must equal
  `ReferenceLayer.allCases`).
- `Tests/WenshuAppTests/Library/Service/LibraryBookFolderLayoutTests.swift`
  (= the per-book folders, and which folders must **not** be there).

### Two places where the copies already disagree

Both are worth knowing before you read the tree above as a contract.

**The catalog names 7 folders; the creators make 6.**
`Sources/WenshuApp/Features/Library/Model/BookFolderCatalog.swift`
(`allBookFolders`) lists `world`, `characters`, `outlines`, `chapters`,
`drafts`, `ideas`, `sessions`. The three on-disk creators list 6 (= the
same set without `ideas`). So `ideas/` is a catalogued folder that no
creator writes; it exists on disk only if the user or an import made it.
`BookFolderCatalogTests` pins the catalog at 7 and
`LibraryBookFolderLayoutTests` pins the disk at 6, so both numbers are
intentional.

**`entities/` is not part of the on-disk book layout.**
`Sources/WenshuApp/Features/Library/Service/FileSystemEntityStore.swift`
resolves `entities/` and `entities.json` under whatever `bookDirectory`
it is given, but the only writer,
`EntityMigration.migrateFromLegacyIfNeeded(bookDirectory:)`, has no caller
in the app. A fresh library therefore has no `entities/` folder in a
book.

## Deciding what to delete

1. **`references/` stays.** It is the canonical reference body, the
   editor writes it, and the editor finds a reference tab by the parent
   directory name.
2. **`reference-library/<layer>/<uuid>.md` stays** (= the layer copy and
   its index). Both copies are by design.
3. **`shelves/chapters/` can go.** Nothing reads it.
4. **Root-level `books/`, `chapters/`, `backups/` can go.** They are
   onboarding leftovers; the app already deletes the empty ones.
5. **Never delete `shelves/`, `reference-library/`, `references/`,
   `assets/`, `cache/`.** The app creates the missing ones on the next
   launch, but the content inside them is the user's.

## How to tell whether a document is live

The cheapest test is the **cover**. The cover key is a pure function of
the document's identity
(`Sources/WenshuApp/Features/Cover/Model/CardCoverService.swift`:
`key(forReference:)` and `key(forBookDoc:)` build it from
`WSCardCoverKind.reference` / `.bookDoc` and the document's uuid), and
the cover directory is `assets/covers/<card-key>/`
(= `CardCoverService.coversRoot` + `directory(forKey:)`).

So:

- a document with a cover was touched by the user after the cover
  feature shipped, so it is in use;
- a document with no cover, absent from every index JSON, and sitting in
  an unreachable directory is residue.

The cover record
(`Sources/WenshuApp/Features/Cover/Model/CoverRecord.swift`) also carries
`lastAttemptAt`, which dates the last cover attempt for that card (= a
cover attempt that failed still leaves a record).

Two independent signals agree with the cover test: the document's uuid
appears in no `*.json` index in the library, and no other file in the
library holds its content.

Note the coverage gap that comes with this test: a cover survives its
document. A cover directory under `assets/covers/` whose document is gone
is an orphan, and the cover does not cascade with the document's
deletion.

## What this document does not cover

- **The SwiftData store's contents.** `WenshuStore.store` holds the
  `@Model` rows (books, references, entities, todos). This file records
  the directory layout, not the schema.
- **Application Support.** The scroll memory
  (`Sources/WenshuApp/Features/Editor/Store/EditorScrollMemory.swift`)
  and the provider-key file live outside the `.ws`, under Application
  Support.
- **The build's own `Sources/` tree.** Only the on-disk `.ws` layout is
  in scope here.
