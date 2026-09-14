//
//  Core/Kanban/KanbanDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 6
//
//  Domain types (KanbanStatus + KanbanTask) extracted from the deleted
//  Core/Kanban/KanbanStore.swift (= sqlite3 legacy actor, now obsolete).
//
//  These types are the canonical wenshu-side public API surface for
//  kanban tickets. The SwiftData-backed persistence lives in
//  Persistence/WSKanbanTask (@Model) and is wrapped by
//  Persistence/Repositories/WSKanbanRepository (@MainActor). The actor
//  that dispatches the LLM-facing kanban tool lives in
//  Core/Agent/Kanban/KanbanTools.swift.
//
//  Moved 2026-09-13 (= phase 5 ticket 6 — see AGENTS.md §11.4.2).
//

import Foundation

/// Kanban task status (= hermes kanban state machine: new → triage → ready → running → blocked → review → done; = wenshu also adds .failed per v0.23 ticket 013.003)
public enum KanbanStatus: String, Codable, Sendable, CaseIterable {
    case new
    case triage
    case ready
    case running
    case blocked
    case review
    case done
    case failed  // wenshu +1 status (hermes → blocked, wenshu failed)
}

/// Kanban task
/// v0.23 ticket 013.003: extended with hermes-style metadata
/// (priority / assignee / started_at / completed_at / model_override).
public struct KanbanTask: Equatable, Sendable {
    public let id: String
    public var title: String
    public var status: KanbanStatus
    public let createdAt: Date
    public var updatedAt: Date
    /// v0.23 ticket 013.003: priority (0 = low, 5 = normal, 10 = urgent).
    public var priority: Int
    /// v0.23 ticket 013.003: assignee agent name (e.g. "writer", "researcher", "wenshu-conductor").
    public var assignee: String?
    /// v0.23 ticket 013.003: when task started running.
    public var startedAt: Date?
    /// v0.23 ticket 013.003: when task completed/failed.
    public var completedAt: Date?
    /// v0.23 ticket 013.003: model used for this task (e.g. "MiniMax-M3", "claude-3.7-sonnet").
    public var modelOverride: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        status: KanbanStatus = .new,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: Int = 5,
        assignee: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        modelOverride: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.priority = priority
        self.assignee = assignee
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.modelOverride = modelOverride
    }
}
