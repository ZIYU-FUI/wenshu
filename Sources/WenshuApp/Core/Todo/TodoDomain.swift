//
//  Core/Todo/TodoDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 7
//
//  Domain types (TodoStatus + TodoPriority + TodoItem + TodoStoreError) extracted
//  from the deleted Core/Todo/TodoStore.swift (= sqlite3 legacy actor, now obsolete).
//
//  These types are the canonical wenshu-side public API surface for todo items.
//  The SwiftData-backed persistence lives in Persistence/WSTodo (@Model) and is
//  wrapped by Persistence/Repositories/WSTodoRepository (@MainActor).
//
//  Moved 2026-09-13 (= phase 5 ticket 7 — see AGENTS.md §11.4.2).
//

import Foundation

public enum TodoStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled
}

/// Todo
public enum TodoPriority: Int, Codable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
}

/// Todo
public struct TodoItem: Equatable, Sendable {
    public let id: String
    public var title: String
    public var status: TodoStatus
    public var priority: TodoPriority
    public var dueDate: Date?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, status: TodoStatus = .pending, priority: TodoPriority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


public enum TodoStoreError: Error {
    case openFailed(dbPath: String, message: String)
    case prepareFailed(message: String)
    case stepFailed(message: String)
    case execFailed(message: String)
}

