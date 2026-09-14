# v0.79 SQLite3 Raw-Store Audit · Spec

**Branch**: `wt/v0.79-sqlite3-audit-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146

## Context

After Phase 5 of the v0.72 SwiftData migration (= AGENTS.md §11.4.2),
**7 of 7 planned sqlite3 stores are deleted** (= KanbanStore + TodoStore +
MemoryStore + LinkIndex + ChatSessionStore + BookmarkStore + WenshuWorkspace).
But **2 sqlite3 files still exist** (= per `SQLiteConstants.swift` header
itself):

1. `Sources/WenshuApp/Core/Kanban/HermesKanbanDB.swift` (= hermes-port
   Kanban subsystem using raw sqlite3)
2. `Sources/WenshuApp/Core/Search/FullTextSearch.swift` (= FTS5 search index)

Plus the 2 helper files:
3. `Sources/WenshuApp/Persistence/SQLiteConstants.swift` (= shared
   SQLITE_TRANSIENT constant for both files above)
4. `Sources/WenshuApp/Persistence/WSMigrationPerStore.swift` (= Phase 4
   legacy importer; = reads raw sqlite3 files from before the SwiftData
   migration; = dead after first launch with new app)

## Per-file decision

### `HermesKanbanDB.swift` (= 14,347 LOC 1:1 hermes port)

- **Production callers in current tree**: zero (= `rg -l "HermesKanbanDB\(" Sources` returns only the file itself)
- **Hermes-port value**: real (= hermes uses raw sqlite3 for kanban)
- **SwiftData replacement**: not needed (= `WSKanbanRepository.shared` covers user-facing kanban)
- **Decision**: keep file, mark as documented future work (= do NOT delete per Q57)

### `FullTextSearch.swift` (= FTS5 search index)

- **Production callers**: yes (= cmd-F shortcut + search panel reads from this)
- **Hermes-port value**: none (= FTS5 is Apple HIG canonical, not hermes)
- **SwiftData replacement**: out of scope (= search is its own surface)
- **Decision**: keep file as-is (= this is the only raw sqlite3 file with real production users)

### `SQLiteConstants.swift` (= shared helper)

- **Used by**: both files above (= SQLITE_TRANSIENT workaround)
- **Decision**: keep (= canonical Swift workaround for missing sqlite3 C constant)

### `WSMigrationPerStore.swift` (= Phase 4 legacy importer)

- **Used by**: only the migration runner (= = one-time at first launch with new app)
- **Decision**: keep (= per AGENTS.md §11.4.2, = dead after first launch but
  preserved for the migration path)

## Per-file deferred header (= this ticket)

Add audit headers to:
1. `HermesKanbanDB.swift` (= documents the zero-caller state + future-work guidance)
2. `FullTextSearch.swift` (= documents the real production use + non-migration status)

(`SQLiteConstants.swift` and `WSMigrationPerStore.swift` already document their
status in their own headers.)

## Cross-references

- `AGENTS.md §11.4.2` (= Phase 5 spec; = "could be future cleanup if user wants pure SwiftData")
- `Sources/WenshuApp/Persistence/SQLiteConstants.swift` (= header lists the 2 still-alive sqlite3 files)

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change)
- [ ] Both deferred headers = present + link to this spec
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope (= explicit)

- Deleting any of the 2 sqlite3 files (= NEVER per Q57)
- Migrating `FullTextSearch` to SwiftData (= out of scope; = needs separate spec)
- Migrating `HermesKanbanDB` to SwiftData (= out of scope; = no caller anyway)
- Adding new sqlite3 consumers (= spec violation)