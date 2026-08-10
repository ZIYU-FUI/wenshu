// ProjectSnapshot.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// In-memory project snapshot used by the UI flow (WO-004). NOT a CoreData
// entity. WO-005 will replace this with a `.ws`-backed CoreData project;
// the `ProjectSnapshot` surface stays the same so the View layer doesn't
// need to change.
//
// Per AGENTS.md §7: `.ws` is the source of truth on disk. Until WO-005
// wires the persistence layer, projects live in `@State` in MainView and
// vanish on app restart (intentional — keeps the demo flow deterministic
// for PM-direct visual verification).

import Foundation

/// Lightweight project model used by the UI before `.ws` is wired.
struct ProjectSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var style: String
    /// 1-9 slider. 1 = 古龙式惜字如金, 9 = 网文式详尽铺陈.
    var verbosity: Int
    var tags: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        style: String,
        verbosity: Int = 5,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.verbosity = verbosity
        self.tags = tags
        self.createdAt = createdAt
    }
}
