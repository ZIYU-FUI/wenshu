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
/// v0.23 ticket 013.003: extended with hermes-style metadata
/// (priority / assignee / started_at / completed_at / model_override).
public struct KanbanTask: Equatable, Sendable {
    public let id: String
    public var title: String
    public var status: KanbanStatus
    public let createdAt: Date
    public var updatedAt: Date
    /// v0.23 ticket 013.003: priority (0 = low, 5 = normal, 10 = urgent).
    public var priority: Int
    /// v0.23 ticket 013.003: assignee agent name (e.g. "writer", "researcher", "wenshu-conductor").
    public var assignee: String?
    /// v0.23 ticket 013.003: when task started running.
    public var startedAt: Date?
    /// v0.23 ticket 013.003: when task completed/failed.
    public var completedAt: Date?
    /// v0.23 ticket 013.003: model used for this task (e.g. "MiniMax-M3", "claude-3.7-sonnet").
    public var modelOverride: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        status: KanbanStatus = .new,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: Int = 5,
        assignee: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        modelOverride: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.priority = priority
        self.assignee = assignee
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.modelOverride = modelOverride
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

    /// Call on startup: Form
    public func bootstrap() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS kanban_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            -- v0.23 ticket 013.003: hermes parity metadata columns.
            priority INTEGER NOT NULL DEFAULT 5,
            assignee TEXT,
            started_at REAL,
            completed_at REAL,
            model_override TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_kanban_status ON kanban_tasks(status);
        """
        try exec(sql)
        // v0.23 ticket 013.003: ALTER TABLE migration for older DBs
        // (CREATE TABLE IF NOT EXISTS skips if table exists, so older DBs
        // don't get new columns. Add columns defensively if missing.)
        let alterStatements = [
            "ALTER TABLE kanban_tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 5;",
            "ALTER TABLE kanban_tasks ADD COLUMN assignee TEXT;",
            "ALTER TABLE kanban_tasks ADD COLUMN started_at REAL;",
            "ALTER TABLE kanban_tasks ADD COLUMN completed_at REAL;",
            "ALTER TABLE kanban_tasks ADD COLUMN model_override TEXT;",
        ]
        for stmt in alterStatements {
            // ALTER TABLE ADD COLUMN is idempotent only with IF NOT EXISTS (sqlite 3.35+).
            // v0.23 audit #014 fix: log failures (boss 8/23 risk-averse:
            // surface silent ALTER failures to user / developer).
            do {
                _ = try exec(stmt)
            } catch {
                NSLog("[KanbanStore] ALTER failed (expected on sqlite<3.35 or already applied): \(error)")
            }
        }
    }

    /// add: 加 1 个 task
    public func add(
        title: String,
        status: KanbanStatus = .new,
        priority: Int = 5,
        assignee: String? = nil,
        modelOverride: String? = nil
    ) throws -> KanbanTask {
        let now = Date()
        // v0.23 ticket 013.003: auto-set startedAt when status == .running.
        let startedAt: Date? = (status == .running) ? now : nil
        let task = KanbanTask(
            id: UUID().uuidString,
            title: title,
            status: status,
            createdAt: now,
            updatedAt: now,
            priority: priority,
            assignee: assignee,
            startedAt: startedAt,
            completedAt: nil,
            modelOverride: modelOverride
        )
        let sql = """
        INSERT INTO kanban_tasks
        (id, title, status, created_at, updated_at, priority, assignee, started_at, completed_at, model_override)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
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
        sqlite3_bind_int(stmt, 6, Int32(task.priority))
        if let a = task.assignee { sqlite3_bind_text(stmt, 7, a, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 7) }
        if let s = task.startedAt { sqlite3_bind_double(stmt, 8, s.timeIntervalSince1970) } else { sqlite3_bind_null(stmt, 8) }
        if let c = task.completedAt { sqlite3_bind_double(stmt, 9, c.timeIntervalSince1970) } else { sqlite3_bind_null(stmt, 9) }
        if let m = task.modelOverride { sqlite3_bind_text(stmt, 10, m, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 10) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw KanbanStoreError.stepFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        return task
    }

    /// transition: 改 status (state machine 真值)
    /// v0.23 ticket 013.003: auto-set started_at / completed_at on state transitions.
    public func transition(id: String, to newStatus: KanbanStatus) throws {
        let now = Date()
        // Auto-set timestamps:
        //   entering .running → started_at = now (if not already set)
        //   entering .done / .failed → completed_at = now
        let startedAtSet = newStatus == .running
        let completedAtSet = newStatus == .done || newStatus == .failed
        let sql: String
        if startedAtSet && completedAtSet {
            sql = "UPDATE kanban_tasks SET status = ?, updated_at = ?, started_at = COALESCE(started_at, ?), completed_at = ? WHERE id = ?;"
        } else if startedAtSet {
            sql = "UPDATE kanban_tasks SET status = ?, updated_at = ?, started_at = COALESCE(started_at, ?) WHERE id = ?;"
        } else if completedAtSet {
            sql = "UPDATE kanban_tasks SET status = ?, updated_at = ?, completed_at = ? WHERE id = ?;"
        } else {
            sql = "UPDATE kanban_tasks SET status = ?, updated_at = ? WHERE id = ?;"
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        sqlite3_bind_text(stmt, idx, newStatus.rawValue, -1, SQLITE_TRANSIENT); idx += 1
        sqlite3_bind_double(stmt, idx, now.timeIntervalSince1970); idx += 1
        if startedAtSet { sqlite3_bind_double(stmt, idx, now.timeIntervalSince1970); idx += 1 }
        if completedAtSet { sqlite3_bind_double(stmt, idx, now.timeIntervalSince1970); idx += 1 }
        sqlite3_bind_text(stmt, idx, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw KanbanStoreError.stepFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// get: 拿 1 个 task
    public func get(id: String) throws -> KanbanTask? {
        let sql = "SELECT id, title, status, created_at, updated_at, priority, assignee, started_at, completed_at, model_override FROM kanban_tasks WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw KanbanStoreError.prepareFailed(message: KanbanStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return decodeKanbanTask(stmt: stmt)
    }

    /// decodeKanbanTask: shared row → KanbanTask decoder (v0.23 ticket 013.003).
    /// Used by both get() and list() to avoid duplication.
    private func decodeKanbanTask(stmt: OpaquePointer?) -> KanbanTask {
        let id = KanbanStore.textColumn(stmt, 0) ?? ""
        let title = KanbanStore.textColumn(stmt, 1) ?? ""
        let status = KanbanStatus(rawValue: KanbanStore.textColumn(stmt, 2) ?? "new") ?? .new
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        let priority = Int(sqlite3_column_int64(stmt, 5))
        let assignee = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : KanbanStore.textColumn(stmt, 6)
        let startedAt = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        let completedAt = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
        let modelOverride = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : KanbanStore.textColumn(stmt, 9)
        return KanbanTask(
            id: id, title: title, status: status,
            createdAt: createdAt, updatedAt: updatedAt,
            priority: priority, assignee: assignee,
            startedAt: startedAt, completedAt: completedAt,
            modelOverride: modelOverride
        )
    }

    /// list: 按 status 列 tasks
    /// v0.23 ticket 013.003: returns full KanbanTask including hermes metadata
    /// (priority / assignee / started_at / completed_at / model_override).
    public func list(status: KanbanStatus? = nil) throws -> [KanbanTask] {
        let sql: String
        if let status = status {
            sql = "SELECT id, title, status, created_at, updated_at, priority, assignee, started_at, completed_at, model_override FROM kanban_tasks WHERE status = ? ORDER BY updated_at DESC;"
        } else {
            sql = "SELECT id, title, status, created_at, updated_at, priority, assignee, started_at, completed_at, model_override FROM kanban_tasks ORDER BY updated_at DESC;"
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
            results.append(decodeKanbanTask(stmt: stmt))
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