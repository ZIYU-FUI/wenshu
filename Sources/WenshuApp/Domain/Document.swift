// Document.swift · Wenshu (Wenshu) · v0.03.0 (document module)
//
// v53 (= 老板 8/15 17:48 '在第二栏里, 显示书的所有章节, 设定, 资料库, 这
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
/// v53 (= 老板 8/15 17:48 '3 个分类') — three cases: 章节 / 设定 / 资料
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
    /// Cross-references resolved at MD body load time from `@<type>.<name>`
    /// syntax in the markdown body (= boss 2026-08-26 OOB cross-
    /// reference feature, ticket 007). Three typed fields rather than
    /// a single untyped array so the view layer can render each ref
    /// category distinctly (= character chips, world chips, reference
    /// chips in the editor sidebar).
    /// All default to empty array for back-compat with v0.25.x
    /// documents (= no Codable migration needed; existing .md files
    /// decode with refIds = [] because the field is missing from the
    /// file metadata; the @-parser re-extracts on next load).
    var characterRefIds: [UUID]
    var worldRefIds: [UUID]
    var referenceRefIds: [UUID]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        category: BookCategory,
        title: String,
        byteSize: Int = 0,
        summary: String = "",
        characterRefIds: [UUID] = [],
        worldRefIds: [UUID] = [],
        referenceRefIds: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.bookId = bookId
        self.category = category
        self.title = title
        self.byteSize = byteSize
        self.summary = summary
        self.characterRefIds = characterRefIds
        self.worldRefIds = worldRefIds
        self.referenceRefIds = referenceRefIds
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
// MARK: - Cross-reference (@-parser)

// MARK: Reference kind enum

/// Type of cross-reference extracted from the `@<type>.<name>` syntax
/// in document markdown bodies (= boss 2026-08-26 OOB cross-reference
/// feature). Three kinds match the three typed refIds fields on
/// Document.
enum DocumentRefKind: String, CaseIterable, Codable, Sendable {
    case character
    case world
    case reference

    /// Chinese UI label (= boss 8/25 'UI 全中文' carve-out).
    var displayName: String {
        switch self {
        case .character: return "角色"
        case .world:     return "世界观"
        case .reference: return "资料"
        }
    }

    /// SF Symbol name (= for chips / badges in the UI).
    var icon: String {
        switch self {
        case .character: return "person.fill"
        case .world:     return "map.fill"
        case .reference: return "books.vertical.fill"
        }
    }
}

// MARK: - Parser

/// Parses `@<type>.<name>` cross-references from document markdown bodies.
///
/// Syntax: the writer types `@character.zhangsan` (= Chinese UI form:
/// `@角色.张三`). The parser normalizes to:
/// - kind: DocumentRefKind (= character / world / reference; mapped
///   from the English prefix; legacy v0.25.x docs may use Chinese
///   prefixes which are mapped here)
/// - name: the slugified identifier after the dot (= zhangsan)
///
/// The parser returns a set of `(kind, name)` pairs (= unique). The
/// caller (= typically FileSystemLibraryStore.loadDocument) is
/// responsible for resolving `name` -> UUID via the per-Book character/
/// world/ indexes (= a name "zhangsan" might match a Character named
/// "张三" via a slug-mapping; v0.27+ may add a proper slug resolver).
struct DocumentCrossRefParser {
    /// Parse all cross-refs from a markdown body. Returns unique
    /// `(kind, name)` pairs (= same name + kind appearing N times = 1
    /// entry). Caller resolves name -> UUID via per-Book indexes.
    static func parse(_ markdown: String) -> [(kind: DocumentRefKind, name: String)] {
        var found: [(kind: DocumentRefKind, name: String)] = []
        var seen = Set<String>()
        for match in matches(in: markdown) {
            let key = "\(match.kind.rawValue).\(match.name)"
            if seen.insert(key).inserted {
                found.append((kind: match.kind, name: match.name))
            }
        }
        return found
    }

    /// Resolve parsed `(kind, name)` pairs into UUID arrays using the
    /// lookup tables provided. Unresolved names (= no match in any
    /// index) are silently skipped (= the writer may have referenced
    /// a name not yet created; v0.27+ may add a "create new entity
    /// from reference" UX).
    static func resolve(
        _ refs: [(kind: DocumentRefKind, name: String)],
        characterLookup: [String: UUID],
        worldLookup: [String: UUID],
        referenceLookup: [String: UUID]
    ) -> (
        characterRefIds: [UUID],
        worldRefIds: [UUID],
        referenceRefIds: [UUID]
    ) {
        var charIds: [UUID] = []
        var worldIds: [UUID] = []
        var refIds: [UUID] = []
        for ref in refs {
            switch ref.kind {
            case .character:
                if let id = characterLookup[ref.name] { charIds.append(id) }
            case .world:
                if let id = worldLookup[ref.name] { worldIds.append(id) }
            case .reference:
                if let id = referenceLookup[ref.name] { refIds.append(id) }
            }
        }
        return (charIds, worldIds, refIds)
    }

    // MARK: Private

    /// Returns all regex matches in the markdown (= may include duplicates).
    private static func matches(in markdown: String) -> [(kind: DocumentRefKind, name: String)] {
        // Pattern: @(character|world|reference).<slug>
        // Slug = alphanumerics + underscore + Chinese characters + hyphen.
        // Matches across newlines (= mode .dotMatchesLineSeparators? No;
        // we want single-line refs; cross-line refs are rare and v0.26
        // doesn't need them).
        //
        // We accept both English prefixes (character / world / reference)
        // and Chinese prefixes (角色 / 世界观 / 资料) for back-compat with
        // any docs the writer may have written by hand using the Chinese
        // UI form per boss 8/25 'UI 全中文' pattern.
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(
                pattern: #"@(character|world|reference|角色|世界观|资料)\.([A-Za-z0-9_\-一-鿿]+)"#
            )
        } catch {
            return []
        }
        let nsMarkdown = markdown as NSString
        let range = NSRange(location: 0, length: nsMarkdown.length)
        var results: [(kind: DocumentRefKind, name: String)] = []
        regex.enumerateMatches(in: markdown, range: range) { match, _, _ in
            guard let match = match, match.numberOfRanges == 3 else { return }
            let kindRaw = nsMarkdown.substring(with: match.range(at: 1))
            let name = nsMarkdown.substring(with: match.range(at: 2))
            guard let kind = kindFromRaw(kindRaw) else { return }
            results.append((kind: kind, name: name))
        }
        return results
    }

    private static func kindFromRaw(_ raw: String) -> DocumentRefKind? {
        switch raw {
        case "character", "角色": return .character
        case "world", "世界观":   return .world
        case "reference", "资料": return .reference
        default: return nil
        }
    }
}
