//
//  Persistence/SQLiteConstants.swift · Wenshu · v0.72 SwiftData migration Phase 5
//
//  v0.72 Q99 dual-axis LOW fix: consolidated the duplicated
//  `private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)`
//  (= previously copy-pasted into 4+ files). Per Phase 5 outcome:
//  - All 7 of the planned chat/kanban/toDo/memory/bookmark/workspace
//    stores WERE deleted (= Phase 5 tickets 6/7/8/9 deleted KanbanStore
//    + TodoStore + MemoryStore + LinkIndex; = ticket 10a deleted
//    ChatSessionStore; = ticket 10b deleted BookmarkStore +
//    WenshuWorkspace).
//  - Plus 2 additional sqlite3 files outside this header's original
//    list that still use SQLITE_TRANSIENT: HermesKanbanDB,
//    FullTextSearch (= total = 2 still-alive files post-Phase 5).
//
//  The system SQLite3 module does not expose SQLITE_TRANSIENT as a public
//  constant (= it's defined as `(void(*)(void*))-1` in sqlite3.c). The
//  unsafeBitCast pattern (= -1 → sqlite3_destructor_type.self) is the
//  canonical Swift workaround.
//
//  Still-alive sqlite3 users (= 2 files post-Phase 5): HermesKanbanDB,
//  FullTextSearch. These are HELPER indices (= FullTextSearch for
//  docs_fts SQLite FTS5 helper; = HermesKanbanDB is a separate Kanban
//  SQLite store scoped to the kanban subsystem), not chat/kanban/toDo/
//  memory/bookmark/workspace persistence.
//  The 7 deleted files (= KanbanStore + TodoStore + MemoryStore +
//  LinkIndex + ChatSessionStore + BookmarkStore + WenshuWorkspace) no
//  longer import this helper.

import Foundation
import SQLite3

/// SQLITE_TRANSIENT sentinel (= tells SQLite to copy the bound string
/// before the binding returns). Equivalent to the C constant SQLITE_TRANSIENT.
public let SQLITE_TRANSIENT: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
