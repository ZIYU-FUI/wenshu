//
//  Persistence/WSCharacter.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 19/21: WSCharacter.
//  Mirrors Character struct from Domain/Character.swift (= per-book
//  fictional person; = JSON sidecar per book; = .md file per char).
//
//  Old storage: characters.json index + <uuid>.md file per character
//  New storage: SwiftData @Model (= metadata index; = .md remains canonical)
//
//  role stored as String (= "protagonist" / "antagonist" / "supporting" / "narrator" / "other")
//  Cross-refs stored as JSON-encoded array of UUID strings (= matches old schema).

import Foundation
import SwiftData

@Model
public final class WSCharacter {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id
    var bookID: String
    var name: String
    var age: Int?
    /// Role string (= matches CharacterRole enum)
    var role: String
    var arc: String?
    var summary: String
    /// JSON-encoded array of UUID strings (= worldRefIds)
    var worldRefIDsJSON: String?
    /// JSON-encoded array of UUID strings (= characterRefIds)
    var characterRefIDsJSON: String?
    /// JSON-encoded array of UUID strings (= referenceRefIds)
    var referenceRefIDsJSON: String?
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    var book: WSBook?

    init(id: String, bookID: String, name: String,
         role: String = "other", summary: String = "",
         age: Int? = nil, arc: String? = nil,
         worldRefIDsJSON: String? = nil,
         characterRefIDsJSON: String? = nil,
         referenceRefIDsJSON: String? = nil) {
        self.id = id
        self.bookID = bookID
        self.name = name
        self.age = age
        self.role = role
        self.arc = arc
        self.summary = summary
        self.worldRefIDsJSON = worldRefIDsJSON
        self.characterRefIDsJSON = characterRefIDsJSON
        self.referenceRefIDsJSON = referenceRefIDsJSON
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
