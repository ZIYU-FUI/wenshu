//
//  Persistence/WSLink.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 5/21: WSLink.
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
    /// Composite key: "<sourceDocID>:<line>:<targetRef>" (= unique per source doc + line + target; = Phase 5 ticket 5 fix)
    @Attribute(.unique) public var id: String
    var sourceDocID: String
    var targetRef: String
    var targetDocID: String?
    var line: Int
    var offset: Int
    var createdAt: Date

    init(sourceDocID: String, targetRef: String, targetDocID: String? = nil, line: Int, offset: Int) {
        // Phase 5 ticket 5: include `targetRef` in composite id (= restores
        // the original LinkIndex compound primary key shape "sourceDocId,
        // targetRef, line"). The previous "sourceDocId:line" id collided
        // when multiple [[name]] links live on the same line (= the
        // BacklinkResolverTests resolve test inserts 2 such links).
        // Discovered when ticket 5 migrated BacklinkResolver + tests
        // onto WSLinkRepository (= the old LinkIndex actor hid this
        // collision behind a manual dedupe; = WSLinkRepository relies on
        // SwiftData's @Attribute(.unique) enforcement).
        self.id = "\(sourceDocID):\(line):\(targetRef)"
        self.sourceDocID = sourceDocID
        self.targetRef = targetRef
        self.targetDocID = targetDocID
        self.line = line
        self.offset = offset
        self.createdAt = Date()
    }
}
