//
//  Persistence/WSReference.swift
//
//  SwiftData @Model for the Reference (= the per-reference entity
//  in the ReferenceLibrary; = sibling to the book-private Document).
//
//  Per boss 2026-10-05 OOB ' 8' (= complete the FileSystem*Store →
//  SwiftData migration). This is commit 2 of #8.
//
//  Apple HIG canonical pattern: Reference's free-form body
//  markdown lives inline in the WSReference.body field (= replaces
//  the per-layer .md file on disk); the metadata fields (= title,
//  source, url, layer, category, tags, etc.) live as typed
//  columns. SwiftData stores the entire reference in a single row.

import Foundation
import SwiftData

@Model
final class WSReference {
    @Attribute(.unique) var id: UUID
    var title: String
    var displayTitle: String?
    var source: String?
    var url: String?
    /// LLM Wiki layer this reference lives in (= raw / entities /
    /// abstracts / indexes / "__metadata__" sentinel for the
    /// ReferenceLibrary metadata record).
    var layer: String
    /// Entity category (= only for `.layerEntities` layer; nil for others).
    var category: String?
    /// Free-form tags for search and group-by.
    var tags: [String]
    /// Type of entity (Character / Location / Event / etc.). Raw
    /// string (= EntityType enum's rawValue).
    var entityType: String
    /// Short summary for the card grid display.
    var summary: String
    /// The reference body markdown (= was a separate .md file per
    /// layer in the pre-#8 FileSystemReferenceStore).
    var body: String
    /// Cross-reference pointers (= JSON-encoded UUID arrays).
    var characterRefIDsData: Data
    var worldRefIDsData: Data
    var bookRefIDsData: Data
    var trailingNoise: String
    var createdAt: Date
    var updatedAt: Date

    init(
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

    var characterRefIDs: [UUID] {
        get { Self.decodeUUIDList(characterRefIDsData) }
        set { characterRefIDsData = Self.encodeUUIDList(newValue) }
    }

    var worldRefIDs: [UUID] {
        get { Self.decodeUUIDList(worldRefIDsData) }
        set { worldRefIDsData = Self.encodeUUIDList(newValue) }
    }

    var bookRefIDs: [UUID] {
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
