//
//  Persistence/WSLink.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 5 of 21 @Model classes: WSLink.
//  Mirrors `links` table from LinkIndex.swift (= v0.19 ticket 12 Internal Link).
//
//  Note: old schema had INTEGER PRIMARY KEY AUTOINCREMENT. SwiftData
//  @Attribute(.unique) auto-generates UUID. The natural uniqueness is
//  per (sourceDocID, targetRef, line) — a doc only has one link to a
//  given target at a given line. We encode this as @Attribute(.unique)
//  on a composite key via a synthetic `id: String` (= "sourceDocID:line").

import Foundation
import SwiftData

@Model
public final class WSLink {
    /// Composite key: "<sourceDocID>:<line>" (= unique per source doc + line)
    @Attribute(.unique) public var id: String
    var sourceDocID: String
    var targetRef: String
    var targetDocID: String?
    var line: Int
    var offset: Int
    var createdAt: Date

    init(sourceDocID: String, targetRef: String, targetDocID: String? = nil, line: Int, offset: Int) {
        self.id = "\(sourceDocID):\(line)"
        self.sourceDocID = sourceDocID
        self.targetRef = targetRef
        self.targetDocID = targetDocID
        self.line = line
        self.offset = offset
        self.createdAt = Date()
    }
}
