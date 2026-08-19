//
//  MemoryStore.swift · Wenshu · v0.17 ticket 01 (hermes replica)
//
//  本地 SQLite 长期记忆 (替代 hermes mem0 云服务).
//  老板 2026-08-19 拍 "底层依赖复刻" — 不依赖 hermes, wenshu 自己能 search/add memory.
//
//  接口对齐 mem0 platform 模式真值: add / search / get / update / delete
//  SQLite 真值: Apple Foundation 内置 SQLite3, schema = user_id / memory_id / content / created_at / updated_at
//

import Foundation
import SQLite3

/// 1 条记忆 = 1 row, schema = user_id 隔离多用户 + memory_id UUID + content TEXT + 时间戳
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

/// SQLite 透明指针 wrap (SQLite C API 原生 sqlite3*, Swift ARC 友好)
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

/// MemoryStore: SQLite-backed 长期记忆, 线程安全 actor, 接口对齐 mem0 platform 模式真值
public actor MemoryStore {
    private let dbPtr: SQLitePtr
    private let dbPath: String

    /// 初始化 (内存或磁盘) — Apple HIG 真值: 默认磁盘 = Library/Application Support/wenshu/memory.db
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

    /// 启动时调用: 建表 (actor 初始化后才能调 self)
    public func bootstrap() throws {
        try createSchema()
    }

    /// 创建 memories 表 (if not exists)
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

    /// add: 加 1 条记忆 (mem0 platform add 接口对齐)
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

    /// search: 按 query 模糊匹配 (mem0 platform search 接口对齐, 简化版 LIKE %query%)
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
            let memory = Memory(
                userId: textColumn(stmt, 0) ?? "",
                memoryId: textColumn(stmt, 1) ?? "",
                content: textColumn(stmt, 2) ?? "",
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            )
            results.append(memory)
        }
        return results
    }

    /// get: 拿 1 条 (mem0 get 接口对齐)
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

    /// update: 改 content (mem0 update 接口对齐)
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

    /// delete: 删 1 条 (mem0 delete 接口对齐)
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

    /// count: 拿 user 记忆条数 (测试用)
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

/// MemoryStore 错误
public enum MemoryStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

/// SQLite3 C API 桥接常量 (Apple 内置 libsqlite3)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite3 错误信息 helper (file-level, 不依赖 self, 用于 actor init)
private enum SQLiteErmsg {
    static func message(_ db: OpaquePointer?) -> String {
        guard let db = db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}