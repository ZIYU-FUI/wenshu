//
//  Persistence/WSTodo.swift
//
//   : WSTodo.
//  Mirrors todos table schema.
//  (=  deleted Core/Todo/TodoStore.swift; the canonical
//  domain type is now Core/Todo/TodoDomain.swift's TodoItem struct.)
//
//  Status values (hermes-port parity per todo.py):
//    - "new"          = created, not started
//    - "in_progress"  = actively being worked on
//    - "done"         = completed
//    - "cancelled"    = dropped (per HermesToDoTool convention)

import Foundation
import SwiftData

@Model
public final class WSTodo {
    @Attribute(.unique) public var id: String
    public var title: String
    /// Status string (= wenshu-native values: "new" / "in_progress" /
    /// "done" / "cancelled"; = does NOT match hermes TodoStatus enum names
    /// which use "pending" / "completed"; = see HermesTodoTool for translation).
    public var status: String
    /// 0 = highest priority (= matches HermesTodoTool convention; = old schema did not have a priority field; = migration adds it; = init default is 5 to match the old TodoStore behavior where most tasks are medium-priority).
    public var priority: Int
    public var dueDate: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, title: String, status: String = "new", priority: Int = 5) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func updateStatus(_ newStatus: String) {
        self.status = newStatus
        self.updatedAt = Date()
    }
}
