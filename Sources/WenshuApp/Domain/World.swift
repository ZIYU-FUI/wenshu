// World.swift · Wenshu (文枢) · v0.26 (FCP library replica — world-building entity)
//
// Domain model for a single world-building entry (= a fact about the
// fictional world, geography / lore / event / object / etc.) living
// inside a Book. Book-private (= per FCP Event metadata pattern).
//
// Each entry is stored as a `.md` file under
// `books/<book-uuid>/world/<entry-uuid>.md`. The JSON file
// `books/<book-uuid>/world/world.json` (= ticket 004's
// FileSystemWorldStore) holds the index: `[WorldEntry]` with id +
// structured fields. The .md body holds the free-form world lore.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 001.
//
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The shape of WorldEntry is locked by the spec + the contract
// tests in ticket 023.

import Foundation

/// World-building entry type (= category of the world-building fact).
/// Apple HIG: enum cases match user-visible mental categories (= a
/// user typing world-building thinks "this is a place" / "this is an
/// event" / "this is an object" — not "this is a row of untyped text").
/// v0.27+ may add `magic` / `language` / `religion` etc. (= extensible
/// via standard Swift Codable enum case addition).
enum WorldEntryType: String, CaseIterable, Codable, Sendable {
    case geography
    case lore
    case event
    case object
    case other

    /// Chinese display label for the card section header. Matches
    /// wenshu design vocabulary (= boss 8/25 'UI 全中文').
    var displayName: String {
        switch self {
        case .geography: return "地理"
        case .lore:      return "传说"
        case .event:     return "事件"
        case .object:    return "物品"
        case .other:     return "其他"
        }
    }

    /// SF Symbol name for the card icon. Apple HIG: SF Symbol carries
    /// the visual weight (= wenshu MD files have no thumbnail).
    var icon: String {
        switch self {
        case .geography: return "map.fill"
        case .lore:      return "book.pages.fill"
        case .event:     return "calendar"
        case .object:    return "cube.box.fill"
        case .other:     return "tag.fill"
        }
    }
}

/// A single world-building entry (= one fact about the fictional world
/// inside a Book). Book-private (= Book 1's "Beijing" and Book 2's
/// "Nanjing" are unrelated entries in two different books, even though
/// the names are similar — same FCP Event metadata boundary).
///
/// The full lore text lives in the .md body (= free-form markdown
/// the user writes). This struct holds the structured metadata used
/// for the second-column card grid (= file 001 / boss 8/26 '卡片
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
/// 样式就是展示文档的重点摘要').
struct WorldEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID

    /// Parent book. Required (= the entry's .md file lives under
    /// the book's directory tree). Same orphan-prevention rationale as
    /// Book.shelfId and Document.bookId.
    let bookId: UUID

    /// Type of the world-building entry (= geography / lore / event /
    /// object / other). Drives the section header grouping in the UI.
    var type: WorldEntryType

    /// Name shown in the card. Falls back to the first H1 of the MD
    /// body or the filename without extension (= per Document.title
    /// convention).
    var name: String

    /// One-line summary shown on the card (= 老板 8/26 '卡片样式就是
    /// 展示文档的重点摘要'). Optional: explicit frontmatter `summary`
    /// field overrides auto-extracted first ~100 chars of the .md body.
    var summary: String

    /// Optional cross-references to other entities (= 老板 8/26
    /// '@<type>.<name>' syntax). Resolved at load time by ticket 007
    /// `Document.refIds` parser. Stored as plain UUIDs here (= not
    /// `@<type>.<name>` strings) so SwiftUI can directly dereference
    /// them for "characters in this chapter" UI.
    var characterRefIds: [UUID]

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        type: WorldEntryType = .other,
        name: String,
        summary: String = "",
        characterRefIds: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.type = type
        self.name = name
        self.summary = summary
        self.characterRefIds = characterRefIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk (= `<uuid>.md`). Stable across renames.
    /// Apple HIG: filesystem identity = stable, name = mutable label.
    var filename: String {
        "\(id.uuidString).md"
    }

    /// Full on-disk path (= the book's directory + the world
    /// directory + the filename). Storage layer uses this for read /
    /// write; view layer doesn't need it.
    func onDiskPath(under bookDirectory: URL) -> URL {
        bookDirectory
            .appendingPathComponent("world")
            .appendingPathComponent(filename)
    }

    // id-based identity (= Apple HIG document-based convention).
    // Renames change `name` but NOT `id`, so `entry == entry` still
    // holds across renames. SwiftUI List diffing /
    // @Observable change detection / WenshuLibrary selection all
    // assume this.
    static func == (lhs: WorldEntry, rhs: WorldEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}