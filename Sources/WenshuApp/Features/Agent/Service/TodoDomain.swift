// TodoDomain.swift
//
// Canonical domain types for todo items (= `TodoStatus` +
// `TodoPriority` + `TodoItem`). Pure value types (= no SQLite
// dependency). SwiftData persistence lives in `WSTodo` @Model +
// `WSTodoRepository`.

import Foundation
import WenshuData

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

/// Reserved for future-hook callers (= no consumers yet; = the
/// pre-migration deleted TodoStore actor's error type was extracted
/// in  and renamed here; = currently dead code but
/// preserved for potential future callers that want the legacy
/// 4-case error shape from the old actor's sqlite3 failures).

