//
//  Persistence/WSForeshadowing.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 17 of 22 @Model classes: WSForeshadowing (= one of the
//  Mirrors the JSON sidecar Foreshadowing struct from
//  ForeshadowingTrackerTools.swift.
//
//  Old storage: in-memory `Foreshadowing` struct (= managed by
//  `ForeshadowingTrackerTools.swift`; = ephemeral during agent session;
//  = NOT persisted to disk pre-v0.72 — the `ForeshadowingSidecar`
//  Codable wrapper in the same file is the data shape but no on-disk
//  per-book JSON was ever written).
//  New storage: SwiftData @Model (= per foreshadowing entry; = first
//  persistence layer for foreshadowing metadata in wenshu)
//
//  Setup-recall pattern: each foreshadowing has a "setup" chapter (where
//  it's introduced) and a "recall" chapter (where it's resolved).
//  Unresolved foreshadowings are still in setup phase.
//
//  Note: SwiftData @Model forbids the property name "description" (=
//  reserved by Swift's CustomStringConvertible). We use "detail" instead.

import Foundation
import SwiftData

@Model
public final class WSForeshadowing {
    @Attribute(.unique) public var id: String
    /// FK to WSBook.id
    var bookID: String
    var title: String
    /// Detail text (= was named `description` in JSON sidecar; = SwiftData reserves `description`)
    var detail: String?
    /// FK to setup chapter (= where introduced)
    var setupChapterID: String?
    /// Line number within setup chapter
    var setupLineNumber: Int?
    /// FK to recall chapter (= where resolved; = nil if still open)
    var recallChapterID: String?
    var recallLineNumber: Int?
    /// Status: "open" / "recalled" / "abandoned"
    var status: String
    /// Type: "character" / "plot" / "world" / "object"
    var foreshadowType: String
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    var book: WSBook?

    init(id: String, bookID: String, title: String,
         foreshadowType: String = "plot", detail: String? = nil,
         setupChapterID: String? = nil, setupLineNumber: Int? = nil,
         recallChapterID: String? = nil, recallLineNumber: Int? = nil,
         status: String = "open") {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.foreshadowType = foreshadowType
        self.detail = detail
        self.setupChapterID = setupChapterID
        self.setupLineNumber = setupLineNumber
        self.recallChapterID = recallChapterID
        self.recallLineNumber = recallLineNumber
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
