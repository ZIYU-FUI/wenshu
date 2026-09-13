//
//  Persistence/WSKanbanTask.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 19/21: WSKanbanTask.
//  Mirrors KanbanTask struct from Core/Kanban/KanbanStore.swift +
//  kanban_tasks table from WenshuWorkspace.swift (= v0.23 ticket 013.003).
//
//  NOTE: Similar to WSTodo but separate domain (= kanban = workspace-level
//  task board; todo = per-session todo list).
//
//  Status enum: .new / .in_progress / .done / .cancelled (matches KanbanStatus)

import Foundation
import SwiftData

@Model
public final class WSKanbanTask {
    @Attribute(.unique) public var id: String
    var title: String
    /// Status string (= matches KanbanStatus enum: "new" / "in_progress" / "done" / "cancelled")
    var status: String
    /// 0 = low, 5 = normal, 10 = urgent
    var priority: Int
    /// Assignee agent name (= "writer" / "researcher" / "wenshu-conductor")
    var assignee: String?
    var startedAt: Date?
    var completedAt: Date?
    /// Model override (= "claude-sonnet-4.5" etc)
    var modelOverride: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: String, title: String, status: String = "new", priority: Int = 5,
         assignee: String? = nil, startedAt: Date? = nil, completedAt: Date? = nil,
         modelOverride: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.modelOverride = modelOverride
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func start(assignee: String) {
        self.status = "in_progress"
        self.assignee = assignee
        self.startedAt = Date()
        self.updatedAt = Date()
    }

    func complete() {
        self.status = "done"
        self.completedAt = Date()
        self.updatedAt = Date()
    }
}
