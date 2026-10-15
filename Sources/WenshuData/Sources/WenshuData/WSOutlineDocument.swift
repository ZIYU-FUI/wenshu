//
//  Persistence/WSOutlineDocument.swift
//
//   : WSOutlineDocument.
//  New SwiftData @Model class (= no previous sqlite source — outline
//  documents were filesystem-only before; = Domain/Document.swift was
//  the in-memory struct; = this is the first persistence layer).
//
//  Old storage: filesystem-only (.ws/shelves/<shelf-id>/books/<book-id>/outline/*.md)
//  New storage: SwiftData @Model index (= filesystem remains source of truth;
//  = SwiftData stores metadata: title, byteSize, updatedAt, etc.)
//
//  Hybrid model: the file body is NOT stored in SwiftData (= too large +
//  filesystem remains canonical). Only metadata is in @Model. The editor
//  reads/writes the file directly; SwiftData is the index that lets the
//  sidebar search/filter without scanning every file.

import Foundation
import SwiftData

@Model
public final class WSOutlineDocument {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id
    public var bookID: String
    /// Title shown in the card (= may differ from filename)
    public var title: String
    /// Filename in the outline/ folder (= no path; = book-relative)
    public var filename: String
    /// File size in bytes (= 0 if not yet on disk)
    public var byteSize: Int
    /// Auto-extracted first ~100 chars of body (= for card preview)
    public var summaryExcerpt: String?
    /// Frontmatter block (= YAML or TOML; = extracted at index time)
    public var frontmatterText: String?
    /// Last-modified timestamp of the file
    public var fileUpdatedAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    public var book: WSBook?

    public init(id: String, bookID: String, title: String, filename: String,
         byteSize: Int = 0, summaryExcerpt: String? = nil,
         frontmatterText: String? = nil, fileUpdatedAt: Date = Date()) {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.filename = filename
        self.byteSize = byteSize
        self.summaryExcerpt = summaryExcerpt
        self.frontmatterText = frontmatterText
        self.fileUpdatedAt = fileUpdatedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Update when the file changes on disk (= called by storage layer).
    public func syncFromFile(title: String, byteSize: Int, summaryExcerpt: String?, fileUpdatedAt: Date) {
        self.title = title
        self.byteSize = byteSize
        self.summaryExcerpt = summaryExcerpt
        self.fileUpdatedAt = fileUpdatedAt
        self.updatedAt = Date()
    }
}
