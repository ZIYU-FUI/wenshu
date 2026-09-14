//
//  Core/LinkGraph/LinkDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 9
//
//  Domain types (Link) extracted from the deleted
//  Core/LinkGraph/LinkIndex.swift (= sqlite3 legacy actor, now obsolete).
//
//  These types are the canonical wenshu-side public API surface for wiki links.
//  The SwiftData-backed persistence lives in Persistence/WSLink (@Model) and is
//  wrapped by Persistence/Repositories/WSLinkRepository (@MainActor).
//
//  Moved 2026-09-13 (= phase 5 ticket 9 — see AGENTS.md §11.4.2).
//

import Foundation

public struct Link: Equatable, Sendable {
    public let sourceDocId: String
    public let targetRef: String
    public let targetDocId: String?
    public let line: Int
    public let offset: Int
    public let createdAt: Date

    public init(sourceDocId: String, targetRef: String, targetDocId: String?, line: Int, offset: Int, createdAt: Date = Date()) {
        self.sourceDocId = sourceDocId
        self.targetRef = targetRef
        self.targetDocId = targetDocId
        self.line = line
        self.offset = offset
        self.createdAt = createdAt
    }
}


/// Reserved for future-hook callers (= no consumers yet; = the
/// pre-Phase 5 deleted LinkIndex actor's error type was extracted
/// in Phase 5 ticket 9 and renamed here; = currently dead code but
/// preserved for potential future callers that want the legacy
/// 4-case error shape from the old actor's sqlite3 failures).

