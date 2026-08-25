//
//  ChatSessionStore.swift · Wenshu · v0.21 ticket 02 (chat persistent multi agent)
//

import Foundation
import SQLite3

/// ChatSessionStore: SQLite-backed chat message persistence. 1 session_id = 1 个延续会话 (老板 2026-08-21 拍 "用户永远看到的只有一个会话"). schema 2 表: chat_messages + chat_summaries. 范式跟 TodoStore / MemoryStore / KanbanStore 一致 (actor + SQLite).
public actor ChatSessionStore {
    private let dbPtr: SQLitePtr
    public let dbPath: String  // v0.24: public for App.swift init logging

    public init(path: String? = nil) throws {
        let url: URL
        if let path = path {
            url = URL(fileURLWithPath: path)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("wenshu", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            url = dir.appendingPathComponent("chat.sqlite")
        }
        self.dbPath = url.path
        let ptr = SQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw ChatSessionStoreError.openFailed(dbPath: url.path, message: ChatSessionStore.sqliteErmsg(ptr.db))
        }
        self.dbPtr = ptr
    }

    public func bootstrap() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL DEFAULT 'default',
            source TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp REAL NOT NULL,
            tokens INTEGER  -- v0.21 ticket 34: real LLM API usage.total_tokens (NULL = not available)
        );
        CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, timestamp);
        """

        let summarySql = """
        CREATE TABLE IF NOT EXISTS chat_summaries (
            session_id TEXT PRIMARY KEY,
            summary TEXT NOT NULL,
            updated_at REAL NOT NULL,
            last_message_id TEXT
        );
        """

        // v0.24 boss验收fix (Boss 8/25 OOB chat persistence bug):
        // ALTER TABLE chat_messages ADD COLUMN tokens INTEGER (idempotent —
        // SQLite returns "duplicate column name" if already exists, swallowed).
        // Existing chat.sqlite (created before commit 39e8d436c) lacks tokens
        // column; vm.send() agent append fails silently with "no such column:
        // tokens" because CREATE TABLE IF NOT EXISTS does not migrate schema.
        let alterSql = "ALTER TABLE chat_messages ADD COLUMN tokens INTEGER;"
        if sqlite3_exec(dbPtr.db, alterSql, nil, nil, nil) != SQLITE_OK {
            let errMsg = ChatSessionStore.sqliteErmsg(dbPtr.db)
            if !errMsg.contains("duplicate column name") {
                NSLog("[wenshu.chatStore] schema migration warning: %@", errMsg)
            }
        }
        // v0.23 ticket 006: sub-agent run trace (boss 8/23 拍: "用户不需要执行细节, 只看结果即可").
        // Schema: id / session_id / agent_name / title / status / started_at / completed_at / result_summary.
        // NOT stored: full LLM dialogue, system prompts, intermediate steps.
        let subAgentRunSql = """
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
        CREATE INDEX IF NOT EXISTS idx_sub_agent_runs_session ON sub_agent_runs(session_id, started_at);
        """
        try exec(sql)
        try exec(summarySql)
        try exec(subAgentRunSql)
    }

    /// loadMessages: 按 timestamp ASC 加载 1 session 的全部消息 (跟 ChatView UI 渲染顺序一致)
    public func loadMessages(sessionId: String) throws -> [StoredChatMessage] {
        let sql = "SELECT id, source, content, timestamp, tokens FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        var results: [StoredChatMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = ChatSessionStore.textColumn(stmt, 0) ?? ""
            let source = ChatSessionStore.textColumn(stmt, 1) ?? "system"
            let content = ChatSessionStore.textColumn(stmt, 2) ?? ""
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            // v0.21 ticket 34: tokens column (INTEGER, nullable)
            let tokens: Int? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 4))
            results.append(StoredChatMessage(id: id, source: source, content: content, timestamp: timestamp, tokens: tokens))
        }
        return results
    }

    /// append: 写 1 条消息到指定 session
    public func append(_ message: StoredChatMessage, sessionId: String) throws {
        let sql = "INSERT OR REPLACE INTO chat_messages (id, session_id, source, content, timestamp, tokens) VALUES (?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, message.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, message.source, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, message.content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 5, message.timestamp.timeIntervalSince1970)
        if let t = message.tokens {
            sqlite3_bind_int64(stmt, 6, Int64(t))
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ChatSessionStoreError.stepFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// clear: 清空 1 session 的 messages, 保留 summary (老板可以多次开始新 chat, 旧 history 留底)
    public func clear(sessionId: String) throws {
        let sql = "DELETE FROM chat_messages WHERE session_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ChatSessionStoreError.stepFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// count: 1 session 的消息总数 (ticket 05 sliding window 用 threshold 比较)
    public func count(sessionId: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM chat_messages WHERE session_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// loadSummary: 读 1 session 的 summary (ticket 05 持久化摘要)
    public func loadSummary(sessionId: String) throws -> String? {
        let sql = "SELECT summary FROM chat_summaries WHERE session_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return ChatSessionStore.textColumn(stmt, 0)
    }

    /// saveSummary: 写 1 session 的 summary (覆盖)
    public func saveSummary(_ summary: String, sessionId: String, lastMessageId: String) throws {
        let sql = "INSERT OR REPLACE INTO chat_summaries (session_id, summary, updated_at, last_message_id) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, summary, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, lastMessageId, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ChatSessionStoreError.stepFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// deleteOldMessages: 删 1 session 早于某 timestamp 的旧 messages (ticket 05 summary 生成后删老原文)
    public func deleteOldMessages(sessionId: String, beforeTimestamp: Date) throws {
        let sql = "DELETE FROM chat_messages WHERE session_id = ? AND timestamp < ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, beforeTimestamp.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ChatSessionStoreError.stepFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// summaryCutoffTimestamp: 留最新 lastN 条 messages, 返回 cutoff timestamp (比 cutoff 早的全删). 返回 nil 表示不需要触发 summary.
    public func summaryCutoffTimestamp(sessionId: String, keepLastN: Int) throws -> Date? {
        let count = try count(sessionId: sessionId)
        guard count > keepLastN else { return nil }
        // 找第 (count - keepLastN) 条消息的 timestamp (= cutoff)
        let offset = count - keepLastN
        let sql = "SELECT timestamp FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC LIMIT 1 OFFSET ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(offset))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
    }

    /// messagesBeforeCutoff: 返回 cutoff 之前的 messages (供 LLM summary 生成用)
    public func messagesBeforeCutoff(sessionId: String, cutoff: Date) throws -> [StoredChatMessage] {
        let sql = "SELECT id, source, content, timestamp, tokens FROM chat_messages WHERE session_id = ? AND timestamp < ? ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, cutoff.timeIntervalSince1970)
        var results: [StoredChatMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = ChatSessionStore.textColumn(stmt, 0) ?? ""
            let source = ChatSessionStore.textColumn(stmt, 1) ?? "system"
            let content = ChatSessionStore.textColumn(stmt, 2) ?? ""
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            // v0.21 ticket 34: tokens column (INTEGER, nullable)
            let tokens: Int? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 4))
            results.append(StoredChatMessage(id: id, source: source, content: content, timestamp: timestamp, tokens: tokens))
        }
        return results
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(dbPtr.db, sql, nil, nil, nil) != SQLITE_OK {
            throw ChatSessionStoreError.execFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// summarizeIfNeeded: 当 count > threshold 时, 拿前 (count - lastN) 条 messages → 调 LLM 生成 summary → saveSummary → deleteOldMessages.
    /// 老板 2026-08-21 拍 '看似唯一会话能延续继续聊, 上下文不能爆'. spec ticket 05 真值.
    public func summarizeIfNeeded(
        sessionId: String,
        lastN: Int = 10,
        threshold: Int = 20,
        verifier: WenshuVerifier
    ) async throws -> Bool {
        guard let cutoff = try summaryCutoffTimestamp(sessionId: sessionId, keepLastN: lastN) else {
            return false  // 不需要 trigger summary
        }
        guard cutoff != Date(timeIntervalSince1970: 0) else {
            // cutoff 早于 epoch → count > threshold 但 timestamp 异常
            return false
        }
        let oldMessages = try messagesBeforeCutoff(sessionId: sessionId, cutoff: cutoff)
        guard !oldMessages.isEmpty else { return false }

        // 拼装 summary prompt
        let transcript = oldMessages.prefix(20).map { msg -> String in
            "[\(msg.source)] \(msg.content.prefix(100))"
        }.joined(separator: "\n")
        let summaryPrompt = """
        请用 200 字内总结以下聊天记录的关键信息 (人名 / 偏好 / 上下文 / 决定), 用中文:

        \(transcript)
        """
        // 调 LLM 生成 summary (spec ticket 05 step 1 真值)
        let response = try await verifier.chat(summaryPrompt)
        // v0.21 ticket 39: union decode (text / thinking / tool_use) — concat all text blocks for summary
        let summary = response.content.map(\.displayText).joined()

        // 写 summary + 删老原文 (顺序不能反, 否则上下文丢失)
        if let firstOldId = oldMessages.first?.id {
            try saveSummary(summary, sessionId: sessionId, lastMessageId: firstOldId)
        }
        try deleteOldMessages(sessionId: sessionId, beforeTimestamp: cutoff)
        return true
    }

    private static func textColumn(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cString)
    }

    fileprivate static func sqliteErmsg(_ db: OpaquePointer?) -> String {
        guard let db = db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: - v0.23 ticket 006: sub-agent run trace

    /// recordSubAgentRun: 写 1 条 sub-agent run summary.
    /// Boss 8/23 拍: "用户不需要执行细节, 只看结果即可" — 不存 LLM 中间对话, 只存 1-line result summary.
    public func recordSubAgentRun(_ run: SubAgentRun, sessionId: String) throws {
        let sql = "INSERT OR REPLACE INTO sub_agent_runs (id, session_id, agent_name, title, status, started_at, completed_at, result_summary) VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, run.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, sessionId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, run.agentName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, run.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, run.status.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 6, run.startedAt.timeIntervalSince1970)
        if let completedAt = run.completedAt {
            sqlite3_bind_double(stmt, 7, completedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 7)
        }
        if let summary = run.resultSummary {
            sqlite3_bind_text(stmt, 8, summary, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ChatSessionStoreError.stepFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
    }

    /// loadSubAgentRuns: 按 started_at ASC 加载 1 session 的全部 sub-agent run.
    /// Used by future "trace replay" view (boss 8/23 拍: 看板任务清单, 任务状态就够).
    public func loadSubAgentRuns(sessionId: String) throws -> [SubAgentRun] {
        let sql = "SELECT id, agent_name, title, status, started_at, completed_at, result_summary FROM sub_agent_runs WHERE session_id = ? ORDER BY started_at ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ChatSessionStoreError.prepareFailed(message: ChatSessionStore.sqliteErmsg(dbPtr.db))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, sessionId, -1, SQLITE_TRANSIENT)
        var results: [SubAgentRun] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = ChatSessionStore.textColumn(stmt, 0) ?? ""
            let agentName = ChatSessionStore.textColumn(stmt, 1) ?? ""
            let title = ChatSessionStore.textColumn(stmt, 2) ?? ""
            let statusStr = ChatSessionStore.textColumn(stmt, 3) ?? "running"
            let startedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let completedAt: Date? = sqlite3_column_type(stmt, 5) == SQLITE_NULL
                ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
            let resultSummary: String? = sqlite3_column_type(stmt, 6) == SQLITE_NULL
                ? nil : ChatSessionStore.textColumn(stmt, 6)
            let status = SubAgentRunStatus(rawValue: statusStr) ?? .running
            results.append(SubAgentRun(
                id: id, agentName: agentName, title: title, status: status,
                startedAt: startedAt, completedAt: completedAt, resultSummary: resultSummary
            ))
        }
        return results
    }
}

/// SubAgentRun: 1-line summary of one sub-agent run.
public struct SubAgentRun: Equatable, Sendable {
    public let id: String
    public let agentName: String
    public let title: String
    public let status: SubAgentRunStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let resultSummary: String?

    public init(
        id: String,
        agentName: String,
        title: String,
        status: SubAgentRunStatus,
        startedAt: Date,
        completedAt: Date? = nil,
        resultSummary: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.title = title
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.resultSummary = resultSummary
    }
}

public enum SubAgentRunStatus: String, Codable, Sendable, CaseIterable {
    case running
    case done
    case failed
}

/// StoredChatMessage: DB 层的 chat message 真值 (= ChatMessage 简化, 不带 ChatRole 因为 source 字段已含 role 真值). 范式跟 TodoItem 一致 (id + content + 时间).
public struct StoredChatMessage: Equatable, Sendable {
    public let id: String
    public let source: String  // user / wenshu / system
    public let content: String
    public let timestamp: Date
    public let tokens: Int?    // v0.21 ticket 34: real LLM API usage.total_tokens (nil if not available)

    public init(id: String, source: String, content: String, timestamp: Date, tokens: Int? = nil) {
        self.id = id
        self.source = source
        self.content = content
        self.timestamp = timestamp
        self.tokens = tokens
    }
}

public enum ChatSessionStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

private final class SQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)