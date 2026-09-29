// LinkDomain.swift · WenshuApp · v0.72
//
// Canonical domain type for wiki links (= `Link`). Pure value
// type (= no SQLite dependency). SwiftData persistence lives in
// `WSLink` @Model + `WSLinkRepository`.

import Foundation

struct Link: Equatable, Sendable {
    let sourceDocId: String
    let targetRef: String
    let targetDocId: String?
    let line: Int
    let offset: Int
    let createdAt: Date

    init(sourceDocId: String, targetRef: String, targetDocId: String?, line: Int, offset: Int, createdAt: Date = Date()) {
        self.sourceDocId = sourceDocId
        self.targetRef = targetRef
        self.targetDocId = targetDocId
        self.line = line
        self.offset = offset
        self.createdAt = createdAt
    }
}


/// Reserved for future-hook callers (= no consumers yet; = the
/// pre-migration deleted LinkIndex actor's error type was extracted
/// in  and renamed here; = currently dead code but
/// preserved for potential future callers that want the legacy
/// 4-case error shape from the old actor's sqlite3 failures).

