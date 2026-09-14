//
//  Persistence/SQLiteConstants.swift · Wenshu · v0.72 SwiftData migration Phase 5
//
//  v0.72 Q99 dual-axis LOW fix: consolidated the duplicated
//  `private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)`
//  (= previously copy-pasted into 4+ files). Per Phase 5 outcome:
//  - 4 of these 6 stores WERE deleted (= Phase 5 tickets 6/7/8/9
//    deleted KanbanStore + TodoStore + MemoryStore + LinkIndex).
//  - 2 stores STILL exist (= per AGENTS.md §11.4.2 HONEST SCOPE GAP;
//    = future cleanup ticket 10): ChatSessionStore only
//  - Plus 3 additional sqlite3 files outside this header's original
//    list that also use SQLITE_TRANSIENT: HermesKanbanDB,
//    FullTextSearch, WenshuWorkspace (= total = 5 still-alive files).
//
//  The system SQLite3 module does not expose SQLITE_TRANSIENT as a public
//  constant (= it's defined as `(void(*)(void*))-1` in sqlite3.c). The
//  unsafeBitCast pattern (= -1 → sqlite3_destructor_type.self) is the
//  canonical Swift workaround.
//
//  Still-alive sqlite3 users (= 5 files post-Phase 5): ChatSessionStore,
//  HermesKanbanDB, FullTextSearch, WenshuWorkspace.
//  The 4 deleted files (= KanbanStore + TodoStore + MemoryStore +
//  LinkIndex) no longer import this helper.

import Foundation
import SQLite3

/// SQLITE_TRANSIENT sentinel (= tells SQLite to copy the bound string
/// before the binding returns). Equivalent to the C constant SQLITE_TRANSIENT.
public let SQLITE_TRANSIENT: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
