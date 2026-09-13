//
//  Persistence/WSTodo.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 3 of 21 @Model classes: WSTodo.
//  Mirrors `todos` table from TodoStore.swift (= v0.18 ticket 06 local Todo).
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
    var title: String
    /// Status string (= wenshu-native values: "new" / "in_progress" /
    /// "done" / "cancelled"; = does NOT match hermes TodoStatus enum names
    /// which use "pending" / "completed"; = see HermesTodoTool for translation).
    var status: String
    /// 0 = highest priority (= matches HermesTodoTool convention; = old schema did not have a priority field; = migration adds it; = init default is 5 to match the old TodoStore behavior where most tasks are medium-priority).
    var priority: Int
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(id: String, title: String, status: String = "new", priority: Int = 5) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updateStatus(_ newStatus: String) {
        self.status = newStatus
        self.updatedAt = Date()
    }
}
