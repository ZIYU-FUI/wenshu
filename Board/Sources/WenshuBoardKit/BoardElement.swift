//
//  BoardElement.swift
//  WenshuBoard
//
//  The element model, ported from the reference (teardown §2, §3, §4, §6).
//
//  The shape that matters is not the field list but the invariant: a board,
//  a column and a card are the SAME record. Only the kind differs, and the
//  payload is an open map that the kind decides the meaning of. That is what
//  lets one container hold cards and boards alike, and it is the difference
//  between "a chapter is a blob with a type tag" and "a chapter is a list of
//  addressable things".
//

import Foundation

/// The kinds the reference model defines.
///
/// The reference has nineteen; the two internal ones (a skeleton placeholder
/// and an unknown fallback) are not part of the vocabulary a client stores, so
/// they are not carried here.
public enum BoardElementKind: String, Hashable, Sendable, CaseIterable {
    case board = "BOARD"
    case column = "COLUMN"
    case card = "CARD"
    case link = "LINK"
    case line = "LINE"
    case image = "IMAGE"
    case file = "FILE"
    case commentThread = "COMMENT_THREAD"
    case taskList = "TASK_LIST"
    case task = "TASK"
    case clone = "CLONE"
    case sketch = "SKETCH"
    case annotation = "ANNOTATION"
    case colorSwatch = "COLOR_SWATCH"
    case document = "DOCUMENT"
    case table = "TABLE"
    case alias = "ALIAS"

    /// The kinds that are containers: they hold other elements.
    public static var containers: [BoardElementKind] { [.board, .column] }
}

/// Where an element sits inside its parent.
public struct BoardLocation: Hashable, Sendable {

    /// The placement regime. A board holds two of them and the difference is
    /// the whole point (teardown §4).
    public enum Section: String, Hashable, Sendable, CaseIterable {
        /// A free canvas: `position.x` / `position.y` in points, `position.score`
        /// as the z-order.
        case canvas = "CANVAS"
        /// An ordered list: `position.index` as the ordinal, `position.score`
        /// as the order key.
        case inbox = "INBOX"
        case trash = "TRASH"
        case deleted = "DELETED"
        case attached = "ATTACHED"
        case quickNotes = "QUICK_NOTES"
    }

    /// The position within the section. The two regimes share one struct and
    /// each uses its own fields, exactly as the reference does.
    public struct Position: Hashable, Sendable {
        public var x: Double?
        public var y: Double?
        public var index: Int?
        /// The order key. See `BoardOrderKey`.
        public var score: Int64?
        public var addedDate: Date?
        public var deletedDate: Date?
        public var attachMode: String?
        /// Where the element goes back to when it is restored.
        public var restoreLocation: RestoreLocation?

        public init(
            x: Double? = nil,
            y: Double? = nil,
            index: Int? = nil,
            score: Int64? = nil,
            addedDate: Date? = nil,
            deletedDate: Date? = nil,
            attachMode: String? = nil,
            restoreLocation: RestoreLocation? = nil
        ) {
            self.x = x
            self.y = y
            self.index = index
            self.score = score
            self.addedDate = addedDate
            self.deletedDate = deletedDate
            self.attachMode = attachMode
            self.restoreLocation = restoreLocation
        }
    }

    /// The parent an element returns to when it is restored.
    public struct RestoreLocation: Hashable, Sendable {
        public var parentID: String?
        public var section: Section?

        public init(parentID: String? = nil, section: Section? = nil) {
            self.parentID = parentID
            self.section = section
        }
    }

    public var parentID: String?
    public var section: Section
    public var position: Position

    public init(parentID: String? = nil, section: Section, position: Position = Position()) {
        self.parentID = parentID
        self.section = section
        self.position = position
    }
}

/// The payload of an element.
///
/// The reference registers one writable path per kind and stores the values in
/// one open map (teardown §6: 122 content paths). This is the same idea, with
/// the values as strings: a text card carries Markdown, a table carries a
/// document, an image carries a file reference.
public struct BoardContent: Hashable, Sendable {

    /// The element's title.
    public var title: String?
    /// The element's body. Wenshu stores Markdown here; the reference stores a
    /// ProseMirror document, and the conversion belongs at the boundary.
    public var body: String?
    /// Every other registered path, by path name.
    public var fields: [String: String]

    public init(title: String? = nil, body: String? = nil, fields: [String: String] = [:]) {
        self.title = title
        self.body = body
        self.fields = fields
    }

    public subscript(path: String) -> String? {
        get { fields[path] }
        set { fields[path] = newValue }
    }
}

/// Who made an element and when.
public struct BoardMeta: Hashable, Sendable {
    public var creator: String?
    public var modifiedBy: String?
    public var createdTime: Date?
    public var modifiedTime: Date?
    /// Bumped when the content changed, not when the element merely moved.
    /// The reference keeps the two apart so a drag does not dirty the board.
    public var significantModified: Date?
    public var platform: String?
    public var versionID: String?

    public init(
        creator: String? = nil,
        modifiedBy: String? = nil,
        createdTime: Date? = nil,
        modifiedTime: Date? = nil,
        significantModified: Date? = nil,
        platform: String? = nil,
        versionID: String? = nil
    ) {
        self.creator = creator
        self.modifiedBy = modifiedBy
        self.createdTime = createdTime
        self.modifiedTime = modifiedTime
        self.significantModified = significantModified
        self.platform = platform
        self.versionID = versionID
    }
}

/// One element: a board, a column, a card, a task row.
public struct BoardElement: Identifiable, Hashable, Sendable {
    public var id: String
    public var kind: BoardElementKind
    public var location: BoardLocation
    public var content: BoardContent
    public var meta: BoardMeta
    /// Per-user permission bitmasks. The reference stores a mask per user and
    /// leaves it nil on a child (= inherited).
    public var acl: [String: UInt32]?

    public init(
        id: String,
        kind: BoardElementKind,
        location: BoardLocation,
        content: BoardContent = BoardContent(),
        meta: BoardMeta = BoardMeta(),
        acl: [String: UInt32]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.location = location
        self.content = content
        self.meta = meta
        self.acl = acl
    }

    /// The order key of this element among its siblings.
    ///
    /// The score means two different things: on a canvas it is the z-order,
    /// in a list it is the order key. The key is therefore only defined in
    /// the list regime, and reading it on a canvas element would silently
    /// hand back a z-index.
    public var orderKey: Int64? {
        location.section == .inbox ? location.position.score : nil
    }

    /// Whether this element sits in the canvas regime.
    ///
    /// The section is the switch between the two placement regimes, and it is
    /// read here so that a reader can tell which fields of the position carry
    /// the meaning.
    public var isOnCanvas: Bool { location.section == .canvas }

    /// Whether this element sits in the ordered-list regime.
    public var isInList: Bool { location.section == .inbox }
}
