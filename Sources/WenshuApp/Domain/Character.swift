// Character.swift · Wenshu (文枢) · v0.26 (FCP library replica — character entity)
//
// Domain model for a single character (= a fictional person living
// inside a Book). Book-private (= per FCP Role pattern: a "role" is a
// metadata label that rides on the event's clips; here a "character"
// is a metadata label that rides on the book's chapters).
//
// Each character is stored as a `.md` file under
// `books/<book-uuid>/characters/<char-uuid>.md`. The JSON file
// `books/<book-uuid>/characters/characters.json` (= ticket 005's
// FileSystemCharacterStore) holds the index: `[Character]` with id +
// structured fields. The .md body holds the free-form character
// biography / personality / backstory.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 002.

import Foundation

/// Character role (= narrative POV function inside the book). Drives
/// color coding in the editor (= Apple HIG: roles are color-coded
/// per the FCP Role pattern that boss 8/26 OOB references).
/// Five cases cover the most common narrative POV positions:
/// protagonist, antagonist, supporting, narrator, other.
enum CharacterRole: String, CaseIterable, Codable, Sendable {
    case protagonist
    case antagonist
    case supporting
    case narrator
    case other

    /// Chinese display label for the card section header.
    var displayName: String {
        switch self {
        case .protagonist: return "主角"
        case .antagonist:  return "反派"
        case .supporting:  return "配角"
        case .narrator:    return "叙述者"
        case .other:       return "其他"
        }
    }

    /// Hex color string (= ARGB without alpha prefix). Drives the
    /// color coding in the editor when this character is referenced
    /// (= per FCP Role color pattern). v0.26 uses fixed colors; v0.27+
    /// can let the user customize per character.
    var colorHex: String {
        switch self {
        case .protagonist: return "#FF3B30"  // Apple system red
        case .antagonist:  return "#FF9500"  // Apple system orange
        case .supporting:  return "#34C759"  // Apple system green
        case .narrator:    return "#8E8E93"  // Apple system gray
        case .other:       return "#5856D6"  // Apple system purple
        }
    }

    /// SF Symbol name for the card icon.
    var icon: String {
        switch self {
        case .protagonist: return "person.fill"
        case .antagonist:  return "person.fill.viewfinder"
        case .supporting:  return "person.2.fill"
        case .narrator:    return "text.bubble.fill"
        case .other:       return "person.crop.circle.badge.questionmark"
        }
    }
}

/// A single character (= one fictional person inside a Book).
/// Book-private (= Book 1's "张三" and Book 2's "张三" are unrelated
/// entries, even though the names are similar — same FCP Event
/// metadata boundary).
///
/// The full biography lives in the .md body (= free-form markdown
/// the user writes). This struct holds the structured metadata used
/// for the second-column card grid (= boss 8/26 '卡片样式就是展示文档
/// 的重点摘要').
struct Character: Identifiable, Hashable, Codable, Sendable {
    let id: UUID

    /// Parent book. Required.
    let bookId: UUID

    /// Character name shown in the card (= 角色名).
    var name: String

    /// Optional age. v0.27+ may add a `birthDate` field for richer
    /// timeline support.
    var age: Int?

    /// Narrative role (= FCP Role pattern). Drives color coding.
    var role: CharacterRole

    /// Optional one-line narrative arc summary (= 主角从 a 状态经
    /// 过 b 事件最终 c 状态). Drives the card's secondary line.
    var arc: String?

    /// One-line summary shown on the card (= boss 8/26 '卡片样式就是
    /// 展示文档的重点摘要').
    var summary: String

    /// Optional cross-references to other entities:
    /// - worldRefIds: which world entries this character interacts with
    /// - characterRefIds: which other characters this character has
    ///   a relationship with (= family / ally / rival / etc.)
    /// - referenceRefIds: which shelf-shared references back this
    ///   character (= real-world historical figures, etc.)
    /// All stored as plain UUIDs (= not `@<type>.<name>` strings) so
    /// SwiftUI can directly dereference them.
    var worldRefIds: [UUID]
    var characterRefIds: [UUID]
    var referenceRefIds: [UUID]

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        name: String,
        age: Int? = nil,
        role: CharacterRole = .other,
        arc: String? = nil,
        summary: String = "",
        worldRefIds: [UUID] = [],
        characterRefIds: [UUID] = [],
        referenceRefIds: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.name = name
        self.age = age
        self.role = role
        self.arc = arc
        self.summary = summary
        self.worldRefIds = worldRefIds
        self.characterRefIds = characterRefIds
        self.referenceRefIds = referenceRefIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk (= `<uuid>.md`).
    var filename: String {
        "\(id.uuidString).md"
    }

    /// Full on-disk path (= the book's directory + the characters
    /// directory + the filename). Storage layer uses this.
    func onDiskPath(under bookDirectory: URL) -> URL {
        bookDirectory
            .appendingPathComponent("characters")
            .appendingPathComponent(filename)
    }

    // id-based identity (= Apple HIG document-based convention).
    // Renames change `name` but NOT `id`, so `char == char` still
    // holds across renames.
    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}