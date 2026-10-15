//
//  Persistence/WSPreference.swift
//
//   : WSPreference.
//  Note: the `preferences` table in WenshuWorkspace.swift was a late
//  add (= most preferences live in UserDefaults via @AppStorage).
//  WSPreference provides the SwiftData K/V store for the few prefs
//  that survive workspace moves (= not @AppStorage-managed).
//
//  Generic K/V store (= use sparingly; = prefer typed settings on
//  the relevant @Model or @Observable class). Used for cross-cutting
//  workspace preferences (= appearance, font, sidebar widths) that
//  don't have a natural home elsewhere.

import Foundation
import SwiftData

@Model
public final class WSPreference {
    @Attribute(.unique) public var key: String
    public var value: String
    public var updatedAt: Date

    public init(key: String, value: String) {
        self.key = key
        self.value = value
        self.updatedAt = Date()
    }

    public func update(value newValue: String) {
        self.value = newValue
        self.updatedAt = Date()
    }
}
