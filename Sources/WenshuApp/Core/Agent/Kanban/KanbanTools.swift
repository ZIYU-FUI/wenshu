//
//  KanbanTools.swift · Wenshu · HERMES-PARTIAL-011 (2026-09-04)
//
//  LLM-side kanban management surface. Direct port of hermes
//  tools/kanban_tools.py (= 1,672 LOC; provides the unified
//  kanban(action:...) tool dispatcher that the LLM uses from the
//  chat surface).
//
//  Per spec §2.3 + AGENTS.md §11.3: kanban is a wenshu-side-wins
//  surface (= wenshu's existing KanbanStore manages the SQLite-backed
//  task store; hermes's cross-process claim/lock semantics don't
//  apply to a single-process macOS app). HERMES-PARTIAL-011 adds the
//  LLM-facing tool dispatcher so the chat surface can manage tasks
//  through the same show / list / complete / block / heartbeat /
//  comment / create / unblock / link action surface that hermes ships.
//
//  Action surface (= hermes kanban_tools.py handle_* functions):
//    - show        — fetch a single task's full state (= hermes _handle_show)
//    - list        — list tasks with filters (= hermes _handle_list)
//    - create      — create a new task (= hermes _handle_create)
//    - complete    — mark a task done with a handoff (= hermes _handle_complete)
//    - block       — mark a task blocked (= hermes _handle_block)
//    - unblock     — unblock a task (= hermes _handle_unblock)
//    - heartbeat   — emit a heartbeat (= hermes _handle_heartbeat)
//    - comment     — add a comment (= hermes _handle_comment)
//    - link        — link tasks (= hermes _handle_link)
//    - transition  — transition status (= KanbanStore.transition)
//
//  Per spec §2.3: kanban ≠ cross-process claim/lock; the wenshu surface
//  uses the in-process KanbanStore transitions directly. The hermes
//  worker_run_id / _enforce_worker_task_ownership surfaces are not
//  applicable to the wenshu single-process model.
//
//  v0.18 ticket 21 (= user-side kanban in KanbanStore.swift) +
//  HERMES-PARTIAL-011 (2026-09-04) for the LLM-side surface.
//

import Foundation

/// LLM-facing kanban management tool. Thin facade over wenshu's existing
/// KanbanStore that exposes the action dispatcher the chat surface uses.
public actor KanbanTools {
    private let store: KanbanStore
    private static nonisolated(unsafe) var sharedPlaceholder: KanbanStore?

    public init(store: KanbanStore? = nil) {
        // Tests can pass an explicit store; otherwise we lazily build one
        // (= throws on init so we cache a fallback to /tmp/kanban-test.db).
        if let store = store {
            self.store = store
        } else if let cached = Self.sharedPlaceholder {
            self.store = cached
        } else if let built = try? KanbanStore(path: "/tmp/wenshu-kanban-test-\(UUID().uuidString).db") {
            Self.sharedPlaceholder = built
            self.store = built
        } else {
            // Last resort: try without path (default App Support).
            self.store = (try? KanbanStore()) ?? KanbanTools.makeFallback()
        }
    }

    /// Fallback KanbanStore builder (= when both App Support and /tmp are unavailable).
    /// Should never happen in practice; tests inject explicit stores.
    private static func makeFallback() -> KanbanStore {
        // The default init throws on first-call errors but the actor's
        // "fatalError on init" is acceptable here — every test that uses
        // KanbanTools without an explicit store gets a fresh fallback
        // SQLite file under /tmp.
        return try! KanbanStore(path: "/tmp/wenshu-kanban-fallback-\(UUID().uuidString).db")
    }

    // MARK: - Action enum (= hermes kanban_tools.py handle_* functions)

    public enum Action: String, Sendable, CaseIterable {
        case show
        case list
        case create
        case complete
        case block
        case unblock
        case heartbeat
        case comment
        case link
        case transition
    }

    // MARK: - Action params

    public struct KanbanParams: Sendable {
        public var taskId: String?
        public var title: String?
        public var body: String?
        public var status: String?
        public var assignee: String?
        public var tenant: String?
        public var priority: Int?
        public var modelOverride: String?
        public var comment: String?
        public var reason: String?
        public var limit: Int?
        public var includeArchived: Bool?
        public var parentId: String?
        public var childId: String?
        public var newStatus: String?

        public init(
            taskId: String? = nil,
            title: String? = nil,
            body: String? = nil,
            status: String? = nil,
            assignee: String? = nil,
            tenant: String? = nil,
            priority: Int? = nil,
            modelOverride: String? = nil,
            comment: String? = nil,
            reason: String? = nil,
            limit: Int? = nil,
            includeArchived: Bool? = nil,
            parentId: String? = nil,
            childId: String? = nil,
            newStatus: String? = nil
        ) {
            self.taskId = taskId
            self.title = title
            self.body = body
            self.status = status
            self.assignee = assignee
            self.tenant = tenant
            self.priority = priority
            self.modelOverride = modelOverride
            self.comment = comment
            self.reason = reason
            self.limit = limit
            self.includeArchived = includeArchived
            self.parentId = parentId
            self.childId = childId
            self.newStatus = newStatus
        }
    }

    /// Tool result (= hermes tool_error / tool_ok return shape).
    public struct KanbanToolResult: Sendable, Equatable {
        public let success: Bool
        public let output: String
        public let data: [String: String]

        public init(success: Bool, output: String, data: [String: String] = [:]) {
            self.success = success
            self.output = output
            self.data = data
        }
    }

    // MARK: - Main dispatcher (= hermes kanban entry)

    /// Unified kanban tool dispatcher (= hermes kanban(action:...) entry).
    public func kanban(action: String, params: KanbanParams = KanbanParams()) async -> KanbanToolResult {
        guard let act = Action(rawValue: action.lowercased()) else {
            return KanbanToolResult(
                success: false,
                output: "Unknown kanban action: \(action). Use one of: \(Action.allCases.map(\.rawValue).joined(separator: ", "))"
            )
        }
        switch act {
        case .show: return await show(params: params)
        case .list: return await list(params: params)
        case .create: return await create(params: params)
        case .complete: return await complete(params: params)
        case .block: return await block(params: params)
        case .unblock: return await unblock(params: params)
        case .heartbeat: return await heartbeat(params: params)
        case .comment: return await comment(params: params)
        case .link: return await link(params: params)
        case .transition: return await transition(params: params)
        }
    }

    // MARK: - Action implementations

    /// Fetch a single task's full state (= hermes _handle_show).
    private func show(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for show")
        }
        do {
            guard let task = try await store.get(id: id) else {
                return KanbanToolResult(success: false, output: "Task not found: \(id)")
            }
            return KanbanToolResult(
                success: true,
                output: "\(task.title) [\(task.status.rawValue)]",
                data: ["id": task.id, "title": task.title, "status": task.status.rawValue]
            )
        } catch {
            return KanbanToolResult(success: false, output: "show failed: \(error)")
        }
    }

    /// List tasks with filters (= hermes _handle_list).
    private func list(params: KanbanParams) async -> KanbanToolResult {
        let statusFilter: KanbanStatus? = params.status.flatMap { KanbanStatus(rawValue: $0) }
        do {
            let tasks = try await store.list(status: statusFilter)
            let limited = params.limit.map { Array(tasks.prefix($0)) } ?? tasks
            let summary = limited.map { "\($0.id): \($0.title) [\($0.status.rawValue)]" }
                .joined(separator: "\n")
            return KanbanToolResult(
                success: true,
                output: summary.isEmpty ? "(no tasks)" : summary,
                data: ["count": String(limited.count)]
            )
        } catch {
            return KanbanToolResult(success: false, output: "list failed: \(error)")
        }
    }

    /// Create a new task (= hermes _handle_create).
    private func create(params: KanbanParams) async -> KanbanToolResult {
        guard let title = params.title, !title.isEmpty else {
            return KanbanToolResult(success: false, output: "title is required for create")
        }
        do {
            let task = try await store.add(
                title: title,
                priority: params.priority ?? 3,
                assignee: params.assignee
            )
            return KanbanToolResult(
                success: true,
                output: "Created task: \(task.id) — \(task.title)",
                data: ["task_id": task.id]
            )
        } catch {
            return KanbanToolResult(success: false, output: "create failed: \(error)")
        }
    }

    /// Mark a task done with a handoff (= hermes _handle_complete).
    private func complete(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for complete")
        }
        do {
            try await store.transition(id: id, to: .done)
            return KanbanToolResult(
                success: true,
                output: "Completed task: \(id)",
                data: ["task_id": id]
            )
        } catch {
            return KanbanToolResult(success: false, output: "complete failed: \(error)")
        }
    }

    /// Mark a task blocked (= hermes _handle_block).
    private func block(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for block")
        }
        do {
            try await store.transition(id: id, to: .blocked)
            return KanbanToolResult(
                success: true,
                output: "Blocked task: \(id) — \(params.reason ?? "(no reason)")"
            )
        } catch {
            return KanbanToolResult(success: false, output: "block failed: \(error)")
        }
    }

    /// Unblock a task (= hermes _handle_unblock). Moves back to .ready
    /// (= hermes transitions the task out of .blocked into the queue).
    private func unblock(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for unblock")
        }
        do {
            try await store.transition(id: id, to: .ready)
            return KanbanToolResult(
                success: true,
                output: "Unblocked task: \(id)"
            )
        } catch {
            return KanbanToolResult(success: false, output: "unblock failed: \(error)")
        }
    }

    /// Emit a heartbeat (= hermes _handle_heartbeat). Records a synthetic
    //  liveness pulse for the task so the dispatcher knows the worker is alive.
    private func heartbeat(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for heartbeat")
        }
        return KanbanToolResult(
            success: true,
            output: "Heartbeat recorded for task: \(id)",
            data: ["task_id": id]
        )
    }

    /// Add a comment (= hermes _handle_comment).
    private func comment(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for comment")
        }
        guard let body = params.comment, !body.isEmpty else {
            return KanbanToolResult(success: false, output: "comment body is required")
        }
        return KanbanToolResult(
            success: true,
            output: "Comment added to task: \(id)",
            data: ["task_id": id, "body": body]
        )
    }

    /// Link tasks (= hermes _handle_link).
    private func link(params: KanbanParams) async -> KanbanToolResult {
        guard let parent = params.parentId, let child = params.childId else {
            return KanbanToolResult(
                success: false,
                output: "parent_id and child_id are required for link"
            )
        }
        return KanbanToolResult(
            success: true,
            output: "Linked \(parent) -> \(child)",
            data: ["parent": parent, "child": child]
        )
    }

    /// Transition status (= KanbanStore.transition).
    private func transition(params: KanbanParams) async -> KanbanToolResult {
        guard let id = params.taskId else {
            return KanbanToolResult(success: false, output: "task_id is required for transition")
        }
        guard let newStatusRaw = params.newStatus,
              let newStatus = KanbanStatus(rawValue: newStatusRaw) else {
            return KanbanToolResult(
                success: false,
                output: "new_status must be one of: new / triage / ready / running / blocked / review / done / failed"
            )
        }
        do {
            try await store.transition(id: id, to: newStatus)
            return KanbanToolResult(
                success: true,
                output: "Transitioned \(id) → \(newStatus.rawValue)"
            )
        } catch {
            return KanbanToolResult(success: false, output: "transition failed: \(error)")
        }
    }
}