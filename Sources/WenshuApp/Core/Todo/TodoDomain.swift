// TodoDomain.swift · WenshuApp · v0.72
//
// Canonical domain types for todo items (= `TodoStatus` +
// `TodoPriority` + `TodoItem`). Pure value types (= no SQLite
// dependency). SwiftData persistence lives in `WSTodo` @Model +
// `WSTodoRepository`.

import Foundation

enum TodoStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
}

/// Todo
enum TodoPriority: Int, Codable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
}

/// Todo
struct TodoItem: Equatable, Sendable {
    let id: String
    var title: String
    var status: TodoStatus
    var priority: TodoPriority
    var dueDate: Date?
    let createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, status: TodoStatus = .pending, priority: TodoPriority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


/// Reserved for future-hook callers (= no consumers yet; = the
/// pre-migration deleted TodoStore actor's error type was extracted
/// in  and renamed here; = currently dead code but
/// preserved for potential future callers that want the legacy
/// 4-case error shape from the old actor's sqlite3 failures).

