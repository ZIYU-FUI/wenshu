//
//  WSEntity.swift
//
//  Canonical SwiftData @Model for the v2.3 entity schema.
//
//  Replaces WSCharacter + WSWorld (= v0.72/v2.0) with a single
//  kind-discriminated model. One row per entity (= the main
//  character / a city / a magical item / a technique / a key
//  plot event).
//
//  Diff from v2.0 WSCharacter / WSWorld:
//  - Single model (= the v2.0 split by source-type was wrong
//    abstraction; = per spec v2.3).
//  - 5 kindSpecific fields (= per EntityKindSpecific).
//  - aliases / tags / attributes as the structured free-form
//    surface (= "protagonist" / "mentor" / "swordsman" all live as tags).
//  - body is stored in a separate WSBody row (= body markdown
//    is potentially large; = the @Model main row stays small for
//    index queries).
//
//  The body is loaded via WSBody / the FileSystemEntityStore on
//  demand. The descriptor (= what the LLM sees) holds a 200-char
//  bodyExcerpt (= see BodyExcerpt in EntityDescriptor.swift).
//

import Foundation
import SwiftData

@Model
final class WSEntity {
    @Attribute(.unique) var id: String
    /// FK to WSBook.id (= String, the SwiftData column type).
    /// Wrapped to BookID at the API surface (= see
    /// WSEntityRepository).
    var bookID: String
    /// EntityKind rawValue (= "person" / "location" / "object" /
    /// "ability" / "event").
    var kind: String
    var name: String
    /// Comma-joined aliases (= one string per row; = small).
    /// Empty string when no aliases.
    var aliasesJoined: String
    /// Comma-joined tags (= one string per row).
    var tagsJoined: String
    var description_: String
    /// JSON-encoded [String: String] dictionary (= matches the
    /// v2.0 WSCharacter.attributes shape; = nil when empty).
    var attributesJSON: String?
    /// JSON-encoded EntityKindSpecific (= see Domain/EntityKind.swift).
    /// nil when empty (= per the spec's empty default).
    var kindSpecificJSON: String?
    /// FK to WSBody.id (= the body markdown row). Always set;
    /// a brand-new entry has a stub body (= "# <name>\n\n<desc>")
    /// that the user / agent fills in via update.
    var bodyID: String
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook).
    var book: WSBook?

    init(
        id: String,
        bookID: String,
        kind: String,
        name: String,
        aliasesJoined: String = "",
        tagsJoined: String = "",
        description: String = "",
        attributesJSON: String? = nil,
        kindSpecificJSON: String? = nil,
        bodyID: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookID = bookID
        self.kind = kind
        self.name = name
        self.aliasesJoined = aliasesJoined
        self.tagsJoined = tagsJoined
        self.description_ = description
        self.attributesJSON = attributesJSON
        self.kindSpecificJSON = kindSpecificJSON
        self.bodyID = bodyID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Stamp `updatedAt` (= called by the repository on every
    /// successful save / replace).
    func touch() {
        self.updatedAt = Date()
    }
}