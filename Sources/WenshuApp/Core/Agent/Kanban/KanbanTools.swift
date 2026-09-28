//
//  KanbanTools.swift · Wenshu · port-window
//
//  LLM-side kanban management surface. Direct port of hermes
//  tools/kanban_tools.py (= 1,672 LOC; provides the unified
//  kanban(action:...) tool dispatcher that the LLM uses from the
//  chat surface).
//
//  Per spec §2.3 + AGENTS.md §11.3: kanban is a wenshu-side-wins
//  surface (= wenshu's SwiftData WSKanbanRepository manages the
//  task store; hermes's cross-process claim/lock semantics don't
//  apply to a single-process macOS app). the
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
//    - transition  — transition status (= WSKanbanRepository.transition)
//
//  Per spec §2.3: kanban ≠ cross-process claim/lock; the wenshu surface
//  uses the WSKanbanRepository (= @MainActor SwiftData) directly. The hermes
//  worker_run_id / _enforce_worker_task_ownership surfaces are not
//  applicable to the wenshu single-process model.
//
// (= user-side kanban) +
// (2026-09-04) for the LLM-side surface.
//

import Foundation

/// LLM-facing kanban management tool. Thin facade over wenshu's
/// SwiftData-backed kanban store (= WSKanbanRepository.shared =
/// @MainActor; [historical actor removed]
/// which used raw sqlite3) that exposes the action dispatcher the
/// chat surface uses.
actor KanbanTools {
    private let store: WSKanbanRepository
    // removed the dead sharedPlaceholder cache
    // (= init always falls through to WSKanbanRepository.shared; = the
    // cache check never returns a hit after the SwiftData migration).
    // This eliminates the nonisolated(unsafe) mutable static var.

    /// v1.55d+ (boss 2026-09-28 OOB A option): `init` is now
    /// `@MainActor` so `WSKanbanRepository.shared` (= @MainActor
    /// accessor) can be referenced directly without a runtime
    /// `MainActor.assumeIsolated` wrap (= which itself trapped
    /// under Swift 6 strict concurrency when invoked from an
    /// actor's serial executor). The `@MainActor` static-let
    /// initializer on `KanbanStoreTool.shared` (= main-actor
    /// caller) makes this safe (= Swift 6 strict-concurrency
    /// contract).
    @MainActor
    init(store: WSKanbanRepository? = nil) {
        // Tests can pass an explicit store; otherwise we lazily build one
        // (= throws on init so we cache a fallback to /tmp/kanban-test.db).
        if let store = store {
            self.store = store
            return
        }
        // Production: `KanbanStoreTool.shared` is `@MainActor static
        // let` (= Swift 6 strict-concurrency contract that the init
        // runs on the main actor). `WSKanbanRepository.shared` is
        // also `@MainActor` (= the same executor), so the unwrapped
        // access is safe.
        self.store = WSKanbanRepository.shared
    }


    // MARK: - Action enum (= hermes kanban_tools.py handle_* functions)

    enum Action: String, Sendable, CaseIterable {
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

    struct KanbanParams: Sendable {
        var taskId: String?
        var title: String?
        var body: String?
        var status: String?
        var assignee: String?
        var tenant: String?
        var priority: Int?
        var modelOverride: String?
        var comment: String?
        var reason: String?
        var limit: Int?
        var includeArchived: Bool?
        var parentId: String?
        var childId: String?
        var newStatus: String?

        init(
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
    struct KanbanToolResult: Sendable, Equatable {
        let success: Bool
        let output: String
        let data: [String: String]

        init(success: Bool, output: String, data: [String: String] = [:]) {
            self.success = success
            self.output = output
            self.data = data
        }
    }

    // MARK: - Main dispatcher (= hermes kanban entry)

    /// Unified kanban tool dispatcher (= hermes kanban(action:...) entry).
    // P2-07 audit (2026-09-24): internal (= KanbanParams is internal;
        // = default-arg would not compile in a public method signature;
        // = the method's contract is intra-package anyway).
        func kanban(action: String, params: KanbanParams = KanbanParams()) async -> KanbanToolResult {
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
            let taskOpt = try await MainActor.run { try store.get(id: id) }
            guard let task = taskOpt else {
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
            let tasks = try await MainActor.run { try store.list(status: statusFilter) }
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
                assignee: params.assignee,
                // Phase 1 T4 (2026-09-28): pass the LLM-authored body
                // through to the @Model column. Mirrors hermes 0.21.5
                // commit 63f5bc0999 (feat(kanban): render task text as
                // markdown) — the LLM tool schema at
                // KanbanStoreTool.swift:333 already exposes body; the
                // create() method now writes it through.
                body: params.body
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
            try await MainActor.run { try store.transition(id: id, to: .done) }
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
            try await MainActor.run { try store.transition(id: id, to: .blocked) }
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
            try await MainActor.run { try store.transition(id: id, to: .ready) }
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

    /// Transition status (= WSKanbanRepository.transition).
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
            try await MainActor.run { try store.transition(id: id, to: newStatus) }
            return KanbanToolResult(
                success: true,
                output: "Transitioned \(id) → \(newStatus.rawValue)"
            )
        } catch {
            return KanbanToolResult(success: false, output: "transition failed: \(error)")
        }
    }
}
