//
// FullTextSearch.swift · Wenshu · v0.19 ticket 17 (Obsidian replica, do first)
// 2026-08-19 evening Obsidian A + ', '.
//
// SQLite FTS5 (Apple HIG: SQLite builtin FTS5, https://www.sqlite.org/fts5.html).
// v0.18 ticket 01 MemoryStore actor + SQLitePtr + bootstrap() .
// Obsidian Search plugin: index / remove / search / highlight.
//


//
//  SQL SAFETY: all sqlite3_*() calls in this file use hard-coded string
//  literals (= zero user-derived SQL = zero SQL injection risk TODAY).
//  Per AGENTS.md §11.3 wenshu-side wins pattern (= hermes-port parity,
//  = sqlite3 C API direct call preferred over GRDB abstraction = matches
//  hermes Python tool-store implementation verbatim).
//
//  SAFETY CONTRACT for future contributors:
//  - DO NOT concatenate user input into the SQL string (= use sqlite3_bind_*
//    parameter binding instead = the only safe pattern).
//  - DO NOT use String(format:) with %@/%.20s substitution (= format-injection).
//  - DO NOT read user input into the table/column names (= always use
//    fixed enum cases or hardcoded identifiers).
//  - If user-derived values are needed in WHERE/INSERT clauses, use
//    sqlite3_bind_text/stmt parameter binding with positional placeholders
//    (= ?, ?N, :name =, @name = per SQLite docs).
//
//  The audit at .scratch/2026-09-06-wenshu-hidden-defects-audit.md
//  documents this convention (= 14 raw sqlite3 sites across 10 files,
//  all hardcoded literals = safe).

import Foundation
import SQLite3

/// 1 search (Obsidian search result 1:1)
public struct SearchResult: Equatable, Sendable {
    public let docId: String
    public let snippet: String       // <mark>
    public let rank: Double          // BM25 ()
    public let line: Int             // in progressok (0-indexed)

    public init(docId: String, snippet: String, rank: Double, line: Int) {
        self.docId = docId
        self.snippet = snippet
        self.rank = rank
        self.line = line
    }
}

/// SearchStore error
public enum SearchStoreError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
    case bindFailed(message: String)
}

/// SQLite helper (per-file private, LinkIndex)
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

/// FullTextSearch: SQLite FTS5, actor
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

    /// FTS5 (Obsidian Search 1:1, schema = doc_id / title / body)
    /// Apple HIG: https://www.sqlite.org/fts5.html (built-in virtual table)
    /// tokenizer trigram (SQLite 3.34+): CJK ("" → in progress)
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    ///: / searchwork (trigram need 3+) — app / OK
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
    /// 1 (upsert: delete, insert)
    public func index(docId: String, title: String, body: String) throws {
        // FTS5 UPDATE, delete + insert
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
    /// delete 1
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

    /// search (BM25 ranking + highlight)
    /// query FTS5 MATCH (phrase / AND / OR / NOT)
    public func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        // FTS5 highlight() \0 /
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
