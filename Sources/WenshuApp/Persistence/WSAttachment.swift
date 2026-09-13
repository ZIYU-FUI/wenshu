//
//  Persistence/WSAttachment.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 9/21: WSAttachment.
//  Mirrors `attachments` table from WenshuWorkspace.swift.
//
//  Polymorphic design (= old schema used `parent_table` + `parent_id`):
//  parentKind (discriminator) + parentID (FK to that kind's table).
//  Allowed parentKind values (= matches old WenshuWorkspace usage):
//    - "chat_message"
//    - "kanban_task"
//    - "book"
//    - "outline"
//
//  Storage strategy:
//    - data: Data?         = inline blob (thumbnails, <1MB files)
//    - externalPath: String? = filesystem path (large files, = wenshu's
//      cache/ directory). Inline + external are mutually exclusive (= one
//      is set, the other is nil).

import Foundation
import SwiftData

@Model
public final class WSAttachment {
    @Attribute(.unique) public var id: String
    var parentKind: String
    var parentID: String
    var filename: String
    var mimeType: String
    var sizeBytes: Int
    var data: Data?
    var externalPath: String?
    var createdAt: Date

    init(id: String, parentKind: String, parentID: String, filename: String, mimeType: String, sizeBytes: Int) {
        self.id = id
        self.parentKind = parentKind
        self.parentID = parentID
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = Date()
    }

    /// Storage invariant: exactly one of data / externalPath is set.
    var hasValidStorage: Bool {
        (data != nil) != (externalPath != nil)
    }
}
