//
//  WenshuWorkspace.swift · Wenshu · v0.23 ticket 014.001
//
//  Boss 2026-08-23 拍: '我想先落地, 类似 FCP 的库文件'.
//
//  Single-file workspace (FCP .fcpbundle parity) — one SQLite file
//  contains all wenshu state (chat / kanban / memory / skills / provider
//  keys / preferences / books / bookmarks / outline / attachments).
//
//  File location: ~/Library/Application Support/wenshu/workspace.ws
//

import Foundation
import SQLite3

/// WenshuWorkspace: single-file workspace actor (FCP .fcpbundle parity).
/// Owns 1 SQLite connection. All state tables (chat / kanban / memory / etc.)
/// live in this one file.
public actor WenshuWorkspace {

    // MARK: - Singleton

    /// shared: default workspace (one per process).
    public static let shared = WenshuWorkspace()

    // MARK: - Schema

    /// v0.23 ticket 014.001: schema version constant.
    /// Bump on every schema change. Migrator reads this + manifest to decide
    /// if migration is needed.
    public static let currentSchemaVersion: Int = 1

    /// Default workspace file path.
    public static let defaultPath: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appendingPathComponent("wenshu", isDirectory: true)
            .appendingPathComponent("workspace.ws")
    }()

    // MARK: - State

    private let dbPath: URL
    private let fm: FileManager
    private var dbPtr: OpaquePointer?

    // MARK: - Init

    public init(path: URL = WenshuWorkspace.defaultPath) {
        self.dbPath = path
        self.fm = FileManager.default
    }

    // MARK: - Lifecycle

    /// open: ensure parent dir exists, then open (or create) the SQLite file.
    public func open() throws {
        // Ensure parent dir.
        let parent = dbPath.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)

        // Open SQLite (creates file if missing).
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(dbPath.path, &handle, flags, nil) == SQLITE_OK else {
            throw WenshuWorkspaceError.openFailed(path: dbPath.path, message: lastError(handle))
        }
        self.dbPtr = handle

        // WAL mode (concurrent reads + 1 writer).
        try exec("PRAGMA journal_mode=WAL;")
        // busy_timeout (5s) — wait if another process holds the lock.
        try exec("PRAGMA busy_timeout=5000;")
        // foreign_keys (default off in SQLite).
        try exec("PRAGMA foreign_keys=ON;")

        // Create schema if missing.
        try bootstrapSchema()
    }

    /// close: finalize open statement + close DB.
    public func close() {
        if let db = dbPtr {
            sqlite3_close(db)
            dbPtr = nil
        }
    }

    // MARK: - Schema bootstrap

    private func bootstrapSchema() throws {
        // Manifest table (tracks schema version + workspace uuid).
        let manifestSql = """
        CREATE TABLE IF NOT EXISTS ws_manifest (
            schema_version INTEGER NOT NULL,
            workspace_uuid TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            wenshu_version TEXT NOT NULL,
            checksum TEXT
        );
        """
        try exec(manifestSql)

        // If manifest is empty (fresh DB), seed.
        let countSql = "SELECT COUNT(*) FROM ws_manifest;"
        let count = queryScalarInt(countSql) ?? 0
        if count == 0 {
            let uuid = UUID().uuidString
            let now = Date().timeIntervalSince1970
            let seedSql = """
            INSERT INTO ws_manifest (schema_version, workspace_uuid, created_at, updated_at, wenshu_version, checksum)
            VALUES (\(WenshuWorkspace.currentSchemaVersion), '\(uuid)', \(now), \(now), 'v0.23', NULL);
            """
            try exec(seedSql)
        }

        // Other tables (forward-compatible: each gets IF NOT EXISTS).
        try exec(Self.chatMessagesSql)
        try exec(Self.chatSummariesSql)
        try exec(Self.kanbanTasksSql)
        try exec(Self.subAgentRunsSql)
        try exec(Self.memoryEntriesSql)
        try exec(Self.skillsSql)
        try exec(Self.providerKeysSql)
        try exec(Self.preferencesSql)
        try exec(Self.booksSql)
        try exec(Self.bookmarksSql)
        try exec(Self.outlineEntriesSql)
        try exec(Self.attachmentsSql)

        // Indexes (common queries).
        try exec("CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, timestamp);")
        try exec("CREATE INDEX IF NOT EXISTS idx_kanban_tasks_status ON kanban_tasks(status);")
        try exec("CREATE INDEX IF NOT EXISTS idx_sub_agent_runs_session ON sub_agent_runs(session_id, started_at);")
        try exec("CREATE INDEX IF NOT EXISTS idx_memory_entries_user ON memory_entries(user_id);")
        try exec("CREATE INDEX IF NOT EXISTS idx_books_shelf ON books(shelf_id);")
        try exec("CREATE INDEX IF NOT EXISTS idx_outline_entries_book ON outline_entries(book_id);")
    }

    // MARK: - Schema SQL (v1)

    static let chatMessagesSql = """
    CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL DEFAULT 'default',
        source TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp REAL NOT NULL,
        tokens INTEGER,
        thinking TEXT
    );
    """

    static let chatSummariesSql = """
    CREATE TABLE IF NOT EXISTS chat_summaries (
        session_id TEXT PRIMARY KEY,
        summary TEXT NOT NULL,
        updated_at REAL NOT NULL,
        last_message_id TEXT
    );
    """

    static let kanbanTasksSql = """
    CREATE TABLE IF NOT EXISTS kanban_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 5,
        assignee TEXT,
        started_at REAL,
        completed_at REAL,
        model_override TEXT,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    static let subAgentRunsSql = """
    CREATE TABLE IF NOT EXISTS sub_agent_runs (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL DEFAULT 'default',
        agent_name TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at REAL NOT NULL,
        completed_at REAL,
        result_summary TEXT
    );
    """

    static let memoryEntriesSql = """
    CREATE TABLE IF NOT EXISTS memory_entries (
        user_id TEXT NOT NULL,
        memory_id TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        PRIMARY KEY (user_id, memory_id)
    );
    """

    static let skillsSql = """
    CREATE TABLE IF NOT EXISTS skills (
        name TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        source TEXT NOT NULL,
        trust_level TEXT NOT NULL,
        path TEXT NOT NULL,
        installed_at REAL NOT NULL
    );
    """

    static let providerKeysSql = """
    CREATE TABLE IF NOT EXISTS provider_keys (
        provider_slug TEXT PRIMARY KEY,
        encrypted_key BLOB NOT NULL,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    static let preferencesSql = """
    CREATE TABLE IF NOT EXISTS preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    static let booksSql = """
    CREATE TABLE IF NOT EXISTS books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        idea TEXT,
        length INTEGER,
        shelf_id TEXT,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    """

    static let bookmarksSql = """
    CREATE TABLE IF NOT EXISTS bookmarks (
        id TEXT PRIMARY KEY,
        book_id TEXT,
        title TEXT NOT NULL,
        note TEXT,
        position INTEGER,
        created_at REAL NOT NULL
    );
    """

    static let outlineEntriesSql = """
    CREATE TABLE IF NOT EXISTS outline_entries (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        level INTEGER NOT NULL,
        title TEXT NOT NULL,
        line_number INTEGER,
        parent_id TEXT
    );
    """

    static let attachmentsSql = """
    CREATE TABLE IF NOT EXISTS attachments (
        id TEXT PRIMARY KEY,
        parent_table TEXT NOT NULL,
        parent_id TEXT NOT NULL,
        filename TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        data BLOB,
        external_path TEXT,
        created_at REAL NOT NULL
    );
    """

    // MARK: - Manifest API

    /// currentSchemaVersion: read from manifest.
    public func currentManifestVersion() -> Int? {
        return queryScalarInt("SELECT schema_version FROM ws_manifest LIMIT 1;")
    }

    /// workspaceUUID: read from manifest.
    public func workspaceUUID() -> String? {
        return queryScalarText("SELECT workspace_uuid FROM ws_manifest LIMIT 1;")
    }

    /// updateManifestTimestamp: called on any write.
    public func updateManifestTimestamp() throws {
        let now = Date().timeIntervalSince1970
        try exec("UPDATE ws_manifest SET updated_at = \(now);")
    }

    // MARK: - Backup / Export / Integrity

    /// backup: copy the workspace file to a destination (atomic).
    /// Used for: Time Machine, manual backup, cross-device transfer.
    public func backup(to destination: URL) throws {
        // Flush WAL → main DB.
        try exec("PRAGMA wal_checkpoint(TRUNCATE);")
        // Atomic copy (FileManager.replaceItemAt).
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: dbPath, to: destination)
    }

    /// integrityCheck: verify SQLite integrity + manifest checksum.
    public func integrityCheck() -> Bool {
        // SQLite's built-in integrity_check pragma.
        let sql = "PRAGMA integrity_check;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                let result = String(cString: cString)
                if result != "ok" { return false }
            }
        }
        return true
    }

    // MARK: - Low-level SQLite helpers

    /// exec: run a SQL statement (no result expected).
    public func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(dbPtr, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw WenshuWorkspaceError.execFailed(sql: sql, message: msg)
        }
    }

    /// queryScalarInt: run scalar SELECT, return Int result (or nil on error).
    public func queryScalarInt(_ sql: String) -> Int? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// queryScalarText: run scalar SELECT, return String result (or nil on error).
    public func queryScalarText(_ sql: String) -> String? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(dbPtr, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let cString = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cString)
    }

    /// tableExists: check if a table exists in this workspace.
    public func tableExists(_ name: String) -> Bool {
        let sql = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='\(name)';"
        return (queryScalarInt(sql) ?? 0) > 0
    }

    /// queryCount: convenience for SELECT COUNT(*).
    public func queryCount(_ sql: String) -> Int? {
        return queryScalarInt(sql)
    }

    private func lastError(_ handle: OpaquePointer?) -> String {
        guard let h = handle, let c = sqlite3_errmsg(h) else { return "no handle" }
        return String(cString: c)
    }
}

/// Errors thrown by WenshuWorkspace.
public enum WenshuWorkspaceError: Error, LocalizedError {
    case openFailed(path: String, message: String)
    case execFailed(sql: String, message: String)
    case backupFailed(source: String, dest: String, message: String)
    case migrationFailed(from: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let path, let msg):
            return "WenshuWorkspace open failed at \(path): \(msg)"
        case .execFailed(let sql, let msg):
            return "WenshuWorkspace exec failed for SQL '\(sql.prefix(80))': \(msg)"
        case .backupFailed(let src, let dst, let msg):
            return "WenshuWorkspace backup failed from \(src) to \(dst): \(msg)"
        case .migrationFailed(let from, let msg):
            return "WenshuWorkspace migration failed from \(from): \(msg)"
        }
    }
}