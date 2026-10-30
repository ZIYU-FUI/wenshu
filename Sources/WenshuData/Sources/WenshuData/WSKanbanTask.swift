//
//  Persistence/WSKanbanTask.swift
//
//   : WSKanbanTask.
//  Mirrors kanban_tasks table from WenshuWorkspace.swift.
//  (=  deleted Core/Kanban/KanbanStore.swift; the canonical
//  domain type is now Core/Kanban/KanbanDomain.swift's KanbanTask struct.)
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
    public var title: String
    /// Status string (= matches KanbanStatus enum rawValues: .new / .triage /
    ///  .ready / .running / .blocked / .review / .done / .failed; = 8 cases per
    ///  Core/Kanban/KanbanDomain.swift; =  preserved the enum)
    public var status: String
    /// 0 = low, 5 = normal, 10 = urgent
    public var priority: Int
    /// Assignee agent name (= "writer" / "researcher" / "wenshu-conductor")
    public var assignee: String?
    public var startedAt: Date?
    public var completedAt: Date?
    /// Model override (= "claude-sonnet-4.5" etc)
    public var modelOverride: String?
    /// Agent-written body (markdown). 2026-09-28 kanban-markdown arc:
    /// mirrors hermes 0.21.5 commit 63f5bc0999 (feat(kanban): render
    /// task text as markdown). KanbanStoreTool already exposes this
    /// argument to the LLM (= `body / description` at
    /// KanbanStoreTool.swift:333), but the @Model had no column.
    public var body: String?
    /// The book this task belongs to (= the board it shows on).
    ///
    /// Nil = the task belongs to no book (= the library-level board and
    /// the reference-material board). The board follows the session, and
    /// the session names its book, so this column is what makes "one
    /// board per book" a fact the store can answer.
    ///
    /// Optional, because a task written before this column existed
    /// belongs to no book (= it reads on the library-level board).
    public var bookID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, title: String, status: String = "new", priority: Int = 5,
         assignee: String? = nil, startedAt: Date? = nil, completedAt: Date? = nil,
         modelOverride: String? = nil, body: String? = nil, bookID: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.assignee = assignee
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.modelOverride = modelOverride
        self.body = body
        self.bookID = bookID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func start(assignee: String) {
        self.status = "in_progress"
        self.assignee = assignee
        self.startedAt = Date()
        self.updatedAt = Date()
    }

    public func complete() {
        self.status = "done"
        self.completedAt = Date()
        self.updatedAt = Date()
    }
}
