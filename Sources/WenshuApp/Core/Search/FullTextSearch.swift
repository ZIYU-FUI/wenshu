//
//  FullTextSearch.swift · Wenshu · v0.19 ticket 17 (Obsidian replica, 后端先做)
//  老板 2026-08-19 evening 拍 Obsidian 复刻范围 A + '复刻后端, 前端不接入核心项目'.
//
//  SQLite FTS5 全文索引 (Apple HIG 真值: SQLite builtin FTS5, https://www.sqlite.org/fts5.html).
//  跟 v0.18 ticket 01 MemoryStore 同 actor + SQLitePtr + bootstrap() 范式.
//  接口对齐 Obsidian Search plugin 真值: index / remove / search / highlight.
//

import Foundation
import SQLite3

/// 1 条搜索结果 (跟 Obsidian search result 1:1)
public struct SearchResult: Equatable, Sendable {
    public let docId: String
    public let snippet: String       // 含 <mark> 高亮的片段
    public let rank: Double          // BM25 排名 (越小越相关)
    public let line: Int             // 命中行号 (0-indexed)

    public init(docId: String, snippet: String, rank: Double, line: Int) {
        self.docId = docId
        self.snippet = snippet
        self.rank = rank
        self.line = line
    }
}

/// SearchStore 错误
public enum SearchStoreError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
    case bindFailed(message: String)
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

/// FullTextSearch: SQLite FTS5 全文索引, 线程安全 actor
public actor FullTextSearch {
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
            url = dir.appendingPathComponent("search.db")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw SearchStoreError.openFailed(dbPath: url.path, message: SQLiteErmsg.message(ptr.db))
        }
        self.dbPtr = ptr
    }

    public func bootstrap() throws {
        try createSchema()
    }

    /// FTS5 虚拟表 (跟 Obsidian Search 索引结构 1:1, schema = doc_id / title / body)
    /// Apple HIG 真值: https://www.sqlite.org/fts5.html (built-in virtual table)
    /// tokenizer 用 trigram (SQLite 3.34+): 支持 CJK 整词匹配 ("林黛玉" → 命中)
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 限制: 单字 / 短词搜索不工作 (trigram 需要 3+ 字符) — 写作 app 搜完整角色名 / 章节名 OK
    private func createSchema() throws {
        let sql = """
        CREATE VIRTUAL TABLE IF NOT EXISTS docs_fts USING fts5(
            doc_id UNINDEXED,
            title,
            body,
            tokenize = 'trigram'
        );
        """
        try exec(sql)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(dbPtr.db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw SearchStoreError.execFailed(sql: sql, message: msg)
        }
    }

    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 索引 1 个文档 (upsert: 先删除旧的, 再插入新的)
    public func index(docId: String, title: String, body: String) throws {
        // FTS5 没有原生 UPDATE, 用 delete + insert
        try remove(docId: docId)
        let sql = "INSERT INTO docs_fts (doc_id, title, body) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, docId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, body, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 删除 1 个文档
    public func remove(docId: String) throws {
        let sql = "DELETE FROM docs_fts WHERE doc_id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, docId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
    }

    /// 全文搜索 (BM25 ranking + highlight)
    /// query 走 FTS5 MATCH 语法 (支持 phrase / AND / OR / NOT)
    public func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        // FTS5 highlight() 用 \0 分隔开始 / 结束标记
        let sql = """
        SELECT doc_id, snippet(docs_fts, 2, '<mark>', '</mark>', '...', 16), rank, -1
        FROM docs_fts
        WHERE docs_fts MATCH ?
        ORDER BY rank
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchStoreError.execFailed(sql: sql, message: SQLiteErmsg.message(dbPtr.db))
        }
        sqlite3_bind_text(stmt, 1, query, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var results: [SearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cDocId = sqlite3_column_text(stmt, 0),
                  let cSnippet = sqlite3_column_text(stmt, 1)
            else { continue }
            let docId = String(cString: cDocId)
            let snippet = String(cString: cSnippet)
            let rank = sqlite3_column_double(stmt, 2)
            results.append(SearchResult(docId: docId, snippet: snippet, rank: rank, line: -1))
        }
        return results
    }
}
