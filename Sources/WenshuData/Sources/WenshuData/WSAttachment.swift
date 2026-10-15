//
//  Persistence/WSAttachment.swift
//
//   : WSAttachment.
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
    public var parentKind: String
    public var parentID: String
    public var filename: String
    public var mimeType: String
    public var sizeBytes: Int
    public var data: Data?
    public var externalPath: String?
    public var createdAt: Date

    public init(id: String, parentKind: String, parentID: String, filename: String, mimeType: String, sizeBytes: Int) {
        self.id = id
        self.parentKind = parentKind
        self.parentID = parentID
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.createdAt = Date()
    }

    /// Storage invariant: exactly one of data / externalPath is set.
    public var hasValidStorage: Bool {
        (data != nil) != (externalPath != nil)
    }
}

// Apple HIG canonical Identifiable conformance for SwiftUI
// Table selection (= `selection: Set<WSAttachment.ID>` is the
// per-row selection set). The default `ID == String` (= reuses
// the existing `@Attribute(.unique) var id: String`; = no
// separate UUID tracking; = SwiftData PersistentIdentifier is
// not entangled here because the id is the model-stored unique
// string; = the conformance is free because Swift's Identifiable
// protocol only requires `var id: ID` and `ID: Hashable`).
extension WSAttachment: Identifiable {}
