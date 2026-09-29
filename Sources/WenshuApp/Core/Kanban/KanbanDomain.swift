// KanbanDomain.swift · WenshuApp · v0.72
//
// Canonical domain types for kanban tickets (= `KanbanStatus` +
// `KanbanTask`). Pure value types (= no SQLite dependency).
// SwiftData persistence lives in `WSKanbanTask` @Model +
// `WSKanbanRepository`.

import Foundation

/// Kanban task status. Mirrors the hermes kanban state machine
/// (= new → triage → ready → running → blocked → review → done);
/// wenshu adds an extra `.failed` case.
enum KanbanStatus: String, Codable, Sendable, CaseIterable {
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
/// .003: extended with hermes-style metadata
/// (priority / assignee / started_at / completed_at / model_override).
struct KanbanTask: Equatable, Sendable {
    let id: String
    var title: String
    var status: KanbanStatus
    let createdAt: Date
    var updatedAt: Date
    /// .003: priority (0 = low, 5 = normal, 10 = urgent).
    var priority: Int
    /// .003: assignee agent name (e.g. "writer", "researcher", "wenshu-conductor").
    var assignee: String?
    /// .003: when task started running.
    var startedAt: Date?
    /// .003: when task completed/failed.
    var completedAt: Date?
    /// .003: model used for this task (e.g. "MiniMax-M3", "claude-3.7-sonnet").
    var modelOverride: String?
    /// Agent-written markdown body. 2026-09-28 kanban-markdown arc:
    /// mirrors WSKanbanTask.body (= the SwiftData column added in T1).
    var body: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        status: KanbanStatus = .new,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        priority: Int = 5,
        assignee: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        modelOverride: String? = nil,
        body: String? = nil
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
        self.body = body
    }
}
