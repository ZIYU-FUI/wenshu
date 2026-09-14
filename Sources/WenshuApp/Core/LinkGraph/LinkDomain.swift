//
//  Core/LinkGraph/LinkDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 9
//
//  Domain types (Link + LinkError) extracted from the deleted
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


public enum LinkError: Error, Equatable {
    case openFailed(dbPath: String, message: String)
    case execFailed(sql: String, message: String)
    case bindFailed(message: String)
    case notFound(sourceDocId: String)
}

