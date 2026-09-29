//
//  WSBody.swift · Wenshu · v2.3 (2026-09-25)
//
//  Standalone @Model for entity body markdown.
//
//  Reasoning: entity body markdown can be arbitrarily large
//  (= tens of thousands of characters for a major character
//  biography). Keeping it in the WSEntity main row would bloat
//  the index query (= every list / find query would drag the
//  body bytes).
//
//  Pattern (= per Aggregate Root in design-check #8):
//  - WSEntity is the root; = WSBody is its child object.
//  - Body cannot be mutated directly (= no public mutation API);
//    every body change goes through `WSEntityRepository
//    .replaceBody(entityID:bodyMarkdown:)` (= which writes both
//    the WSBody row + the WSEntity.touch() in one transaction).
//
//  Storage split:
//  - WSEntity row: structured metadata (= name / kind / tags /
//    kindSpecific / ...).
//  - WSBody row: raw markdown string (= the body).
//  - On-disk: WSBody is the SSOT for body content (= entities/
//    <entity-uuid>.md per FileSystemEntityStore in a later
//    ticket); = the WSBody @Model is the in-memory mirror so
//    SwiftData queries can read the body without FS IO.
//
//  Wait — re-reading the spec: the on-disk entity body lives at
//  `entities/<entity-uuid>.md`. The WSBody @Model is the index
//  layer (= holds the bytes that match the on-disk file). If the
//  on-disk file is missing, WSBody is the fallback (= at startup,
//  load everything from entities/*.md into WSBody rows; = write
//  goes through to both).
//
//  For v2.3 first ship: WSEntity holds `bodyID` as a FK to
//  WSBody. The WSBody row is created alongside the WSEntity
//  row in one repository method. Body markdown IS persisted in
//  WSBody (= SQLite TEXT column; = plenty of space).
//

import Foundation
import SwiftData

@Model
final class WSBody {
    @Attribute(.unique) var id: String
    /// The body markdown (= full text, no truncation).
    var markdown: String
    /// Last-modified timestamp (= updated when the body is
    /// replaced via the repository).
    var updatedAt: Date

    init(id: String, markdown: String, updatedAt: Date = Date()) {
        self.id = id
        self.markdown = markdown
        self.updatedAt = updatedAt
    }

    func replaceBody(_ newMarkdown: String) {
        self.markdown = newMarkdown
        self.updatedAt = Date()
    }
}