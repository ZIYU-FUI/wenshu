//
//  Persistence/SQLiteConstants.swift · Wenshu · v0.72 SwiftData migration Phase 5
//
//  v0.72 Q99 dual-axis LOW fix: consolidated the duplicated
//  `private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)`
//  (= previously copy-pasted into 4+ files: MemoryStore / ChatSessionStore /
//  TodoStore / BookmarkStore / KanbanStore / LinkIndex).
//
//  The system SQLite3 module does not expose SQLITE_TRANSIENT as a public
//  constant (= it's defined as `(void(*)(void*))-1` in sqlite3.c). The
//  unsafeBitCast pattern (= -1 → sqlite3_destructor_type.self) is the
//  canonical Swift workaround.
//
//  All pre-v0.72 sqlite store files use this helper now.
//  (= Phase 5 file deletion will remove these files entirely.)

import Foundation
import SQLite3

/// SQLITE_TRANSIENT sentinel (= tells SQLite to copy the bound string
/// before the binding returns). Equivalent to the C constant SQLITE_TRANSIENT.
public let SQLITE_TRANSIENT: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
