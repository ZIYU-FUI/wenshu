//
//  OutlineEntry.swift
//
//  Domain model for one outline item under a book.
//
//  Outline = high-level story structure (volumes / chapters / scenes
//  / beats). Lives at <bookDir>/outlines/<outline-uuid>.md + an
//  index at <bookDir>/outlines.json.
//
//  Hierarchy via `parent: UUID?` (= the outline item this one is a
//  child of; nil = top-level volume). Depth limit is not enforced
//  here; = the UI / authoring layer renders any depth.

import Foundation

struct OutlineEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let bookId: UUID
    var title: String
    var summary: String
    var parent: UUID?
    var order: Int
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        title: String,
        summary: String = "",
        parent: UUID? = nil,
        order: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.summary = summary
        self.parent = parent
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk (= <uuid>.md).
    var filename: String {
        "\(id.uuidString).md"
    }

    func onDiskPath(under bookDirectory: URL) -> URL {
        bookDirectory
            .appendingPathComponent("outlines")
            .appendingPathComponent(filename)
    }

    static func == (lhs: OutlineEntry, rhs: OutlineEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}