//
//  Persistence/WSPlaceholder.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 17/21: WSPlaceholder.
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
    var bookID: String
    /// FK to WSChapter.id
    var chapterID: String
    /// 1-indexed line number within chapter text
    var lineNumber: Int
    /// Surrounding text excerpt (= the matched line + small window)
    var context: String
    /// The literal matched text (= e.g. "[TODO: check this]")
    var pattern: String
    /// Lifecycle status: "open" / "in_progress" / "resolved" / "ignored"
    var status: String
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    var book: WSBook?

    init(id: String, bookID: String, chapterID: String, lineNumber: Int,
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
