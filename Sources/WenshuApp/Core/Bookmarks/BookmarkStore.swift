//
//  BookmarkStore.swift · Wenshu · v0.19 ticket 22 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  跨 note 收藏夹 (actor SQLite-backed).
//  跟 Obsidian Bookmarks plugin 行为对齐 (https://obsidian.md/help/plugins/bookmarks).
//  Apple HIG: actor + SQLite + Codable 跟 v0.18 ticket 01 MemoryStore 同范式.
//

import Foundation
import SQLite3

/// 1 条书签 = 1 row
public struct Bookmark: Equatable, Sendable, Identifiable {
    public var id: String          // UUID
    public var docId: String       // 收藏的 doc_id
    public var label: String       // 显示标签
    public var createdAt: Date

    public init(id: String = UUID().uuidString, docId: String, label: String, createdAt: Date = Date()) {
        self.id = id
        self.docId = docId
        self.label = label
        self.createdAt = createdAt
    }
}

/// BookmarkStore 错误
public enum BookmarkStoreError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
}

/// SQLite helper (per-file private, 跟 LinkIndex 同范式)
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

private enum SQLiteErmsg {
    static func message(_ db: OpaquePointer?) -> String {
        guard let db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// BookmarkStore: SQLite-backed 收藏夹
public actor BookmarkStore {
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
            url = dir.appendingPathComponent("bookmarks.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw BookmarkStoreError.openFailed(dbPath: url.path, message: SQLiteErmsg.message(ptr.db))
        }
        self.dbPtr = ptr
    }

    public func bootstrap() throws {
        try createSchema()
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS bookmarks (
            id TEXT PRIMARY KEY,
            doc_id TEXT NOT NULL,
            label TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_bookmarks_doc_id ON bookmarks(doc_id);
        CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at DESC);
        """
        try exec(sql)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(dbPtr.db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw BookmarkStoreError.execFailed(sql: sql, message: msg)
        }
    }

    /// 加书签
    public func add(_ bookmark: Bookmark) throws {
        let sql = "INSERT INTO bookmarks (id, doc_id, label, created_at) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw BookmarkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, bookmark.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, bookmark.docId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, bookmark.label, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, bookmark.createdAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw BookmarkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    /// 删书签 (按 id)
    public func remove(id: String) throws {
        let sql = "DELETE FROM bookmarks WHERE id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw BookmarkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw BookmarkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    /// 列所有书签 (按 created_at DESC)
    public func list() throws -> [Bookmark] {
        let sql = "SELECT id, doc_id, label, created_at FROM bookmarks ORDER BY created_at DESC;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw BookmarkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        var bookmarks: [Bookmark] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cId = sqlite3_column_text(stmt, 0),
                  let cDocId = sqlite3_column_text(stmt, 1),
                  let cLabel = sqlite3_column_text(stmt, 2)
            else { continue }
            let id = String(cString: cId)
            let docId = String(cString: cDocId)
            let label = String(cString: cLabel)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            bookmarks.append(Bookmark(id: id, docId: docId, label: label, createdAt: createdAt))
        }
        return bookmarks
    }
}
