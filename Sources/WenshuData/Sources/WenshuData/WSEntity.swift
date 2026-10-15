//
//  WSEntity.swift
//
//  Canonical SwiftData @Model for the entity schema.
//
//  Replaces WSCharacter + WSWorld (= ) with a single
//  kind-discriminated model. One row per entity (= the main
//  character / a city / a magical item / a technique / a key
//  plot event).
//
//  Diff from WSCharacter / WSWorld:
//  - Single model (= the split by source-type was wrong
//    abstraction; = per spec).
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
public final class WSEntity {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id (= String, the SwiftData column type).
    /// Wrapped to BookID at the API surface (= see
    /// WSEntityRepository).
    public var bookID: String
    /// EntityKind rawValue (= "person" / "location" / "object" /
    /// "ability" / "event").
    public var kind: String
    public var name: String
    /// Comma-joined aliases (= one string per row; = small).
    /// Empty string when no aliases.
    public var aliasesJoined: String
    /// Comma-joined tags (= one string per row).
    public var tagsJoined: String
    public var description_: String
    /// JSON-encoded [String: String] dictionary (= matches the
    /// shape; = nil when empty).
    public var attributesJSON: String?
    /// JSON-encoded EntityKindSpecific (= see Domain/EntityKind.swift).
    /// nil when empty (= per the spec's empty default).
    public var kindSpecificJSON: String?
    /// FK to WSBody.id (= the body markdown row). Always set;
    /// a brand-new entry has a stub body (= "# <name>\n\n<desc>")
    /// that the user / agent fills in via update.
    public var bodyID: String
    public var createdAt: Date
    public var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook).
    public var book: WSBook?

    public init(
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
    public func touch() {
        self.updatedAt = Date()
    }
}