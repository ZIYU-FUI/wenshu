//
//  KanbanStore.swift · Wenshu · v0.18 ticket 05 (hermes replica)
//
//  本地 Kanban (复刻 hermes kanban_db.py 真值简化版).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现".
//
//  真值: hermes kanban DB schema = tasks / task_links / task_comments / task_events 4 表.
//  简化版: 1 tasks 表 + 6 status + SQLite + actor 线程安全.
//  Apple HIG 真值: SQLite + actor + Sendable.
//

import Foundation
import SQLite3

/// Kanban 任务状态真值 (hermes kanban state machine: new → triage → ready → running → blocked → review → done)
public enum KanbanStatus: String, Codable, Sendable, CaseIterable {
    case new
    case triage
    case ready
    case running
    case blocked
    case review
    case done
    case failed  // wenshu 额外 +1 状态 (hermes 失败 → blocked, wenshu 显式 failed)
}

/// Kanban 任务真值
public struct KanbanTask: Equatable, Sendable {
    public let id: String
    public var title: String
    public var status: KanbanStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, status: KanbanStatus = .new, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// SQLite 透明指针 wrap
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

/// KanbanStore: SQLite-backed kanban (简化版, 单表 + 6 状态)
public actor KanbanStore {
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
            url = dir.appendingPathComponent("kanban.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw KanbanStoreError.openFailed(dbPath: url.path, message: KanbanStore.sqliteErmsg(ptr.db))
        }
        self.dbPtr = ptr
    }

    /// 启动时调用: 建表
    public func bootstrap() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS kanban_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_kanban_status ON kanban_tasks(status);
        """
        try exec(sql)
    }

    /// add: 加 1 个 task
    public func add(title: String, status: KanbanStatus = .new) throws -> KanbanTask {
        let now = Date()
        let task = KanbanTask(id: UUID().uuidString, title: title, status: status, createdAt: now, updatedAt: now)
        let sql = "INSERT INTO kanban_tasks (id, title, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, task.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, task.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, task.status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, task.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 5, task.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw KanbanStoreError.stepFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        return task
    }

    /// transition: 改 status (state machine 真值)
    public func transition(id: String, to newStatus: KanbanStatus) throws {
        let now = Date()
        let sql = "UPDATE kanban_tasks SET status = ?, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, newStatus.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, now.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw KanbanStoreError.stepFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// get: 拿 1 个 task
    public func get(id: String) throws -> KanbanTask? {
        let sql = "SELECT id, title, status, created_at, updated_at FROM kanban_tasks WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return KanbanTask(
            id: KanbanStore.textColumn(stmt, 0) ?? "",
            title: KanbanStore.textColumn(stmt, 1) ?? "",
            status: KanbanStatus(rawValue: KanbanStore.textColumn(stmt, 2) ?? "new") ?? .new,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        )
    }

    /// list: 按 status 列 tasks
    public func list(status: KanbanStatus? = nil) throws -> [KanbanTask] {
        let sql: String
        if let status = status {
            sql = "SELECT id, title, status, created_at, updated_at FROM kanban_tasks WHERE status = ? ORDER BY updated_at DESC;"
        } else {
            sql = "SELECT id, title, status, created_at, updated_at FROM kanban_tasks ORDER BY updated_at DESC;"
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        if let status = status {
            sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        }
        var results: [KanbanTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(KanbanTask(
                id: KanbanStore.textColumn(stmt, 0) ?? "",
                title: KanbanStore.textColumn(stmt, 1) ?? "",
                status: KanbanStatus(rawValue: KanbanStore.textColumn(stmt, 2) ?? "new") ?? .new,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            ))
        }
        return results
    }

    /// delete: 删 1 个
    public func delete(id: String) throws {
        let sql = "DELETE FROM kanban_tasks WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw KanbanStoreError.stepFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// count: 拿 user 任务数 (按 status 选)
    public func count(status: KanbanStatus? = nil) throws -> Int {
        let sql: String
        if status != nil {
            sql = "SELECT COUNT(*) FROM kanban_tasks WHERE status = ?;"
        } else {
            sql = "SELECT COUNT(*) FROM kanban_tasks;"
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        if let status = status {
            sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(dbPtr.db, sql, nil, nil, nil) != SQLITE_OK {
            throw KanbanStoreError.execFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
    }

    private static func textColumn(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cString)
    }

    fileprivate static func sqliteErmsg(_ db: OpaquePointer?) -> String {
        guard let db = db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}

/// KanbanStore 错误
public enum KanbanStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

/// SQLite3 C API 桥接常量 (Apple 内置 libsqlite3)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)