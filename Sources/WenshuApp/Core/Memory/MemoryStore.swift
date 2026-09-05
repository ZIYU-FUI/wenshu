//
//  MemoryStore.swift · Wenshu · v0.17 ticket 01 (hermes replica)
//  + SETTINGS-PERSISTENCE-001 (2026-09-05).
//

import Foundation
import SQLite3

public struct Memory: Equatable, Sendable {
    public let userId: String
    public let memoryId: String
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(userId: String, memoryId: String = UUID().uuidString, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.userId = userId
        self.memoryId = memoryId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

public actor MemoryStore {
    private let dbPtr: SQLitePtr
    private let dbPath: String

    public init(path: String? = nil) throws {
        let url: URL
        if let path = path {
            url = URL(fileURLWithPath: path)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("wenshu", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("memory.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw MemoryStoreError.openFailed(dbPath: url.path, message: SQLiteErmsg.message(ptr.db))
        }
        self.dbPtr = ptr
    }

    public func bootstrap() throws {
        try createSchema()
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS memories (
            user_id TEXT NOT NULL,
            memory_id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_memories_user_id ON memories(user_id);
        """
        try exec(sql)
    }

    public func add(userId: String, content: String) throws -> Memory {
        let now = Date()
        let memory = Memory(userId: userId, content: content, createdAt: now, updatedAt: now)
        let sql = "INSERT INTO memories (user_id, memory_id, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, memory.userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, memory.memoryId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, memory.content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, memory.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 5, memory.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw MemoryStoreError.stepFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        return memory
    }

    public func search(userId: String, query: String, limit: Int = 10) throws -> [Memory] {
        let sql = "SELECT user_id, memory_id, content, created_at, updated_at FROM memories WHERE user_id = ? AND content LIKE ? ORDER BY updated_at DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, "%\(query)%", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(limit))
        var results: [Memory] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(Memory(
                userId: textColumn(stmt, 0) ?? "",
                memoryId: textColumn(stmt, 1) ?? "",
                content: textColumn(stmt, 2) ?? "",
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            ))
        }
        return results
    }

    public func get(memoryId: String) throws -> Memory? {
        let sql = "SELECT user_id, memory_id, content, created_at, updated_at FROM memories WHERE memory_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, memoryId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Memory(
            userId: textColumn(stmt, 0) ?? "",
            memoryId: textColumn(stmt, 1) ?? "",
            content: textColumn(stmt, 2) ?? "",
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        )
    }

    public func update(memoryId: String, content: String) throws {
        let now = Date()
        let sql = "UPDATE memories SET content = ?, updated_at = ? WHERE memory_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, now.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, memoryId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw MemoryStoreError.stepFailed(message: lastErrorMessage(db: dbPtr.db))
        }
    }

    public func delete(memoryId: String) throws {
        let sql = "DELETE FROM memories WHERE memory_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, memoryId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw MemoryStoreError.stepFailed(message: lastErrorMessage(db: dbPtr.db))
        }
    }

    public func count(userId: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM memories WHERE user_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, userId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    public func listRecent(userId: String, limit: Int = 20) throws -> [Memory] {
        guard limit > 0 else { return [] }
        let sql = "SELECT user_id, memory_id, content, created_at, updated_at FROM memories WHERE user_id = ? ORDER BY updated_at DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var results: [Memory] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(Memory(
                userId: textColumn(stmt, 0) ?? "",
                memoryId: textColumn(stmt, 1) ?? "",
                content: textColumn(stmt, 2) ?? "",
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            ))
        }
        return results
    }

    @discardableResult
    public func purgeOlderThan(userId: String, retentionDays: Int) throws -> Int {
        guard retentionDays > 0 else { return 0 }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86_400.0)
        let sql = "DELETE FROM memories WHERE user_id = ? AND created_at < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw MemoryStoreError.prepareFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, userId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, cutoff.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw MemoryStoreError.stepFailed(message: lastErrorMessage(db: dbPtr.db))
        }
        return Int(sqlite3_changes(dbPtr.db))
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(dbPtr.db, sql, nil, nil, nil) != SQLITE_OK {
            throw MemoryStoreError.execFailed(message: lastErrorMessage(db: dbPtr.db))
        }
    }

    private func textColumn(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cString)
    }

    private func lastErrorMessage(db: OpaquePointer?) -> String {
        SQLiteErmsg.message(db)
    }
}

public enum MemoryStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteErmsg {
    static func message(_ db: OpaquePointer?) -> String {
        guard let db = db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}
