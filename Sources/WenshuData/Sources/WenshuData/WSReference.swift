//
//  Persistence/WSReference.swift
//
//  SwiftData @Model for the Reference (= the per-reference entity
//  in the ReferenceLibrary; = sibling to the book-private Document).
//
//  (= see OOB.md #2026-10-05). SwiftData migration; = commit 2 of #8.
//
//  Apple HIG canonical pattern: Reference's free-form body
//  markdown lives inline in the WSReference.body field (= replaces
//  the per-layer .md file on disk); the metadata fields (= title,
//  source, url, layer, category, tags, etc.) live as typed
//  columns. SwiftData stores the entire reference in a single row.

import Foundation
import SwiftData

@Model
public final class WSReference {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var displayTitle: String?
    public var source: String?
    public var url: String?
    /// LLM Wiki layer this reference lives in (= raw / entities /
    /// abstracts / indexes / "__metadata__" sentinel for the
    /// ReferenceLibrary metadata record).
    public var layer: String
    /// Entity category (= only for `.layerEntities` layer; nil for others).
    public var category: String?
    /// Free-form tags for search and group-by.
    public var tags: [String]
    /// Type of entity (Character / Location / Event / etc.). Raw
    /// string (= EntityType enum's rawValue).
    public var entityType: String
    /// Short summary for the card grid display.
    public var summary: String
    /// The reference body markdown (= was a separate .md file per
    /// layer in the pre-#8 FileSystemReferenceStore).
    public var body: String
    /// Cross-reference pointers (= JSON-encoded UUID arrays).
    public var characterRefIDsData: Data
    public var worldRefIDsData: Data
    public var bookRefIDsData: Data
    public var trailingNoise: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        displayTitle: String? = nil,
        source: String? = nil,
        url: String? = nil,
        layer: String,
        category: String? = nil,
        tags: [String] = [],
        entityType: String,
        summary: String = "",
        body: String = "",
        characterRefIDs: [UUID] = [],
        worldRefIDs: [UUID] = [],
        bookRefIDs: [UUID] = [],
        trailingNoise: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.displayTitle = displayTitle
        self.source = source
        self.url = url
        self.layer = layer
        self.category = category
        self.tags = tags
        self.entityType = entityType
        self.summary = summary
        self.body = body
        self.characterRefIDsData = Self.encodeUUIDList(characterRefIDs)
        self.worldRefIDsData = Self.encodeUUIDList(worldRefIDs)
        self.bookRefIDsData = Self.encodeUUIDList(bookRefIDs)
        self.trailingNoise = trailingNoise
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var characterRefIDs: [UUID] {
        get { Self.decodeUUIDList(characterRefIDsData) }
        set { characterRefIDsData = Self.encodeUUIDList(newValue) }
    }

    public var worldRefIDs: [UUID] {
        get { Self.decodeUUIDList(worldRefIDsData) }
        set { worldRefIDsData = Self.encodeUUIDList(newValue) }
    }

    public var bookRefIDs: [UUID] {
        get { Self.decodeUUIDList(bookRefIDsData) }
        set { bookRefIDsData = Self.encodeUUIDList(newValue) }
    }

    private static func encodeUUIDList(_ ids: [UUID]) -> Data {
        (try? JSONEncoder().encode(ids)) ?? Data()
    }

    private static func decodeUUIDList(_ data: Data) -> [UUID] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
    }
}
