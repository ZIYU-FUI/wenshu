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

/// 1 条链接 = 1 row, schema = source_doc_id / target_ref / target_doc_id / line / offset / created_at
/// - source_doc_id: 当前文档 ID (= WenshuLibrary Book.id)
/// - target_ref: `[[name]]` 里的目标引用字符串 (未解析, 保留原样)
/// - target_doc_id: 解析后的目标文档 ID (可空, 因为 `[[new name]]` 可能对应未存在的文档)
/// - line / offset: 链接在 source 文档里的位置
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

/// LinkStore 错误 (跟 MemoryStoreError 同范式)
public enum LinkStoreError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
    case bindFailed(message: String)
    case notFound(sourceDocId: String)
}

/// SQLite 透明指针 wrap (跟 MemoryStore 同)
private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

/// SQLite emsg helper (跟 MemoryStore SQLiteErmsg 同, per-file private)
private enum SQLiteErmsg {
    static func message(_ db: OpaquePointer?) -> String {
        guard let db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }
}

/// SQLite transient destructor (per-file private, 跟 v0.18 MemoryStore 同坑 — actor across files 必须独立定义)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// LinkIndex: SQLite-backed 双向链接索引, 线程安全 actor, 接口对齐 Obsidian Backlinks plugin
public actor LinkIndex {
    private let dbPtr: SQLitePtr
    private let dbPath: String

    /// 初始化 (内存或磁盘) — Apple HIG 真值: 默认磁盘 = Library/Application Support/wenshu/links.db
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

    /// 启动时调用: 建表 (actor 初始化后才能调 self)
    public func bootstrap() throws {
        try createSchema()
    }

    /// 创建 links 表 (if not exists)
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

    /// 执行 SQL (跟 MemoryStore.exec 同范式)
    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(dbPtr.db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw LinkStoreError.execFailed(sql: sql, message: msg)
        }
    }

    /// 加 1 条链接
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

    /// 删除 source_doc_id 的所有链接 (文档重写/删除时清空)
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

    /// 正向查: 给 source_doc_id, 拿它引用的所有目标 (Obsidian 'Outgoing links')
    public func searchForward(sourceDocId: String) throws -> [Link] {
        try queryLinks(where: "source_doc_id = ?", bind: { stmt in
            sqlite3_bind_text(stmt, 1, sourceDocId, -1, SQLITE_TRANSIENT)
        })
    }

    /// 反向查: 给 target_ref 或 target_doc_id, 拿所有引用它的 source (Obsidian 'Backlinks')
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

    /// 通用 query helper
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
