// Document.swift · Wenshu (Wenshu) · v0.03.0 (document module)
//
// v53 (= boss 8/15 17:48 '在第二栏里, 显示书的所有章节, 设定, 资料库, 这
// 里的文档需要分类'): the second column of the layout shows a card
// grid (= FCP Browser filmstrip pattern) of MD documents grouped by
// category.
//
// Document = one MD file inside a book. The .md is the source of
// truth for content; Document is the metadata (= title, summary,
// byte size, last-modified). The storage layer reads the .md's bytes
// (= 'summary' is auto-extracted from the first ~100 chars of the body;
// 'title' falls back to the first H1 of the MD, or the filename if no
// H1 is present).
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The shape of Document is locked by `Tests/WenshuAppTests/
// Domain/DocumentTests.swift`. Adding any required field forces the
// architectural decision to surface.
//
// Storage layout (= building on the v0.02.x book / chapter layout):
//   ~/Documents/wenshu/<shelf-id>/<book-id>/
//     book.json
//     chapters/<doc-id>.md   ← BookCategory.chapter
//     settings/<doc-id>.md   ← BookCategory.setting
//     research/<doc-id>.md   ← BookCategory.research
//
// id == filename (= <uuid>.md). Stable across rename (= Apple HIG
// document-based app: id = filesystem identity, title = label).

import Foundation

/// Document category (= what kind of MD file this is in the book).
/// v53 (= boss 8/15 17:48 '3 个分类') — three cases: 章节 / 设定 / 资料
/// 库 (= chapters / settings / research). Three cases is the v0.03.0
/// minimum; v0.04+ can add more (= outline / foreshadowing / notes /
/// drafts) without breaking the contract (= Codable default value
/// handles unknown strings, and the card UI iterates `allCases` so
/// new categories appear automatically).
///
/// The `directoryName` is the actual on-disk folder (= Apple HIG: the
/// filesystem identity for documents in this category). The
/// `displayName` is the card section header label (= Chinese, matches
/// the wenshu design vocabulary). The `icon` is the SF Symbol used in
/// the card.
enum BookCategory: String, CaseIterable, Codable, Sendable {
    case chapter
    case setting
    case research

    /// Filesystem directory name (= the on-disk folder under the book).
    /// Stable across rename (= Apple HIG: directory = identity, not the
    /// category's display label).
    var directoryName: String {
        switch self {
        case .chapter:  return "chapters"
        case .setting:  return "settings"
        case .research: return "research"
        }
    }

    /// Chinese display label for the card section header (= "章节 (3)"
    /// in the second-column cards view).
    var displayName: String {
        switch self {
        case .chapter:  return "章节"
        case .setting:  return "设定"
        case .research: return "资料库"
        }
    }

    /// SF Symbol name for the card's icon (= no thumbnail in wenshu
    /// since MD files have no visual; the symbol carries the visual
    /// weight, FCP Browser does the same when no poster frame exists).
    /// Apple HIG: symbols follow the system font; we use the .large
    /// image scale at render time for empty-state size.
    var icon: String {
        switch self {
        case .chapter:  return "book.closed"
        case .setting:  return "gearshape.2"
        case .research: return "books.vertical.fill"
        }
    }
}

struct Document: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// Parent book. Required (= the document's .md file lives under
    /// the book's directory tree). Same orphan-prevention rationale as
    /// Book.shelfId.
    let bookId: UUID
    var category: BookCategory
    /// Title shown in the card. Falls back to the first H1 of the MD
    /// (= 1-line: '# Title'), or the filename without extension if no
    /// H1 is present. Set by the storage layer when reading the file.
    var title: String
    /// File size in bytes (= 0 if the .md doesn't exist yet — i.e. the
    /// document is a placeholder that hasn't been saved to disk). The
    /// card footer shows this as '1.2 KB' / '234 B' / etc.
    var byteSize: Int
    /// Auto-extracted first ~100 chars of the MD body (with newlines
    /// collapsed to spaces; frontmatter stripped if present). Lets the
    /// user glance at the document's center of gravity (= FCP
    /// Browser's filmstrip thumbnail role) without opening the file.
    /// v0.04+ will allow an explicit `summary` frontmatter field to
    /// override the auto-extracted one.
    var summary: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        category: BookCategory,
        title: String,
        byteSize: Int = 0,
        summary: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.category = category
        self.title = title
        self.byteSize = byteSize
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filename on disk (= `<uuid>.md`). Stable across title renames.
    var filename: String {
        "\(id.uuidString).md"
    }

    /// Full on-disk path (= the book's directory + the category
    /// directory + the filename). The storage layer uses this for read
    /// / write; the view layer doesn't need it (= the view only
    /// cares about the in-memory metadata).
    func onDiskPath(under bookDirectory: URL) -> URL {
        bookDirectory
            .appendingPathComponent(category.directoryName)
            .appendingPathComponent(filename)
    }

    // id-based identity (= Apple HIG document-based convention).
    // Renames change `title` but NOT `id`, so `doc == doc` still
    // holds across renames. SwiftUI List diffing /
    // @Observable change detection / WenshuLibrary selection all
    // assume this.
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}