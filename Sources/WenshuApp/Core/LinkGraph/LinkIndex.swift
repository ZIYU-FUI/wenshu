//
//  LinkIndex.swift · Wenshu · v0.19 ticket 12 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入'.
//
//  本地 SQLite 双向链接索引 (Internal Link [[name]] + Backlinks 反向链接).
//  跟 v0.18 ticket 01 MemoryStore 同样的 actor + SQLitePtr wrap + bootstrap() + createSchema() 范式.
//  接口对齐 Obsidian Backlinks plugin 真值: add / remove / searchForward / searchBackward.
//
//  SQLite 真值: Apple Foundation 内置 SQLite3, schema = source_doc_id / target_ref / target_doc_id / line / offset / created_at
//  跟 SilverBullet page ref `[[name]]` 同语法, 跟 Obsidian / SilverBullet 双向兼容.
//

import Foundation
import SQLite3

/// 1 link = 1 row, schema = source_doc_id / target_ref / target_doc_id / line / offset / created_at
/// - source_doc_id: current document ID (= WenshuLibrary Book.id)
/// - target_ref: target reference string inside `[[name]]` (unresolved, kept as-is)
/// - target_doc_id: resolved target document ID (may be empty, because `[[new name]]` has no corresponding document yet)
/// - line / offset: position of the link in the source document
public struct Link: Equatable, Sendable {
    public let sourceDocId: String
    public let targetRef: String
    public let targetDocId: String?
    public let line: Int
    public let offset: Int
    public let createdAt: Date

    public init(sourceDocId: String, targetRef: String, targetDocId: String?, line: Int, offset: Int, createdAt: Date = Date()) {
        self.sourceDocId = sourceDocId
        self.targetRef = targetRef
        self.targetDocId = targetDocId
        self.line = line
        self.offset = offset
        self.createdAt = createdAt
    }
}

/// LinkStore error (same pattern as MemoryStoreError)
public enum LinkStoreError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
    case bindFailed(message: String)
    case notFound(sourceDocId: String)
}

/// SQLite transparent pointer wrap (same as MemoryStore)
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

/// SQLite emsg helper (same as MemoryStore SQLiteErmsg, per-file private)
private enum SQLiteErmsg {
    static func message(_ db: OpaquePointer?) -> String {
        guard let db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}

/// SQLite transient destructor (per-file private, same pitfall as v0.18 MemoryStore — actor across files must define independently)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// LinkIndex: SQLite-backed bidirectional link index, thread-safe actor, API aligned with Obsidian Backlinks plugin
public actor LinkIndex {
    private let dbPtr: SQLitePtr
    private let dbPath: String

    /// Initialize (memory or disk) — Apple HIG ground truth: default disk = Library/Application Support/wenshu/links.db
    public init(path: String? = nil) throws {
        let url: URL
        if let path = path {
            url = URL(fileURLWithPath: path)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("wenshu", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("links.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw LinkStoreError.openFailed(dbPath: url.path, message: SQLiteErmsg.message(ptr.db))
        }
        self.dbPtr = ptr
    }

    /// Call on startup: create tables (can only call self after actor is initialized)
    public func bootstrap() throws {
        try createSchema()
    }

    /// Create links table (if not exists)
    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS links (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_doc_id TEXT NOT NULL,
            target_ref TEXT NOT NULL,
            target_doc_id TEXT,
            line INTEGER NOT NULL,
            offset INTEGER NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_links_source ON links(source_doc_id);
        CREATE INDEX IF NOT EXISTS idx_links_target_ref ON links(target_ref);
        CREATE INDEX IF NOT EXISTS idx_links_target_doc ON links(target_doc_id);
        """
        try exec(sql)
    }

    /// Execute SQL (same pattern as MemoryStore.exec)
    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(dbPtr.db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw LinkStoreError.execFailed(sql: sql, message: msg)
        }
    }

    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// Add 1 link
    public func add(_ link: Link) throws {
        let sql = """
        INSERT INTO links (source_doc_id, target_ref, target_doc_id, line, offset, created_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw LinkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, link.sourceDocId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, link.targetRef, -1, SQLITE_TRANSIENT)
        if let target = link.targetDocId {
            sqlite3_bind_text(stmt, 3, target, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, Int32(link.line))
        sqlite3_bind_int(stmt, 5, Int32(link.offset))
        sqlite3_bind_double(stmt, 6, link.createdAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LinkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    /// Delete all links for source_doc_id (clear when document is rewritten/deleted)
    public func removeAll(sourceDocId: String) throws {
        let sql = "DELETE FROM links WHERE source_doc_id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw LinkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, sourceDocId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw LinkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    /// Forward query: given source_doc_id, return all targets it references (Obsidian 'Outgoing links')
    public func searchForward(sourceDocId: String) throws -> [Link] {
        try queryLinks(where: "source_doc_id = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, sourceDocId, -1, SQLITE_TRANSIENT)
        })
    }

    /// Backward query: given target_ref or target_doc_id, return all sources that reference it (Obsidian 'Backlinks')
    public func searchBackward(targetRef: String) throws -> [Link] {
        try queryLinks(where: "target_ref = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, targetRef, -1, SQLITE_TRANSIENT)
        })
    }

    public func searchBackward(targetDocId: String) throws -> [Link] {
        try queryLinks(where: "target_doc_id = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, targetDocId, -1, SQLITE_TRANSIENT)
        })
    }

    /// Common query helper
    private func queryLinks(where clause: String, bind: (OpaquePointer?) -> Void) throws -> [Link] {
        let sql = "SELECT source_doc_id, target_ref, target_doc_id, line, offset, created_at FROM links WHERE \(clause) ORDER BY created_at DESC;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw LinkStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        bind(stmt)
        var links: [Link] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cSource = sqlite3_column_text(stmt, 0),
                  let cRef = sqlite3_column_text(stmt, 1)
            else { continue }
            let sourceDocId = String(cString: cSource)
            let targetRef = String(cString: cRef)
            var targetDocId: String? = nil
            if let cTarget = sqlite3_column_text(stmt, 2) {
                targetDocId = String(cString: cTarget)
            }
            let line = Int(sqlite3_column_int(stmt, 3))
            let offset = Int(sqlite3_column_int(stmt, 4))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
            links.append(Link(sourceDocId: sourceDocId, targetRef: targetRef, targetDocId: targetDocId, line: line, offset: offset, createdAt: createdAt))
        }
        return links
    }
}
