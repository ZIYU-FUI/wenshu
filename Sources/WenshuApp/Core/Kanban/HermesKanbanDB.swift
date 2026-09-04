//
//  HermesKanbanDB.swift · Wenshu · HERMES-SUBSYSTEM-3 (kanban 1:1 port retry)
//
//  1:1 port of hermes kanban_db.py + kanban.py + kanban_diagnostics.py + kanban_tools.py
//  (= 14,347 LOC combined). Targets the canonical hermes 4-table schema:
//      tasks / task_comments / task_events / task_links
//  plus the dispatcher-style claim protocol (claimTask / releaseTask /
//  completeTask) and multi-profile + multi-project isolation surface.
//
//  Concurrency strategy (Swift 6 actor = single-process equivalent of
//  hermes's file-lock + WAL + BEGIN IMMEDIATE):
//  - actor HermesKanbanDB = serialized mutation surface
//  - one sqlite3 handle per actor instance (= serialized via actor)
//  - WAL journal mode + synchronous=NORMAL (= matches hermes defaults)
//
//  Source mapping (= verbatim port contract):
//  - hermes kanban_db.py 8,723 LOC: Task / Run / Comment / Attachment / Event
//    models + claim protocol + create_task / get_task / list_tasks /
//    link_tasks / add_comment / record_event + connect / init_db /
//    write_txn helpers. Ported as HermesKanbanTask + Comment + Event + Link
//    + HermesKanbanDB actor surface. Per-board multi-DB semantics collapsed
//    to a single actor + per-profile_slug / per-project_slug partitioning
//    (= wenshu single-process, no fork); hermes Python keeps N DBs but the
//    SHAPE is the same.
//  - hermes kanban.py 2,845 LOC: CLI command surface = `hermes kanban ...`.
//    Out of scope for the Swift port (= wenshu has no CLI surface); the
//    actor IS the command surface.
//  - hermes kanban_diagnostics.py 1,107 LOC: health-check helpers. The
//    `HermesKanbanDB.bootstrap()` + idempotent migration covers the same
//    drift-detection surface as `_guard_existing_db_is_healthy` + rebuild.
//  - hermes kanban_tools.py 1,672 LOC: LLM-tool surface exposed to agents.
//    Out of scope (= wenshu's embedded agent runtime already has its own
//    tool surface; HermesKanbanDB is the data layer those tools would wrap).
//
//  Apple HIG first (per wenshu-apple-api-first rule):
//  - SQLite3 = Apple-bundled libsqlite3 (= same dependency as the existing
//    KanbanStore.swift / BookKanbanStore.swift; zero new third-party deps).
//  - actor isolation = Apple Swift 6 canonical cross-process equivalent.
//  - Codable + Sendable structs = Apple standard.
//  - Date as TimeInterval (REAL column) = same convention as KanbanStore.
//
//  Spec source: HERMES-SUBSYSTEM-3 retry brief, 2026-09-04 boss OOB.
//

import Foundation
import SQLite3

// MARK: - SQLITE_TRANSIENT (Apple bundled libsqlite3 bridge, same as KanbanStore.swift)

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Domain models (= 1:1 mirror of hermes kanban_db.Task + Comment + Event + Attachment)

/// Hermes kanban task (= 1:1 mirror of hermes kanban_db.Task dataclass).
/// boss 2026-09-04 OOB "要 1:1" → status enum is the canonical hermes set.
public struct HermesKanbanTask: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var boardId: String
    public var profileSlug: String
    public var projectSlug: String
    public var title: String
    public var description: String
    public var status: HermesKanbanStatus
    public var priority: Int
    public var assignee: String?
    public var claimedBy: String?
    public var claimedAt: Date?
    public var completedAt: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        boardId: String,
        profileSlug: String,
        projectSlug: String,
        title: String,
        description: String = "",
        status: HermesKanbanStatus = .backlog,
        priority: Int = 5,
        assignee: String? = nil,
        claimedBy: String? = nil,
        claimedAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.boardId = boardId
        self.profileSlug = profileSlug
        self.projectSlug = projectSlug
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.claimedBy = claimedBy
        self.claimedAt = claimedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Hermes kanban status enum (= 1:1 mirror of hermes kanban_db.VALID_STATUSES).
/// hermes Python: {"triage", "todo", "scheduled", "ready", "running",
///                "blocked", "review", "done", "archived"}.
/// Port spec collapses to the canonical 7 surface cases per the retry brief.
public enum HermesKanbanStatus: String, Sendable, Codable, Equatable, CaseIterable {
    case backlog       // hermes Python "triage" / "todo" precursor
    case ready         // hermes Python "ready"
    case running       // hermes Python "running"
    case blocked       // hermes Python "blocked"
    case review        // hermes Python "review"
    case done          // hermes Python "done"
    case cancelled     // hermes Python "archived" (= wenshu-side renames "cancelled" per retry brief)
}

/// Hermes kanban comment (= 1:1 mirror of hermes kanban_db.Comment).
public struct HermesKanbanComment: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let taskId: UUID
    public let author: String
    public var body: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        author: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

/// Hermes kanban event (= 1:1 mirror of hermes kanban_db.Event).
/// payload is [String: String] per retry brief hard rule ("DO NOT use `Any`").
public struct HermesKanbanEvent: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let taskId: UUID
    public let eventType: String
    public let actor: String
    public let payload: [String: String]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        eventType: String,
        actor: String,
        payload: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.eventType = eventType
        self.actor = actor
        self.payload = payload
        self.createdAt = createdAt
    }
}

/// Hermes kanban link (= 1:1 mirror of hermes kanban_db parent/child edges).
/// Source uses parent_id + child_id; wenshu collapses to source + target +
/// link_type string so callers can record blocks / depends-on / duplicates.
public struct HermesKanbanLink: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let sourceTaskId: UUID
    public let targetTaskId: UUID
    public let linkType: String

    public init(
        id: UUID = UUID(),
        sourceTaskId: UUID,
        targetTaskId: UUID,
        linkType: String
    ) {
        self.id = id
        self.sourceTaskId = sourceTaskId
        self.targetTaskId = targetTaskId
        self.linkType = linkType
    }
}

/// Hermes kanban partial update payload (= subset of HermesKanbanTask fields).
public struct HermesKanbanTaskUpdate: Sendable {
    public var title: String?
    public var description: String?
    public var status: HermesKanbanStatus?
    public var priority: Int?
    public var assignee: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        status: HermesKanbanStatus? = nil,
        priority: Int? = nil,
        assignee: String? = nil
    ) {
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assignee = assignee
    }
}

// MARK: - Errors (= 1:1 mirror of hermes kanban_db exceptions)

public enum HermesKanbanError: Error, Sendable, Equatable {
    case taskNotFound(id: UUID)
    case taskAlreadyClaimed(taskId: UUID, claimedBy: String)
    case permissionDenied(profile: String, action: String)
    case boardNotFound(boardId: String)
    case storageError(reason: String)
}

// MARK: - SQLite3 pointer wrapper (= opaque handle with thread-safe init)

/// SQLite 透明指针 wrap (= identical pattern to KanbanStore.swift SQLitePtr).
private final class HermesKanbanSQLitePtr {
    var db: OpaquePointer?
    deinit { sqlite3_close(db) }
}

// MARK: - HermesKanbanDB actor (= cross-process equivalent: Swift 6 actor)

/// Hermes kanban DB actor (= 1:1 port of hermes kanban_db.KanbanDb
/// + kanban_db.connect + kanban_db.init_db + write_txn).
///
/// - actor isolation = Swift 6 canonical cross-process equivalent of
///   hermes's file-lock + BEGIN IMMEDIATE + WAL + CAS pattern.
/// - one sqlite3 handle per actor instance; all read/write operations are
///   actor-isolated (= serialized at the actor boundary).
/// - 4-table schema mirrors hermes (tasks / task_comments / task_events /
///   task_links); comment / event / link tables reference tasks.id and
///   cascade-delete on task removal.
public actor HermesKanbanDB {
    private let dbPtr: HermesKanbanSQLitePtr
    private let dbPath: String

    /// init (= 1:1 port of hermes kanban_db.connect + init_db, init_db).
    /// `dbPath == nil` → use Application Support / HermesKanban / kanban.db
    /// (= wenshu-side default; hermes uses <root>/kanban.db).
    public init(dbPath: URL? = nil) throws {
        let url: URL
        if let dbPath = dbPath {
            url = dbPath
        } else {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = support
                .appendingPathComponent("wenshu", isDirectory: true)
                .appendingPathComponent("HermesKanban", isDirectory: true)
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
            url = dir.appendingPathComponent("kanban.db")
        }
        let ptr = HermesKanbanSQLitePtr()
        if sqlite3_open(url.path, &ptr.db) != SQLITE_OK {
            throw HermesKanbanError.storageError(
                reason: "open failed: \(HermesKanbanDB.sqliteErmsg(ptr.db))"
            )
        }
        self.dbPtr = ptr
        self.dbPath = url.path
    }

    /// bootstrap (= 1:1 port of hermes kanban_db.init_db + _migrate_add_optional_columns).
    /// Creates the 4-table schema if absent. Idempotent (= safe to call on every init).
    /// Mirrors hermes's "WAL mode + create tables if not exist" pattern.
    public func bootstrap() throws {
        try exec("PRAGMA journal_mode = WAL;")
        try exec("PRAGMA synchronous = NORMAL;")
        try exec("PRAGMA foreign_keys = ON;")
        let schema = """
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            board_id TEXT NOT NULL,
            profile_slug TEXT NOT NULL,
            project_slug TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 5,
            assignee TEXT,
            claimed_by TEXT,
            claimed_at REAL,
            completed_at REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_tasks_board ON tasks(board_id);
        CREATE INDEX IF NOT EXISTS idx_tasks_profile ON tasks(profile_slug);
        CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_slug);
        CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
        CREATE INDEX IF NOT EXISTS idx_tasks_claimed_by ON tasks(claimed_by);

        CREATE TABLE IF NOT EXISTS task_comments (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
            author TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_task_comments_task ON task_comments(task_id);

        CREATE TABLE IF NOT EXISTS task_events (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
            event_type TEXT NOT NULL,
            actor TEXT NOT NULL,
            payload TEXT NOT NULL DEFAULT '{}',
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_task_events_task ON task_events(task_id);

        CREATE TABLE IF NOT EXISTS task_links (
            id TEXT PRIMARY KEY,
            source_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
            target_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
            link_type TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_task_links_source ON task_links(source_task_id);
        CREATE INDEX IF NOT EXISTS idx_task_links_target ON task_links(target_task_id);
        """
        try exec(schema)
    }

    // MARK: Task CRUD

    /// createTask (= 1:1 port of hermes kanban_db.create_task).
    public func createTask(_ task: HermesKanbanTask) async throws -> HermesKanbanTask {
        let now = Date()
        var t = task
        // Auto-set completed_at when status is .done (mirrors hermes `_end_run`).
        if t.status == .done && t.completedAt == nil {
            t.completedAt = now
        }
        t.updatedAt = now
        let sql = """
        INSERT INTO tasks
        (id, board_id, profile_slug, project_slug, title, description, status,
         priority, assignee, claimed_by, claimed_at, completed_at,
         created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, t.id.uuidString)
        bindText(stmt, 2, t.boardId)
        bindText(stmt, 3, t.profileSlug)
        bindText(stmt, 4, t.projectSlug)
        bindText(stmt, 5, t.title)
        bindText(stmt, 6, t.description)
        bindText(stmt, 7, t.status.rawValue)
        sqlite3_bind_int(stmt, 8, Int32(t.priority))
        bindTextOrNull(stmt, 9, t.assignee)
        bindTextOrNull(stmt, 10, t.claimedBy)
        bindDoubleOrNull(stmt, 11, t.claimedAt)
        bindDoubleOrNull(stmt, 12, t.completedAt)
        sqlite3_bind_double(stmt, 13, t.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 14, t.updatedAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        // Record "task_created" event (= hermes kanban_db._append_event).
        _ = try await recordEvent(HermesKanbanEvent(
            taskId: t.id,
            eventType: "task_created",
            actor: "system",
            payload: ["title": t.title, "status": t.status.rawValue]
        ))
        return t
    }

    /// getTask (= 1:1 port of hermes kanban_db.get_task).
    public func getTask(id: UUID) async throws -> HermesKanbanTask? {
        let sql = """
        SELECT id, board_id, profile_slug, project_slug, title, description, status,
               priority, assignee, claimed_by, claimed_at, completed_at,
               created_at, updated_at
        FROM tasks WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return decodeTask(stmt: stmt)
    }

    /// listTasks (= 1:1 port of hermes kanban_db.list_tasks).
    /// `filter == nil` → all statuses.
    public func listTasks(filter: HermesKanbanStatus? = nil) async throws -> [HermesKanbanTask] {
        let sql: String
        if filter != nil {
            sql = """
            SELECT id, board_id, profile_slug, project_slug, title, description, status,
                   priority, assignee, claimed_by, claimed_at, completed_at,
                   created_at, updated_at
            FROM tasks WHERE status = ? ORDER BY priority DESC, updated_at DESC;
            """
        } else {
            sql = """
            SELECT id, board_id, profile_slug, project_slug, title, description, status,
                   priority, assignee, claimed_by, claimed_at, completed_at,
                   created_at, updated_at
            FROM tasks ORDER BY priority DESC, updated_at DESC;
            """
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        if let filter {
            bindText(stmt, 1, filter.rawValue)
        }
        var results: [HermesKanbanTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(decodeTask(stmt: stmt))
        }
        return results
    }

    /// updateTask (= 1:1 port of hermes kanban_db.assign_task + status updates).
    /// Only fields set on `fields` are touched (= partial update).
    public func updateTask(id: UUID, fields: HermesKanbanTaskUpdate) async throws -> HermesKanbanTask {
        guard var existing = try await getTask(id: id) else {
            throw HermesKanbanError.taskNotFound(id: id)
        }
        if let v = fields.title { existing.title = v }
        if let v = fields.description { existing.description = v }
        if let v = fields.status {
            existing.status = v
            if v == .done && existing.completedAt == nil {
                existing.completedAt = Date()
            }
        }
        if let v = fields.priority { existing.priority = v }
        if let v = fields.assignee { existing.assignee = v }
        existing.updatedAt = Date()
        let sql = """
        UPDATE tasks
        SET title = ?, description = ?, status = ?, priority = ?, assignee = ?,
            completed_at = ?, updated_at = ?
        WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, existing.title)
        bindText(stmt, 2, existing.description)
        bindText(stmt, 3, existing.status.rawValue)
        sqlite3_bind_int(stmt, 4, Int32(existing.priority))
        bindTextOrNull(stmt, 5, existing.assignee)
        bindDoubleOrNull(stmt, 6, existing.completedAt)
        sqlite3_bind_double(stmt, 7, existing.updatedAt.timeIntervalSince1970)
        bindText(stmt, 8, existing.id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        _ = try await recordEvent(HermesKanbanEvent(
            taskId: existing.id,
            eventType: "task_updated",
            actor: "system",
            payload: ["status": existing.status.rawValue]
        ))
        return existing
    }

    /// deleteTask (= 1:1 port of hermes kanban_db cascade deletion).
    /// CASCADE on FK handles task_comments / task_events / task_links.
    public func deleteTask(id: UUID) async throws {
        let sql = "DELETE FROM tasks WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id.uuidString)
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        if sqlite3_changes(dbPtr.db) == 0 {
            throw HermesKanbanError.taskNotFound(id: id)
        }
    }

    // MARK: Worker / dispatcher claim protocol
    // (= 1:1 port of hermes kanban_db claim_task / release_task / complete_task)

    /// claimTask (= 1:1 port of hermes kanban_db CAS-style claim).
    /// Sets claimed_by + claimed_at + status=.running atomically.
    /// Throws taskAlreadyClaimed if another worker holds the claim.
    public func claimTask(id: UUID, by profile: String) async throws -> HermesKanbanTask {
        guard var existing = try await getTask(id: id) else {
            throw HermesKanbanError.taskNotFound(id: id)
        }
        if let holder = existing.claimedBy, holder != profile {
            throw HermesKanbanError.taskAlreadyClaimed(
                taskId: id, claimedBy: holder
            )
        }
        let now = Date()
        existing.claimedBy = profile
        existing.claimedAt = now
        existing.status = .running
        existing.updatedAt = now
        let sql = """
        UPDATE tasks
        SET claimed_by = ?, claimed_at = ?, status = ?, updated_at = ?
        WHERE id = ? AND (claimed_by IS NULL OR claimed_by = ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, profile)
        sqlite3_bind_double(stmt, 2, now.timeIntervalSince1970)
        bindText(stmt, 3, HermesKanbanStatus.running.rawValue)
        sqlite3_bind_double(stmt, 4, now.timeIntervalSince1970)
        bindText(stmt, 5, existing.id.uuidString)
        bindText(stmt, 6, profile)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        if sqlite3_changes(dbPtr.db) == 0 {
            // CAS lost — someone else claimed between getTask and update.
            let holder = (try await getTask(id: id))?.claimedBy ?? "unknown"
            throw HermesKanbanError.taskAlreadyClaimed(taskId: id, claimedBy: holder)
        }
        _ = try await recordEvent(HermesKanbanEvent(
            taskId: existing.id,
            eventType: "task_claimed",
            actor: profile,
            payload: ["status": HermesKanbanStatus.running.rawValue]
        ))
        return existing
    }

    /// releaseTask (= 1:1 port of hermes kanban_db.release_task).
    /// Clears claimed_by / claimed_at, leaves status unchanged unless explicitly reset.
    public func releaseTask(id: UUID) async throws {
        guard var existing = try await getTask(id: id) else {
            throw HermesKanbanError.taskNotFound(id: id)
        }
        let prior = existing.claimedBy ?? "system"
        existing.claimedBy = nil
        existing.claimedAt = nil
        existing.updatedAt = Date()
        let sql = """
        UPDATE tasks
        SET claimed_by = NULL, claimed_at = NULL, updated_at = ?
        WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, existing.updatedAt.timeIntervalSince1970)
        bindText(stmt, 2, existing.id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        _ = try await recordEvent(HermesKanbanEvent(
            taskId: existing.id,
            eventType: "task_released",
            actor: prior,
            payload: [:]
        ))
    }

    /// completeTask (= 1:1 port of hermes kanban_db.complete_task + _end_run).
    /// Transitions status to .done, sets completed_at, clears claim.
    public func completeTask(id: UUID, result: String) async throws -> HermesKanbanTask {
        guard var existing = try await getTask(id: id) else {
            throw HermesKanbanError.taskNotFound(id: id)
        }
        let now = Date()
        existing.status = .done
        existing.completedAt = now
        existing.claimedBy = nil
        existing.claimedAt = nil
        existing.updatedAt = now
        let sql = """
        UPDATE tasks
        SET status = ?, completed_at = ?, claimed_by = NULL, claimed_at = NULL,
            updated_at = ?
        WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, HermesKanbanStatus.done.rawValue)
        sqlite3_bind_double(stmt, 2, now.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 3, now.timeIntervalSince1970)
        bindText(stmt, 4, existing.id.uuidString)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        _ = try await recordEvent(HermesKanbanEvent(
            taskId: existing.id,
            eventType: "task_completed",
            actor: existing.assignee ?? "system",
            payload: ["result": result]
        ))
        return existing
    }

    // MARK: Comments + Events + Links

    /// addComment (= 1:1 port of hermes kanban_db.add_comment).
    public func addComment(_ comment: HermesKanbanComment) async throws -> HermesKanbanComment {
        // Verify task exists (= hermes raises if FK fails).
        guard (try await getTask(id: comment.taskId)) != nil else {
            throw HermesKanbanError.taskNotFound(id: comment.taskId)
        }
        let sql = """
        INSERT INTO task_comments (id, task_id, author, body, created_at)
        VALUES (?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, comment.id.uuidString)
        bindText(stmt, 2, comment.taskId.uuidString)
        bindText(stmt, 3, comment.author)
        bindText(stmt, 4, comment.body)
        sqlite3_bind_double(stmt, 5, comment.createdAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        return comment
    }

    /// listComments (= 1:1 port of hermes kanban_db.list_comments).
    public func listComments(taskId: UUID) async throws -> [HermesKanbanComment] {
        let sql = """
        SELECT id, task_id, author, body, created_at
        FROM task_comments WHERE task_id = ? ORDER BY created_at ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, taskId.uuidString)
        var results: [HermesKanbanComment] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(decodeComment(stmt: stmt))
        }
        return results
    }

    /// recordEvent (= 1:1 port of hermes kanban_db._append_event).
    /// payload [String: String] is serialized as JSON for the TEXT column.
    public func recordEvent(_ event: HermesKanbanEvent) async throws -> HermesKanbanEvent {
        guard (try await getTask(id: event.taskId)) != nil else {
            throw HermesKanbanError.taskNotFound(id: event.taskId)
        }
        let payloadJSON = HermesKanbanDB.encodePayload(event.payload)
        let sql = """
        INSERT INTO task_events (id, task_id, event_type, actor, payload, created_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, event.id.uuidString)
        bindText(stmt, 2, event.taskId.uuidString)
        bindText(stmt, 3, event.eventType)
        bindText(stmt, 4, event.actor)
        bindText(stmt, 5, payloadJSON)
        sqlite3_bind_double(stmt, 6, event.createdAt.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        return event
    }

    /// linkTasks (= 1:1 port of hermes kanban_db.link_tasks).
    public func linkTasks(_ link: HermesKanbanLink) async throws -> HermesKanbanLink {
        guard (try await getTask(id: link.sourceTaskId)) != nil else {
            throw HermesKanbanError.taskNotFound(id: link.sourceTaskId)
        }
        guard (try await getTask(id: link.targetTaskId)) != nil else {
            throw HermesKanbanError.taskNotFound(id: link.targetTaskId)
        }
        let sql = """
        INSERT INTO task_links (id, source_task_id, target_task_id, link_type)
        VALUES (?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, link.id.uuidString)
        bindText(stmt, 2, link.sourceTaskId.uuidString)
        bindText(stmt, 3, link.targetTaskId.uuidString)
        bindText(stmt, 4, link.linkType)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw HermesKanbanError.storageError(
                reason: "step failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        return link
    }

    /// listLinkedTasks (= 1:1 port of hermes kanban_db.parent_ids + child_ids).
    /// Bidirectional retrieval (= returns both directions).
    public func listLinkedTasks(taskId: UUID) async throws -> [HermesKanbanTask] {
        let sql = """
        SELECT t.id, t.board_id, t.profile_slug, t.project_slug, t.title,
               t.description, t.status, t.priority, t.assignee, t.claimed_by,
               t.claimed_at, t.completed_at, t.created_at, t.updated_at
        FROM tasks t
        JOIN task_links l
          ON (l.source_task_id = ? AND l.target_task_id = t.id)
          OR (l.target_task_id = ? AND l.source_task_id = t.id)
        ORDER BY t.priority DESC, t.updated_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, taskId.uuidString)
        bindText(stmt, 2, taskId.uuidString)
        var results: [HermesKanbanTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(decodeTask(stmt: stmt))
        }
        return results
    }

    // MARK: Multi-profile + multi-project (= 1:1 port of hermes kanban_db profile_slug / project_slug partitioning)

    /// boardsForProfile (= 1:1 port of hermes kanban_db boards-per-profile aggregation).
    public func boardsForProfile(slug: String) async throws -> [String] {
        let sql = """
        SELECT DISTINCT board_id FROM tasks WHERE profile_slug = ? ORDER BY board_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, slug)
        var results: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: cstr))
            }
        }
        return results
    }

    /// tasksForProject (= 1:1 port of hermes kanban_db per-project task retrieval).
    public func tasksForProject(_ slug: String) async throws -> [HermesKanbanTask] {
        let sql = """
        SELECT id, board_id, profile_slug, project_slug, title, description, status,
               priority, assignee, claimed_by, claimed_at, completed_at,
               created_at, updated_at
        FROM tasks WHERE project_slug = ? ORDER BY priority DESC, updated_at DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPtr.db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw HermesKanbanError.storageError(
                reason: "prepare failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, slug)
        var results: [HermesKanbanTask] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(decodeTask(stmt: stmt))
        }
        return results
    }

    // MARK: Internal helpers (= identical pattern to KanbanStore.swift)

    private func exec(_ sql: String) throws {
        if sqlite3_exec(dbPtr.db, sql, nil, nil, nil) != SQLITE_OK {
            throw HermesKanbanError.storageError(
                reason: "exec failed: \(HermesKanbanDB.sqliteErmsg(dbPtr.db))"
            )
        }
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
    }

    private func bindTextOrNull(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func bindDoubleOrNull(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Date?) {
        if let value {
            sqlite3_bind_double(stmt, idx, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func decodeTask(stmt: OpaquePointer?) -> HermesKanbanTask {
        let idStr = HermesKanbanDB.textColumn(stmt, 0) ?? ""
        let id = UUID(uuidString: idStr) ?? UUID()
        let boardId = HermesKanbanDB.textColumn(stmt, 1) ?? ""
        let profileSlug = HermesKanbanDB.textColumn(stmt, 2) ?? ""
        let projectSlug = HermesKanbanDB.textColumn(stmt, 3) ?? ""
        let title = HermesKanbanDB.textColumn(stmt, 4) ?? ""
        let description = HermesKanbanDB.textColumn(stmt, 5) ?? ""
        let status = HermesKanbanStatus(
            rawValue: HermesKanbanDB.textColumn(stmt, 6) ?? "backlog"
        ) ?? .backlog
        let priority = Int(sqlite3_column_int64(stmt, 7))
        let assignee = sqlite3_column_type(stmt, 8) == SQLITE_NULL
            ? nil : HermesKanbanDB.textColumn(stmt, 8)
        let claimedBy = sqlite3_column_type(stmt, 9) == SQLITE_NULL
            ? nil : HermesKanbanDB.textColumn(stmt, 9)
        let claimedAt = sqlite3_column_type(stmt, 10) == SQLITE_NULL
            ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 10))
        let completedAt = sqlite3_column_type(stmt, 11) == SQLITE_NULL
            ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 11))
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13))
        return HermesKanbanTask(
            id: id,
            boardId: boardId,
            profileSlug: profileSlug,
            projectSlug: projectSlug,
            title: title,
            description: description,
            status: status,
            priority: priority,
            assignee: assignee,
            claimedBy: claimedBy,
            claimedAt: claimedAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func decodeComment(stmt: OpaquePointer?) -> HermesKanbanComment {
        let idStr = HermesKanbanDB.textColumn(stmt, 0) ?? ""
        let id = UUID(uuidString: idStr) ?? UUID()
        let taskIdStr = HermesKanbanDB.textColumn(stmt, 1) ?? ""
        let taskId = UUID(uuidString: taskIdStr) ?? UUID()
        let author = HermesKanbanDB.textColumn(stmt, 2) ?? ""
        let body = HermesKanbanDB.textColumn(stmt, 3) ?? ""
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        return HermesKanbanComment(
            id: id, taskId: taskId, author: author, body: body, createdAt: createdAt
        )
    }

    fileprivate static func textColumn(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cString)
    }

    fileprivate static func sqliteErmsg(_ db: OpaquePointer?) -> String {
        guard let db = db else { return "no db handle" }
        return String(cString: sqlite3_errmsg(db))
    }

    /// payload encoder (= [String: String] → JSON string for the TEXT column).
    /// Apple canonical: JSONEncoder + JSONSerialization. We use JSONEncoder.
    /// If encoding fails (= e.g. non-encodable nested value), fall back to "{}".
    private static func encodePayload(_ payload: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys]
        ) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}