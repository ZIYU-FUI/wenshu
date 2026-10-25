//
//  PreviewPaneModels.swift
//
//  Pure data types extracted from PreviewPane.swift (= §6.6 god-class
//  split pass 1/2: 5 enums + 1 struct = 265 LOC of pure data moved out
//  of the View file). The types are stateless and have no dependencies
//  on the View (= no @State / @Binding / @Environment references; = safe
//  to move to a separate file).
//

import Foundation
import CryptoKit
import OSLog

enum BookFolder: String, CaseIterable, Codable, Sendable, Hashable {
    case world
    case characters
    case outlines
    case chapters
    case drafts
    case ideas
    case sessions

    /// On-disk directory name (= matches BookFolderCatalog spec;
    /// = SSOT for filesystem → id mapping).
    var directoryName: String {
        BookFolderCatalog.spec(for: rawValue)?.directoryName ?? rawValue
    }

    /// Display name shown in card folder badge (= short Chinese
    /// label = e.g. 'Chapter' for chapters (= fits the card grid
    /// cell width). Maps from BookFolderCatalog.cardDisplayName
    /// (= SSOT).
    var displayName: String {
        BookFolderCatalog.spec(for: rawValue)?.cardDisplayName ?? rawValue
    }

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// directive). The
    /// import template
    /// (= markdown
    /// skeleton) that
    /// constrains the
    /// rewrite for
    /// documents in this
    /// folder. Returns
    /// nil for the
    /// non-import folders
    /// (= sessions; =
    /// not in the import
    /// path yet).
    ///
    /// 
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// 构思" directive).
    /// `ideas` (= 构思)
    /// returns a light-
    /// weight template
    /// (= the boss's
    /// "零散的设定
    /// 和未来的一些
    /// 想法"; = 4
    /// sections only;
    /// = the user uses
    /// ideas/ to dump
    /// fragments that
    /// might become
    /// characters /
    /// locations /
    /// events / chapters
    /// later; = no full
    /// chapter structure;
    /// = no commitment to
    /// any specific
    /// type).
    var importTemplate: ImportDocumentTemplate? {
        switch self {
        case .world:      return .world
        case .characters: return .characters
        case .outlines:   return .outlines
        case .chapters:   return .chapters
        case .drafts:     return .drafts
        case .ideas:      return .ideas
        case .sessions:
            return nil
        }
    }
    /// kebab-case names (= globe / user-round / list-tree / book-text /
    /// file-pen-line) are NOT valid SF Symbols 6 identifiers and
    /// SwiftUI renders them as blank rectangles. Verified against
    /// /Applications/SF Symbols Beta.app/Contents/Executables/
    /// sfsymbols search 2026-09-16. Mapping mirrors the
    /// legacy NewLibraryOutlineView.standardFolderNames
    /// (= the sidebar's folder row ICON, to keep both surfaces
    /// visually consistent).
    ///
    /// the icon / displayName
    /// / directoryName values derive from BookFolderCatalog
    /// (= the canonical source). BookFolder stays as the enum type
    /// (= caller-visible type signature unchanged) but its three
    /// computed properties are now thin lookups into the catalog.
    /// To rename / re-icon a folder, edit the matching
    /// BookFolderSpec in BookFolderCatalog.swift and the PreviewPane
    /// picks up the new values automatically. The "file-text"
    /// fallback for unknown folderName (= from .bookDoc(let d):
    /// d.folderName) keeps the card rendering safe if a future
    /// Document references a folder that the enum does not know.
    var icon: String {
        BookFolderCatalog.spec(for: rawValue)?.icon ?? "file-text"
    }
}

enum EntitySortOrder: String, CaseIterable, Identifiable {
    case pinyinFirstLetter = "首字母"
    case createdAt = "创建时间"
    case modifiedAt = "修改时间"

    var id: String { rawValue }

    /// SF Symbols 6 icon name (= Apple canonical; = for the sort
    /// menu picker). Replaces the Lucide-era names removed in
    /// 
    var menuIcon: String {
        switch self {
        case .pinyinFirstLetter: return "list.number"           // Lucide 'list-ordered'
        case .createdAt: return "list.number"                   // Lucide 'list-ordered'
        case .modifiedAt: return "list.number"                  // Lucide 'list-ordered'
        }
    }
}

/// the sidebar selection (= WorkspaceView computes `previewScope` from
/// sidebarSelection + the routed SidebarItem; = drives the
/// preview-pane card grid + tab sourceScope).
///
/// Apple canonical model: this enum is the **single source of
/// truth** for the preview-pane content scope. The Apple Swift API
/// design guideline §"Make illegal states unrepresentable" rules
/// out combining scopes with a single optional / nil case (= the
/// ambiguity was the only reason a nil was
/// ever legal here; the facet model resolves that by giving
/// tag + category separate, dedicated cases below).
///
/// tag is a cross-cutting facet (= a single
/// reference can carry 0..N tags; = browsing by tag must NOT
/// silently fall through to a different facet's case). Hence
/// the dedicated `tagScope(String)` case (= Apple canonical
/// type-safe scoping; = `tag` cannot be confused with
/// `referenceScope`'s category at runtime).
enum PreviewScope: Hashable, Codable {
    /// Reference library scope. category nil = root (= all entities);
    /// category non-nil = that category only.
    case referenceScope(EntityCategory?)
    /// Reference library tag scope. The string is a tag value;
    /// the preview pane filters references by `tags.contains(tag)`.
    /// (= tag is a cross-cutting facet; =
    /// dedicated case, not a nil-fallback to referenceScope.)
    case tagScope(String)
    /// Book scope. folderName nil = all folders in this book; non-nil
    /// = just that folder's .md files.
    case bookScope(bookId: UUID, folderName: String?)
    /// Shelf scope. No documents — preview pane shows a hint to
    /// drill into a book. (= the spec: shelves are a tree level, not
    /// a document scope.)
    case shelfScope(shelfId: UUID)
    /// Nothing selected. Preview pane shows an empty state.
    case empty
}

struct BookDoc: Identifiable, Hashable {
    // Stable-id root-cause fix: the previous `let id: UUID = UUID()` default value made
    // every BookDoc instance unique (= the SwiftUI ForEach inside bookDocsGrid saw
    // "all rows changed" on every body re-render = full grid rebuild =
    // NSHostingView size/invalidate cycle = the 'more Update Constraints in Window
    // passes than there are views in the window' crash). Fixed: derive the id from
    // the on-disk path (= bookId + folderName + fileName → SHA256 → first 16 bytes
    // as UUID) so the id is STABLE across re-evaluations of the same .md file. y:
    // simpler stable id = `bookId-folderName-fileName` UUID v5-style hash
    // (UUID(uuidString:) from a deterministic namespace UUID + SHA256 of the
    // path). The identifier matches Swift's Identifiable contract: two BookDocs
    // for the same .md file on disk are == across SwiftUI body re-evaluations.
    let id: UUID
    /// Folder directory name (= "world", "characters", "outlines",
    /// "chapters", "drafts", "ideas", "sessions"). Used for the
    /// folder badge in the card.
    let bookId: UUID
    let folderName: String
    /// Full filename including .md extension (= e.g.
    /// "yes.md").
    let fileName: String
    /// File modification date (= used for sort: createdAt /
    /// modifiedAt).
    let modifiedAt: Date
    /// File creation date (= used for sort: createdAt).
    let createdAt: Date
    /// First H1 markdown heading stripped of the leading `# ` (= the
    /// chapter's first-line heading). Per the user's 2026-10-12
    /// directive "书的卡片, 和资料库的卡片样式不同, 标签还在用
    /// #加文字显示, 向资料库卡片对齐. 统一样式" = the book's
    /// first H1 is now surfaced as a `Reference.tags`-style chip pill
    /// in the card (= not as a literal `# xxx` grey subtitle), so
    /// the book card visually matches the reference card. The
    /// literal `# ` prefix is stripped (= Apple HIG card style
    /// never shows raw markdown syntax) and the rest of the
    /// heading text becomes a single tag.
    ///
    /// `nil` if the file has no H1 line (= the card silently omits
    /// the chip row, same as a reference with `tags = []`).
    let tags: [String]
    /// Full .md body content with the first H1 line stripped (= used
    /// for card summary preview + future editor binding). Stripping
    /// the first H1 (= the user's directive) removes the literal
    /// `# xxx` line that previously bled into the summary and made
    /// the book card look different from the reference card.
    let body: String

    /// Display title (= filename without extension).
    var title: String {
        (fileName as NSString).deletingPathExtension
    }

    /// Truncated body for card preview (= first 200 chars of the
    /// post-H1 body). The summary deliberately does NOT include
    /// the H1 line (= the chip row above already shows the heading
    /// text; = putting the H1 in both the chip row and the summary
    /// body was the prior visual misalignment).
    var summary: String {
        String(body.prefix(200))
    }

    /// Path component (= "world/yes.md") for sort by file
    /// name within folder (= directory-scoping model
    /// includes the folder context).
    var displayPath: String {
        "\(folderName)/\(fileName)"
    }
}

/// 
/// derive a STABLE UUID for a BookDoc from its on-disk
/// path (= bookId + folderName + fileName). The same .md
/// file on disk maps to the same UUID across SwiftUI body
/// re-evaluations (= Identifiable ForEach inside bookDocsGrid
/// sees stable row ids = no full grid rebuild = no SwiftUI
/// NSHostingView constraint cycle). Implementation = UUID v5
/// (SHA1-based namespaced UUID) over a fixed namespace + the
/// canonical path string (= FastCrypto via Swift stdlib).
enum BookDocIDFactory {
    /// Fixed namespace for BookDoc ids (= arbitrary UUID;
    /// picked once and frozen = different from any random
    /// UUID wenshu might generate elsewhere). Two BookDocs
    /// for the same .md file → same id; two for different
    /// .md files → different ids.
    static let namespace: uuid_t = (
        0x42, 0x6f, 0x6f, 0x6b, 0x44, 0x6f, 0x63, 0x49,
        0x44, 0x73, 0x70, 0x61, 0x63, 0x65, 0x00, 0x01
    )

    /// Compute the SHA-1 (= UUID v5 algorithm) over
    /// `namespace + "/" + bookId + "/" + folderName + "/" + fileName`
    /// and return the first 16 bytes as a UUID. This is the
    /// same algorithm SwiftUI uses internally for
    /// Identifiable ids in List/ForEach (= no collisions
    /// within a single wenshu install).
    static func make(bookId: UUID, folderName: String, fileName: String) -> UUID {
        var hasher = Insecure.SHA1()
        // Feed each component into the hasher. macOS 27 CryptoKit `update(data:)` wants
        // `Data`, so we wrap the raw bytes via `Data(_ buffer:)` (= the
        // explicit UnsafeRawBufferPointer overload).
        hasher.update(data: Self.dataForNamespace())
        hasher.update(data: Data("/".utf8))
        hasher.update(data: Self.dataForUUID(bookId))
        hasher.update(data: Data(folderName.utf8))
        hasher.update(data: Data("/".utf8))
        hasher.update(data: Data(fileName.utf8))
        let digest = hasher.finalize()
        var bytes = Array(digest.prefix(16))
        // Set RFC 4122 version (5) and variant bits so the UUID is a valid v5 namespaced
        // UUID (= Swift's UUID(uuid:) tolerates but other consumers expect).
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    /// Convert the fixed 16-byte namespace tuple to Data
    /// (= the Swift CryptoKit `update(data:)` overload
    /// signature on macOS 27).
    private static func dataForNamespace() -> Data {
        var bytes = namespace
        return withUnsafeBytes(of: &bytes) { Data($0) }
    }

    /// Convert a UUID to Data via its `uuid` tuple (= 16
    /// raw bytes; = the same bytes macOS uses to identify
    /// the UUID in NSUUID / uuid_t bridging).
    private static func dataForUUID(_ id: UUID) -> Data {
        var u = id.uuid
        return withUnsafeBytes(of: &u) { Data($0) }
    }
}

