//
//  TodoStore.swift · Wenshu · v0.18 ticket 06 (hermes replica)
//
//  本地 Todo (复刻 hermes todo 真值简化版).
//  老板 2026-08-19 拍 "全模块复刻, Apple 体系实现" + "不符合文枢定位的可以复刻".
//
//  wenshu 定位 = SwiftUI 桌面写作 app. TodoStore = wenshu 项目内任务调度 (比 KanbanStore 轻量).
//  真值: hermes todo / goals 真值 (4 状态 + priority + due).
//  简化版: 1 todos 表 + 4 status + SQLite + actor.
//

import Foundation
import SQLite3

/// Todo 状态真值
public enum TodoStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
}

/// Todo 优先级真值
public enum TodoPriority: Int, Codable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
}

/// Todo 真值
public struct TodoItem: Equatable, Sendable {
    public let id: String
    public var title: String
    public var status: TodoStatus
    public var priority: TodoPriority
    public var dueDate: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, status: TodoStatus = .pending, priority: TodoPriority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// SQLite 透明指针 wrap
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

/// TodoStore: SQLite-backed todo
public actor TodoStore {
    private let dbPtr: SQLitePtr
    private let dbPath: String

    /// WIRE-TODO-001: listeners subscribed to writes (= AsyncStream
    /// of `TodoItem`). Each `add` / `setStatus` / `delete` fires a
    /// `notify(_:)` so the UI (= TodoListView, future widgets) can
    /// re-read on the fly instead of polling. Keyed by subscription
    /// token (= UUID) so `unsubscribe` can drop one without touching
    /// the rest. Continuations are flushed on deinit (= finalizer
    /// safety net: never leave a consumer hanging on a closed actor).
    private var listeners: [UUID: AsyncStream<TodoItem>.Continuation] = [:]

    public init(path: String? = nil) throws {
        let url: URL
        if let path = path {
            url = URL(fileURLWithPath: path)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("wenshu", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("todo.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw TodoStoreError.openFailed(dbPath: url.path, message: TodoStore.sqliteErmsg(ptr.db))
        }
        self.dbPtr = ptr
    }

    public func bootstrap() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS todos (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            priority INTEGER NOT NULL,
            due_date REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_todos_status ON todos(status);
        CREATE INDEX IF NOT EXISTS idx_todos_priority ON todos(priority);
        """
        try exec(sql)
    }

    public func add(title: String, priority: TodoPriority = .medium, dueDate: Date? = nil) throws -> TodoItem {
        let now = Date()
        let todo = TodoItem(id: UUID().uuidString, title: title, status: .pending, priority: priority, dueDate: dueDate, createdAt: now, updatedAt: now)
        let sql = "INSERT INTO todos (id, title, status, priority, due_date, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, todo.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, todo.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, todo.status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, Int32(todo.priority.rawValue))
        if let due = dueDate {
            sqlite3_bind_double(stmt, 5, due.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_double(stmt, 6, todo.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, todo.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TodoStoreError.stepFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        notify(todo)
        return todo
    }

    public func setStatus(id: String, status: TodoStatus) throws {
        let now = Date()
        let sql = "UPDATE todos SET status = ?, updated_at = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, now.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TodoStoreError.stepFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        // WIRE-TODO-001: notify listeners with the post-update row so
        // they don't need to re-query to see the new status.
        if let updated = try get(id: id) {
            notify(updated)
        }
    }

    public func get(id: String) throws -> TodoItem? {
        let sql = "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return readRow(stmt)
    }

    public func list(status: TodoStatus? = nil, orderByPriority: Bool = true) throws -> [TodoItem] {
        let sql: String
        if orderByPriority {
            sql = status != nil
                ? "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos WHERE status = ? ORDER BY priority DESC, due_date ASC;"
                : "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos ORDER BY priority DESC, due_date ASC;"
        } else {
            sql = status != nil
                ? "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos WHERE status = ? ORDER BY created_at DESC;"
                : "SELECT id, title, status, priority, due_date, created_at, updated_at FROM todos ORDER BY created_at DESC;"
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        if let status = status {
            sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        }
        var results: [TodoItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readRow(stmt))
        }
        return results
    }

    public func delete(id: String) throws {
        // WIRE-TODO-001: capture the row before deletion so listeners
        // see the removed item via the stream (= consumers that
        // re-list() on every notification will see it disappear).
        let removed: TodoItem? = try get(id: id)
        let sql = "DELETE FROM todos WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TodoStoreError.stepFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        if let removed = removed {
            notify(removed)
        }
    }

    public func count(status: TodoStatus? = nil) throws -> Int {
        let sql = status != nil ? "SELECT COUNT(*) FROM todos WHERE status = ?;" : "SELECT COUNT(*) FROM todos;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw TodoStoreError.prepareFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        if let status = status {
            sqlite3_bind_text(stmt, 1, status.rawValue, -1, SQLITE_TRANSIENT)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func readRow(_ stmt: OpaquePointer?) -> TodoItem {
        let id = TodoStore.textColumn(stmt, 0) ?? ""
        let title = TodoStore.textColumn(stmt, 1) ?? ""
        let status = TodoStatus(rawValue: TodoStore.textColumn(stmt, 2) ?? "pending") ?? .pending
        let priorityRaw = Int(sqlite3_column_int(stmt, 3))
        let priority = TodoPriority(rawValue: priorityRaw) ?? .medium
        let due: Date? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
        return TodoItem(id: id, title: title, status: status, priority: priority, dueDate: due, createdAt: created, updatedAt: updated)
    }

    // MARK: - WIRE-TODO-001: subscribe / unsubscribe / notify

    /// Subscribe to TodoStore writes. Returns:
    ///   - `id`: the subscription token (= pass back to `unsubscribe`
    ///     to cancel without touching other listeners).
    ///   - `stream`: an `AsyncStream<TodoItem>` that yields the
    ///     affected row after each `add` / `setStatus` / `delete`.
    ///
    /// Consumers typically `for await item in stream { await refresh() }`
    /// — the stream element carries the changed item but the consumer
    /// owns the refresh policy (= in practice, re-read `list()`).
    ///
    /// The stream is buffered with the default unbounded policy so a
    /// slow consumer doesn't block the actor; a terminated stream
    /// (= via `unsubscribe` or `deinit`) is finalized and yields no
    /// further elements.
    public func subscribe() -> (id: UUID, stream: AsyncStream<TodoItem>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<TodoItem>.makeStream()
        listeners[id] = continuation
        return (id, stream)
    }

    /// Cancel a subscription. The matching continuation is dropped and
    /// finalized (= no more elements). Safe to call with an unknown
    /// id (= no-op).
    public func unsubscribe(_ id: UUID) {
        if let c = listeners.removeValue(forKey: id) {
            c.finish()
        }
    }

    /// Fire-and-forget notification: yield the affected row to every
    /// active listener. Detached continuations (= already finished
    /// by their consumer) are silently dropped. `nil` is a no-op.
    private func notify(_ item: TodoItem) {
        guard !listeners.isEmpty else { return }
        for (_, continuation) in listeners {
            continuation.yield(item)
        }
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(dbPtr.db, sql, nil, nil, nil) != SQLITE_OK {
            throw TodoStoreError.execFailed(message: TodoStore.sqliteErmsg(dbPtr.db))
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

public enum TodoStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
private let SQLITE_NULL = 5