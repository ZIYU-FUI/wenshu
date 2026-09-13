
# SwiftData Migration Spec (Apple-recommended database path)

## 1. Scope

Replace all 10 raw sqlite3 stores with SwiftData @Model classes + ModelContainer.
Drop WenshuWorkspace.swift's hand-rolled "13 tables in one file" pattern —
adopt the Apple ModelContainer pattern (one container, many @Model classes).

### Files to REMOVE (after migration verified)
- Sources/WenshuApp/Core/Memory/MemoryStore.swift
- Sources/WenshuApp/Core/Chat/ChatSessionStore.swift
- Sources/WenshuApp/Core/Todo/TodoStore.swift
- Sources/WenshuApp/Core/Bookmarks/BookmarkStore.swift
- Sources/WenshuApp/Core/Kanban/KanbanStore.swift        (Hermes partial port)
- Sources/WenshuApp/Core/Kanban/HermesKanbanDB.swift    (Hermes verbatim port)
- Sources/WenshuApp/Core/LinkGraph/LinkIndex.swift
- Sources/WenshuApp/Core/Workspace/WenshuWorkspace.swift (the mega-store)
- Sources/WenshuApp/Core/Search/FullTextSearch.swift      (FTS5 — see §5)

### Files to ADD
- Sources/WenshuApp/Persistence/Models.swift              (all @Model classes in one file)
- Sources/WenshuApp/Persistence/Container.swift           (ModelContainer setup)
- Sources/WenshuApp/Persistence/MigrationPlan.swift      (SwiftData SchemaMigrationPlan)
- Sources/WenshuApp/Persistence/Repositories/MemoryRepository.swift
- Sources/WenshuApp/Persistence/Repositories/ChatRepository.swift
- Sources/WenshuApp/Persistence/Repositories/TodoRepository.swift
- Sources/WenshuApp/Persistence/Repositories/BookmarkRepository.swift
- Sources/WenshuApp/Persistence/Repositories/KanbanRepository.swift
- Sources/WenshuApp/Persistence/Repositories/WorkspaceRepository.swift
- Sources/WenshuApp/Persistence/Repositories/LinkRepository.swift
- Sources/WenshuApp/Persistence/Repositories/ProviderKeyRepository.swift
- Sources/WenshuApp/Persistence/Repositories/PreferenceRepository.swift

## 2. @Model classes (= 1:1 with existing tables)

### Tier-1: simple (= no relationships)
- WSMemory
- WSBookmark
- WSTodo
- WSLink
- WSSkill
- WSPreference

### Tier-2: with relationships
- WSChatMessage (→ WSSession)
- WSSession (1↔N WSChatMessage, 1↔1 WSSummary, 1↔N WSArchive, 1↔N WSSubAgentRun)
- WSSummary (→ WSSession)
- WSArchive (→ WSSession)
- WSSubAgentRun (→ WSSession)
- WSKanbanTask (→ WSBoard)
- WSBoard (1↔N WSKanbanTask)
- WSTaskComment (→ WSKanbanTask)
- WSTaskEvent (→ WSKanbanTask)
- WSTaskLink (→ WSKanbanTask ↔ WSKanbanTask)
- WSBook (1↔N WSOutlineEntry, 1↔N WSBookmark)
- WSOutlineEntry (→ WSBook, optional → WSOutlineEntry parent)
- WSAttachment (polymorphic via parent_table + parent_id)
- WSProviderKey
- WSManifest

### Encrypted BLOB (provider_keys.encrypted_key)
SwiftData supports `Data` natively (= mapped to BLOB).
Apple Keychain remains the right home for crypto material — but the
BLOB stays in SQLite (= Apple-recommended pattern for non-secret
data; = see AGENTS.md §11 "API keys via AppleKeychain NEVER plaintext SQLite"
is ALREADY met because we encrypt before writing).

## 3. Persistence stack

```swift
// Persistence/Container.swift
@MainActor
final class WenshuPersistence {
    static let shared: WenshuPersistence = .init()
    let container: ModelContainer

    private init() {
        let schema = Schema([
            WSMemory.self,
            WSBookmark.self,
            WSTodo.self,
            WSLink.self,
            WSSkill.self,
            WSPreference.self,
            WSChatMessage.self,
            WSSession.self,
            WSSummary.self,
            WSArchive.self,
            WSSubAgentRun.self,
            WSKanbanTask.self,
            WSBoard.self,
            WSTaskComment.self,
            WSTaskEvent.self,
            WSTaskLink.self,
            WSBook.self,
            WSOutlineEntry.self,
            WSAttachment.self,
            WSProviderKey.self,
            WSManifest.self,
        ])
        let config = ModelConfiguration("Wenshu", schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Wenshu ModelContainer init failed: \(error)")
        }
    }
}
```

## 4. Migration plan

### Phase 1: Schema creation
- All @Model classes defined with `var` properties (= migratable)
- ModelContainer reads existing SQLite DBs on first launch
- SwiftData creates a fresh store on macOS 27 Tahoe (= the Wenshu.wenshu_store URL)

### Phase 2: Data migration (one-time)
- On first launch with new container:
  1. Read all rows from existing sqlite3_* DBs
  2. Insert equivalent @Model instances into the new container
  3. Mark migration complete (= write WSManifest.migratedFromRawSqliteAt = now)
- Existing sqlite3 DBs kept as backup until next major version (= AGENTS.md §11.3 "wenshu-side wins" pattern)

### Phase 3: Future migrations
- SwiftData SchemaMigrationPlan with versionedSchema
- v2.swiftDataSchema (when schema needs to change)
- Apple ships built-in lightweight migration (= no manual SQL)

## 5. FTS5 search (= the one non-SwiftData piece)

Apple-recommended for full-text search on macOS:
- NSPredicate + NSFetchedResultsController (= built-in)
- NSPredicate supports CONTAINS[cd] / BEGINSWITH for basic search
- For typo-tolerant search: needs custom ranking

Plan:
- WSLibrarySearch via @Query + NSPredicate `CONTAINS[cd]`
- For typo tolerance (= current FTS5 behavior): use Apple's `NaturalLanguage` framework
  (= NLTokenizer for stemming) as a Phase-2 enhancement

If boss vetoes dropping FTS5 parity (= hermes verbatim port), keep FullTextSearch.swift
alongside SwiftData (= one raw sqlite3 DB for FTS5 indexes, one SwiftData for everything else).
= hybrid approach, but document WHY in the spec.

## 6. Estimated effort

| Phase | Work | Commits |
|---|---|---|
| Phase 1 | Define 21 @Model classes + ModelContainer | 5 |
| Phase 2 | Write 9 repositories (= replace existing Actor APIs) | 12 |
| Phase 3 | Update 30+ caller sites (ToolRegistry / Tool outputs / ViewModels) | 15 |
| Phase 4 | One-time data migration from sqlite3_* to SwiftData | 3 |
| Phase 5 | Remove old raw sqlite3 stores | 5 |
| Phase 6 | Update CLAUDE.md / AGENTS.md / CONTEXT.md | 2 |
| **Total** | | **~42 commits** (~3-4 weeks of focused work) |

## 7. Risk

| Risk | Mitigation |
|---|---|
| FTS5 feature regression (= dropped) | Phase 2 NaturalLanguage fallback, OR keep hybrid |
| Migration corrupts existing user data | One-shot migration writes both old + new; verify with parity tests |
| SwiftData on macOS 14+ (= boss's macOS 27 is fine) | Document minimum macOS = 14 |
| Schema changes harder than raw SQL later | Apple ships versionedSchema — embrace it from day 1 |
| 30+ call sites need updating | Mechanical refactor with grep-friendly @Observable @Model access |
