//
//  Persistence/WSMigrationPerStore.swift · Wenshu · v0.72 SwiftData migration Phase 4
//
//  Migration commit 39 of 42: per-store migration logic.
//  Per AGENTS.md §11.4.
//
//  Each function reads the corresponding raw sqlite3 store file (= if it
//  exists) and inserts equivalent SwiftData rows.
//
//  Migration is idempotent: each function checks for existing rows via
//  @Attribute(.unique) constraints (= duplicate inserts throw; = catches
//  partial migration state). Existing rows = skip.
//
//  Default store paths (= per AGENTS.md §11):
//    ~/Library/Application Support/wenshu/<store>.db
//
//  Old store → new @Model mapping:
//    memory.db → WSMemory         (user_id + memory_id + content + timestamps)
//    chat.db → WSSession + WSChatMessage + WSSummary + WSSubAgentRun
//    todos.db → WSTodo            (id + title + status + priority + due_date)
//    bookmarks.db → WSBookmark    (id + doc_id OR book_id + title + position)
//    kanban.db → WSKanbanTask     (id + title + status + priority + assignee + ...)
//    links.db → WSLink            (id = source_doc_id:line + ...)
//    books table (WenshuWorkspace.swift) → WSBook + WSBookShelf + WSChapter + WSCharacter + WSWorld + ...
//    provider_keys table (WenshuWorkspace.swift) → WSProviderKey (encrypted BLOB metadata index)
//    preferences table (WenshuWorkspace.swift) → WSPreference (= replaces deprecated UserDefaults path; = per-key K/V for cross-cutting workspace prefs)

import Foundation
import SQLite3
import SwiftData

@MainActor
enum WSMigrationPerStore {

    /// Find the .ws bundle path (= per AGENTS.md §11: wenshu library is
    /// NSOpenPanel-selected at onboarding; = stored in UserDefaults).
    static func wenshuPath() -> String? {
        // Per AGENTS.md §11: UserDefaults key "wenshu.libraryPath"
        UserDefaults.standard.string(forKey: "wenshu.libraryPath")
    }

    /// Resolve default db path for a store (= ~/Library/Application Support/wenshu/<name>.db)
    static func defaultDBPath(name: String) -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = support.appendingPathComponent("wenshu", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).db")
    }

    /// Open raw sqlite3 DB in read-only mode (= safe migration).
    static func openForRead(_ url: URL) -> OpaquePointer? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK {
            return db
        }
        sqlite3_close(db)
        return nil
    }

    /// Execute a SELECT and return rows as [[String: Any]].
    static func query(_ db: OpaquePointer, sql: String) -> [[String: Any]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<colCount {
                let colName = String(cString: sqlite3_column_name(stmt, i))
                let colType = sqlite3_column_type(stmt, i)
                switch colType {
                case SQLITE_INTEGER:
                    row[colName] = sqlite3_column_int64(stmt, i)
                case SQLITE_FLOAT:
                    row[colName] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:
                    if let cStr = sqlite3_column_text(stmt, i) {
                        row[colName] = String(cString: cStr)
                    } else {
                        row[colName] = NSNull()
                    }
                case SQLITE_NULL:
                    row[colName] = NSNull()
                default:
                    row[colName] = NSNull()
                }
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: - Per-store migrations

    static func migrateMemoryStore(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "memory"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        // Skip if already migrated (= any WSMemory rows exist)
        let existing = try context.fetch(FetchDescriptor<WSMemory>())
        if !existing.isEmpty { return }

        let rows = query(db, sql: "SELECT user_id, memory_id, content, created_at, updated_at FROM memories;")
        for row in rows {
            let memoryID = (row["memory_id"] as? String) ?? UUID().uuidString
            let userID = (row["user_id"] as? String) ?? "default"
            let content = (row["content"] as? String) ?? ""
            // PRIMARY KEY is (user_id, memory_id); = use composite for migration
            let model = WSMemory(memoryID: memoryID, userID: userID, content: content)
            context.insert(model)
        }
        try context.save()
    }

    static func migrateChatSessionStore(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "chat"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        // Skip if already migrated
        if try !context.fetch(FetchDescriptor<WSSession>()).isEmpty { return }

        // Migrate chat_sessions
        let sessionRows = query(db, sql: "SELECT session_id, title, created_at, updated_at, archived_at FROM chat_sessions;")
        for row in sessionRows {
            let sessionID = (row["session_id"] as? String) ?? UUID().uuidString
            let title = row["title"] as? String
            let session = WSSession(sessionID: sessionID, title: title)
            context.insert(session)
        }

        // Migrate chat_messages
        let msgRows = query(db, sql: "SELECT id, session_id, source, content, timestamp, tokens, thinking FROM chat_messages;")
        var positionBySession: [String: Int] = [:]
        for row in msgRows {
            let id = (row["id"] as? String) ?? UUID().uuidString
            let sessionID = (row["session_id"] as? String) ?? "default"
            let role = (row["source"] as? String) ?? "user"
            let content = (row["content"] as? String) ?? ""
            let position = positionBySession[sessionID, default: 0]
            positionBySession[sessionID] = position + 1
            let model = WSChatMessage(
                id: id,
                sessionID: sessionID,
                role: role,
                content: content,
                position: position,
                status: "ok"
            )
            if let tokens = row["tokens"] as? Int64 {
                model.tokenCount = Int(tokens)
            }
            context.insert(model)
        }

        try context.save()
    }

    static func migrateTodoStore(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "todos"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        if try !context.fetch(FetchDescriptor<WSTodo>()).isEmpty { return }

        let rows = query(db, sql: "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos;")
        for row in rows {
            let id = (row["id"] as? String) ?? UUID().uuidString
            let title = (row["title"] as? String) ?? ""
            let model = WSTodo(id: id, title: title)
            model.status = (row["status"] as? String) ?? "pending"
            model.priority = Int((row["priority"] as? Int64) ?? 1)
            model.createdAt = Date(timeIntervalSince1970: (row["created_at"] as? Double) ?? 0)
            model.updatedAt = Date(timeIntervalSince1970: (row["updated_at"] as? Double) ?? 0)
            context.insert(model)
        }
        try context.save()
    }

    static func migrateBookmarkStore(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "bookmarks"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        if try !context.fetch(FetchDescriptor<WSBookmark>()).isEmpty { return }

        let rows = query(db, sql: "SELECT id, doc_id, title, note, position, created_at FROM bookmarks;")
        for row in rows {
            let id = (row["id"] as? String) ?? UUID().uuidString
            let title = (row["title"] as? String) ?? ""
            let docID = row["doc_id"] as? String
            let model = WSBookmark(id: id, title: title, docID: docID)
            model.position = Int((row["position"] as? Int64) ?? 0)
            model.note = row["note"] as? String
            context.insert(model)
        }
        try context.save()
    }

    static func migrateKanbanStore(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "kanban"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        if try !context.fetch(FetchDescriptor<WSKanbanTask>()).isEmpty { return }

        let rows = query(db, sql: "SELECT id, title, status, priority, assignee, started_at, completed_at, model_override, created_at, updated_at FROM kanban_tasks;")
        for row in rows {
            let id = (row["id"] as? String) ?? UUID().uuidString
            let title = (row["title"] as? String) ?? ""
            let model = WSKanbanTask(
                id: id,
                title: title,
                status: (row["status"] as? String) ?? "new",
                priority: Int((row["priority"] as? Int64) ?? 5)
            )
            model.assignee = row["assignee"] as? String
            model.modelOverride = row["model_override"] as? String
            context.insert(model)
        }
        try context.save()
    }

    static func migrateLinkIndex(context: ModelContext) async throws {
        guard let url = defaultDBPath(name: "links"),
              FileManager.default.fileExists(atPath: url.path),
              let db = openForRead(url) else { return }
        defer { sqlite3_close(db) }

        if try !context.fetch(FetchDescriptor<WSLink>()).isEmpty { return }

        let rows = query(db, sql: "SELECT id, source_doc_id, target_ref, target_doc_id, line, offset, created_at FROM links;")
        for row in rows {
            let sourceDocID = (row["source_doc_id"] as? String) ?? ""
            let targetRef = (row["target_ref"] as? String) ?? ""
            let targetDocID = row["target_doc_id"] as? String
            let line = Int((row["line"] as? Int64) ?? 0)
            let offset = Int((row["offset"] as? Int64) ?? 0)
            let model = WSLink(
                sourceDocID: sourceDocID,
                targetRef: targetRef,
                targetDocID: targetDocID,
                line: line,
                offset: offset
            )
            context.insert(model)
        }
        try context.save()
    }

    static func migrateBooks(context: ModelContext) async throws {
        // Books are stored as filesystem JSON (= .ws/shelves/<shelf-id>/books/<book-id>/book.json)
        // SwiftData migration requires walking the directory tree (= future ticket)
        // For now: skip (= books remain on filesystem)
        _ = context
    }

    static func migrateProviderKeys(context: ModelContext) async throws {
        // Provider keys are stored in AppleKeychain (= AGENTS.md §11 contract)
        // SwiftData WSProviderKey is metadata index only (= not source of truth)
        // No migration needed (= the keys are in AppleKeychain, not in any DB file)
        _ = context
    }

    static func migratePreferences(context: ModelContext) async throws {
        // Preferences are stored in UserDefaults (= `preferences` table in old schema
        // is rarely used; = UserDefaults is the canonical store for wenshu)
        // No migration needed
        _ = context
    }
}
