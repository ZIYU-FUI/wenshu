# #8/#9 follow-up ticket

## Status

- **#9 done** (3 commits): `8936ba4a7` `0ea46ed8e` `9a074ee23`
  - WSLayoutTreeState @Model + 4 @Model classes (= 26 entity types total)
  - LayoutTreeRepository bridges Codable <-> SwiftData
  - LayoutTreeStore rewires init to accept optional ModelContainer
- **#8 done** (1 commit): `92074c54d` FileSystemChapterStore
  - WSChapter @Model gained `summary` + `body` fields
  - FileSystemChapterStore SwiftData-backed with FileSystem fallback
- **#8 #9 remaining** (this ticket)

## Remaining #8 stores (4 left)

Per boss 2026-10-05 OOB '做 8 和 9', each FileSystem*Store needs to
migrate to SwiftData. FileSystemChapterStore (commit `92074c54d`)
established the pattern; the remaining 4 stores need the same
treatment. Each is one commit. Estimated 1-2 hours each.

### Remaining stores

| Store | LOC | Caller count | Status |
|---|---|---|---|
| FileSystemChapterStore | 242 | 2 | ✅ `92074c54d` |
| FileSystemReferenceStore | 636 | 5 | TODO (= 5 callers need updating + SwiftData migration of Reference struct with body, source, url, tags, characterRefIDs, worldRefIDs, bookRefIDs fields) |
| FileSystemEntityStore | ? | ? | TODO |
| FileSystemOutlineStore | ? | ? | TODO |
| FileSystemLibraryStore | ? | ? | TODO |

### Pattern (from FileSystemChapterStore)

1. Add a `<TypeName>.swift` in `Sources/WenshuApp/Persistence/`
   declaring the `@Model` class with all fields (= inline the
   `body` field that was a separate .md file)
2. Register in `Persistence/Container.swift:65` schema list
3. Add `modelContainer: ModelContainer? = nil` parameter to the
   store struct's init (= preserves FileSystem fallback path)
4. Add `nonisolated static func` fallback methods that callers
   use when no ModelContainer is wired (= actor callers can't
   reach MainActor; = they call the static helpers directly)
5. Mark the protocol `@MainActor` (= SwiftData enforces this)

### Caller pattern

Each FileSystem*Store caller instantiates the struct with only
`referenceLibraryRoot` (or equivalent). After the migration the
caller pattern becomes:

```swift
// Before (still works as fallback):
let store = FileSystemReferenceStore(referenceLibraryRoot: url)

// After (SwiftData path):
let store = FileSystemReferenceStore(
    referenceLibraryRoot: url,
    modelContainer: WSPersistenceContainer.shared
)
```

## Remaining #9 work

### Commit 4: delete LayoutTreeStore legacy UserDefaults path

LayoutTreeStore has 0 callers instantiating it (= v2 NavigationSplitView
rewrite disconnected it from the active renderer). The struct is
still referenced by LayoutPicker / LayoutEditBar / ZoneEditor / PaneView
/ TabContentDispatcher (= dev tool UIs), but the store itself is dead
code. Two paths:

A. **Delete LayoutTreeStore + LayoutTreeRepository** (= removes 745+320
   lines of dead code). Risk: dev tools might use store properties.
B. **Keep LayoutTreeStore** for backward compat (= accepted as dev tool
   surface; = no caller to migrate).

Recommend (A) — confirm with PM first. Per boss 'no users, no forward-
compat' = clean cut is canonical.

### Commit 5: caller migration

Originally scoped to migrate LayoutPicker / LayoutEditBar / ZoneEditor /
PaneView / TabContentDispatcher to use SwiftData @Query instead of the
Codable struct. Per boss 'no users' + (A) above deletes the struct = the
callers must already have been migrated when v2 NavigationSplitView
was rewritten (= they read layout state from AppState instead). 0
actual caller migration needed if (A) is chosen.

## Work estimate

- #8 commit 2 (FileSystemReferenceStore): 2-3 hours
- #8 commit 3 (FileSystemEntityStore): 1-2 hours
- #8 commit 4 (FileSystemOutlineStore): 1-2 hours
- #8 commit 5 (FileSystemLibraryStore): 1 hour
- #9 commit 4 (LayoutTreeStore cleanup): 30 minutes

Total: ~7-9 hours of work = 1-2 sessions.

## Commit conventions

Per AGENTS.md §11:
- Commit body in English (= no boss/OOB/Q-numbers/version-narrative)
- Author `hermes <hermes@local>`
- Build pass + smoke test 25+ seconds 0 fatal per commit
- `1 RULE 1 commit` (= one logical change per commit)

## File paths (canonical)

- wenshu main: `/Volumes/ANAN/Engineering/wenshu`
- WSChapter @Model: `Sources/WenshuApp/Persistence/WSChapter.swift`
- FileSystemChapterStore: `Sources/WenshuApp/Storage/FileSystemChapterStore.swift`
- Container schema: `Sources/WenshuApp/Persistence/Container.swift:65`
- WSLayoutTreeState @Model: `Sources/WenshuApp/Persistence/WSLayoutTreeState.swift`
- LayoutTreeStore (legacy): `Sources/WenshuApp/State/LayoutTreeStore.swift`
- LayoutTreeRepository: `Sources/WenshuApp/State/LayoutTreeRepository.swift`
