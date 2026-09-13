//
//  Persistence/WSWorld.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 20/21: WSWorld.
//  Mirrors WorldEntry struct from Domain/World.swift (= per-book
//  world-building entry; = geography / lore / event / object / other).
//
//  Old storage: world.json index + <uuid>.md file per entry
//  New storage: SwiftData @Model (= metadata index; = .md remains canonical)

import Foundation
import SwiftData

@Model
public final class WSWorld {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id
    var bookID: String
    /// WorldEntryType string (= "geography" / "lore" / "event" / "object" / "other")
    var type: String
    var name: String
    var summary: String
    /// JSON-encoded array of UUID strings (= characterRefIds)
    var characterRefIDsJSON: String?
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    var book: WSBook?

    init(id: String, bookID: String, type: String = "other", name: String,
         summary: String = "", characterRefIDsJSON: String? = nil) {
        self.id = id
        self.bookID = bookID
        self.type = type
        self.name = name
        self.summary = summary
        self.characterRefIDsJSON = characterRefIDsJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
