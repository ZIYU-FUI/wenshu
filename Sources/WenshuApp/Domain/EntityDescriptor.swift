//
//  EntityDescriptor.swift
//
//  Brand ID + immutable entity descriptor for the v2.3 schema.
//
//  EntityID = brand wrapper around UUID string (= per the
//  TypedID convention from Persistence/TypedID.swift; = see
//  BookID for the pilot pattern).
//
//  EntityDescriptor = the immutable value type that the LLM sees
//  via the book_entity tool (= returned by find / list / read).
//  It is NOT the @Model (= WSEntity is the @Model; = see
//  Persistence/WSEntity.swift in a later ticket). The descriptor
//  is computed from the @Model row + the body markdown excerpt
//  (= see EntityDescriptor.make(_:bodyExcerpt:)).
//

import Foundation

// MARK: - Brand ID

/// Brand wrapper for an entity (= person / location / object /
/// ability / event) identifier.
///
/// Conforms to TypedID (= same convention as BookID).
struct EntityID: TypedID, Equatable, CustomStringConvertible {
    let rawValue: String

    var description: String { "EntityID(\(rawValue))" }
}

// MARK: - Immutable descriptor (LLM-facing)

/// Immutable value type returned by the book_entity tool.
///
/// Lifetime: created on demand by WSEntityRepository (= from a
/// WSEntity @Model row + the body excerpt). Never mutated in
/// place; every "update" produces a new descriptor.
///
/// Fields are split into:
/// - shared (= all kinds): id, bookID, kind, name, aliases,
///   tags, description, attributes
/// - kindSpecific: 5 fields, optional, see EntityKindSpecific
/// - bodyExcerpt: first 200 chars of the markdown body (=
///   compressed view for the LLM; full body is fetched via a
///   separate read tool call).
struct EntityDescriptor: Codable, Sendable, Equatable {
    /// Stored as String on disk (= see Codable note below).
    /// At the API surface (= the LLM-facing tool return), callers
    /// receive this as `BookID(rawValue:)`.
    var bookIDRaw: String
    /// Stored as String on disk; bridged to EntityID via accessor.
    var idRaw: String
    var kind: EntityKind
    var name: String
    var aliases: [String]
    var tags: [String]
    var description: String
    var attributes: [String: String]
    var kindSpecific: EntityKindSpecific
    var bodyExcerpt: String
    var createdAt: Date
    var updatedAt: Date

    /// Convenience accessor (= bridges the String-on-disk format
    /// to the typed BookID at the API surface).
    var bookID: BookID { BookID(rawValue: bookIDRaw) }

    /// Convenience accessor (= bridges to EntityID).
    var id: EntityID { EntityID(rawValue: idRaw) }

    init(
        id: EntityID,
        bookID: BookID,
        kind: EntityKind,
        name: String,
        aliases: [String] = [],
        tags: [String] = [],
        description: String = "",
        attributes: [String: String] = [:],
        kindSpecific: EntityKindSpecific = .empty,
        bodyExcerpt: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.idRaw = id.rawValue
        self.bookIDRaw = bookID.rawValue
        self.kind = kind
        self.name = name
        self.aliases = aliases
        self.tags = tags
        self.description = description
        self.attributes = attributes
        self.kindSpecific = kindSpecific
        self.bodyExcerpt = bodyExcerpt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Body excerpt extraction

/// First N characters of a markdown body (= for the LLM-facing
/// descriptor). Strips at the nearest line break so the LLM
/// never gets mid-sentence truncations.
///
/// Default N = 200 (= per the tool compression spec in
/// ticket T14). The full body is fetched via a separate tool
/// call when needed (= same as the BookCharacterTool /
/// BookWorldTool v2.0 behavior).
enum BodyExcerpt {
    static let maxLength = 200

    static func make(from body: String) -> String {
        if body.count <= maxLength { return body }
        // Search for a newline within the first maxLength chars.
        // If found, truncate there (= clean sentence break). If
        // not (= body is one long line with no break), fall back
        // to a hard cut + ellipsis.
        let cutoff = body.index(body.startIndex, offsetBy: maxLength)
        let head = body[..<cutoff]
        if let lastNewline = head.lastIndex(of: "\n") {
            return String(body[..<lastNewline])
        }
        return String(head) + "…"
    }
}