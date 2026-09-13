//
//  Persistence/WSPreference.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 7 of 21 @Model classes: WSPreference.
//  Mirrors `preferences` table from WenshuWorkspace.swift.
//
//  Generic K/V store (= use sparingly; = prefer typed settings on
//  the relevant @Model or @Observable class). Used for cross-cutting
//  workspace preferences (= appearance, font, sidebar widths) that
//  don't have a natural home elsewhere.

import Foundation
import SwiftData

@Model
final class WSPreference {
    @Attribute(.unique) var key: String
    var value: String
    var updatedAt: Date

    init(key: String, value: String) {
        self.key = key
        self.value = value
        self.updatedAt = Date()
    }

    func update(value newValue: String) {
        self.value = newValue
        self.updatedAt = Date()
    }
}
