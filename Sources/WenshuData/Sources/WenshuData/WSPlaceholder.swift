//
//  Persistence/WSPlaceholder.swift
//
//   : WSPlaceholder.
//  Mirrors the JSON sidecar Placeholder struct from
//  PlaceholderScannerTools.swift.
//
//  Old storage: PlaceholderSidecar JSON file
//  New storage: SwiftData @Model

import Foundation
import SwiftData

@Model
public final class WSPlaceholder {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id
    public var bookID: String
    /// FK to WSChapter.id
    public var chapterID: String
    /// 1-indexed line number within chapter text
    public var lineNumber: Int
    /// Surrounding text excerpt (= the matched line + small window)
    public var context: String
    /// The literal matched text (= e.g. "[TODO: check this]")
    public var pattern: String
    /// Lifecycle status: "open" / "in_progress" / "resolved" / "ignored"
    public var status: String
    public var createdAt: Date
    public var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    public var book: WSBook?

    public init(id: String, bookID: String, chapterID: String, lineNumber: Int,
         context: String = "", pattern: String, status: String = "open") {
        self.id = id
        self.bookID = bookID
        self.chapterID = chapterID
        self.lineNumber = max(0, lineNumber)
        self.context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pattern = pattern
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
