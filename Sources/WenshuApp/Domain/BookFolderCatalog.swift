//
//  BookFolderCatalog.swift
//  wenshu
//
// SSOT (= single source of truth) for the 8 standard
//  book sub-folders (= world / characters / outlines / chapters
//  / drafts / sessions / foreshadowing / placeholders). Prior
//  history:
//
//  * SidebarService.swift folderCatalog = 5 user-facing
//    (name, displayName, icon) tuples (= the sidebar row).
//  * PreviewPane.swift BookFolder enum = 8 cases with
//    (directoryName, displayName, icon) (= the card row + the
//    per-book folder child nodes).
//  * BookStore.swift StandardBookFolder enum = 8 cases with
//    (folderName, displayName) (= the Kanban / Todo task scope
//    enum).
//
//  These three (now four after v1.80) parallel sources all describe
//  the same underlying 8 folders with overlapping but
//  inconsistent field sets (= the 'change one folder, edit N
//  sites' footgun). v1.80 caught one such instance (= the 4
//  icon replacements landed in 3 sites instead of 1 because the
//  caller-side review missed the BookFolder enum).
//
//  Resolution: this catalog is the canonical source. The other
//  three sites become thin derivations:
//
//  * SidebarService.folderCatalog → BookFolderCatalog.userFacing
//    mapped to (name, displayName, icon).
//  * PreviewPane.BookFolder.icon / displayName / directoryName
//    → BookFolderCatalog.spec(for: rawValue)?.[icon|displayName|
//    directoryName].
//  * BookStore.StandardBookFolder.folderName / displayName →
//    BookFolderCatalog.spec(for: rawValue)?.[directoryName|
//    displayName].
//
//  Each derived site keeps its own type (= enum vs struct vs
//  tuple) for its caller compatibility (= caller-visible type
//  signature stays unchanged), but the icon + name values
//  flow from this catalog. To add a 9th folder: add one
//  BookFolderSpec literal here (= 1 site edit) + register it
//  in BookFolderCatalog.allBookFolders (= 1 site edit) = done.
//
// displays the sidebar name + card name differently on purpose:
//  sidebar uses the full phrasing (e.g. the long form of the
//  chapter title) to tell the user the folder's purpose; the card
//  uses the short label (e.g. 'Chapter') to fit the grid cell
//  width. Both names are stored in this catalog
//  (= sidebarDisplayName / cardDisplayName). If a future
//  ticket collapses the names, change the catalog fields and the
//  two derived sites pick up the new values automatically.
//
// '8 folders total, but only 5 are user-visible; the icon field
//  is optional (= nil for the 3 internal folders: sessions /
//  foreshadowing / placeholders, which have no UI row to render
//  into; = the catalog still defines the folder for filesystem /
//  scope purposes, but the
//  icon field is not meaningful). The `isUserFacing` flag is
//  the canonical way to check whether the icon will ever
//  draw. A future ticket could collapse sidebarIcon + cardIcon
//  into a single `icon` (= the current 5 user-facing folders
//  all share the same glyph at both surfaces = the 'one
//  entity = one icon' rule that v1.80 established).
//

import Foundation

/// One row in the 8-folder book layout (= immutable, Sendable,
/// value-type). Read-only after construction (= all fields
/// `let`); = the catalog is append-only at the source level.
struct BookFolderSpec: Sendable, Equatable {
    /// Filesystem-stable identifier (= used as the rawValue
    /// for the matching enums at the call sites). Lowercase,
    /// ASCII, kebab-free (= matches `LibraryBootstrapper`'s
    /// standardFolders array order).
    let id: String
    /// On-disk directory name (= currently always == id; =
    /// explicit field for the future case where a folder id
    /// diverges from its directory name, e.g. a renamed
    /// legacy folder).
    let directoryName: String
    /// User-facing label rendered in the sidebar row (= the
    /// full phrasing = the user knows what the folder holds at
    /// a glance).
    let sidebarDisplayName: String
    /// User-facing label rendered in the card grid header (= the
    /// short phrasing = fits the 2-line grid cell without
    /// truncation).
    let cardDisplayName: String
    /// SF Symbol 6 outline glyph for the folder icon. Nil for
    /// internal folders (= sessions / foreshadowing /
    /// placeholders) that never render in the UI (= no
    /// sidebar row, no card row; = the icon would be dead
    /// value). Callers MUST check `isUserFacing` before reading
    /// `icon` (= the type system doesn't enforce non-nil on
    /// internal folders because the catalog is a value type
    /// and the call sites have their own per-folder rendering
    /// logic).
    let icon: String?
    /// `true` = the folder appears in the user-visible sidebar
    /// tree (the 5 user-facing folders). `false` = the folder
    /// exists on disk but is hidden from the sidebar tree
    /// (= internal storage like 'sessions' / 'foreshadowing'
    /// / 'placeholders' = wenshu-internal folders that hold
    /// AI-assisted artifacts the user can browse via the
    /// card grid but should not see as a top-level sidebar
    /// entry).
    let isUserFacing: Bool
}

/// SSOT (= single source of truth) for the 8 standard book
/// sub-folders. Every folder icon, display name, and filesystem
/// directory name in the workspace derives from one of these
/// literals.
///
/// Naming convention:
/// - `world` = the book's mental model (places, rules, magic
///   systems)
/// - `characters` = named entities with relationships
/// - `outlines` = pre-write planning (beat sheets, plot
///   structure, foreshadowing seeds)
/// - `chapters` = the published body of the novel (= chapter
///   .md files)
/// - `drafts` = in-progress / experimental drafts
/// - `sessions` = LLM chat transcripts that produced the book
///   (INTERNAL = not sidebar-visible)
/// - `foreshadowing` = cross-chapter plant / payoff tracking
///   (INTERNAL = not sidebar-visible)
/// - `placeholders` = TODO / hint markers the user plants
///   during drafting (INTERNAL = not sidebar-visible)
enum BookFolderCatalog {
    /// The book universe
    static let world = BookFolderSpec(
        id: "world",
        directoryName: "world",
        sidebarDisplayName: "世界观",
        cardDisplayName: "世界观",
        icon: "globe",
        isUserFacing: true
    )

    /// Named characters
    static let characters = BookFolderSpec(
        id: "characters",
        directoryName: "characters",
        sidebarDisplayName: "角色",
        cardDisplayName: "角色",
        icon: "person.crop.circle",
        isUserFacing: true
    )

    /// Pre-write outline (= beat sheets)
    static let outlines = BookFolderSpec(
        id: "outlines",
        directoryName: "outlines",
        sidebarDisplayName: "章节大纲",
        cardDisplayName: "章节大纲",
        icon: "bookmark.circle",
        isUserFacing: true
    )

    /// The published body (= chapter .md files
    /// live here)
    static let chapters = BookFolderSpec(
        id: "chapters",
        directoryName: "chapters",
        sidebarDisplayName: "小说正文",
        cardDisplayName: "章节",
        icon: "book.closed.circle",
        isUserFacing: true
    )

    /// In-progress drafts
    static let drafts = BookFolderSpec(
        id: "drafts",
        directoryName: "drafts",
        sidebarDisplayName: "小说草稿",
        cardDisplayName: "草稿",
        icon: "book.circle",
        isUserFacing: true
    )

    /// LLM chat transcripts (= internal folder; = NOT
    /// shown in the sidebar; = no icon (= never rendered))
    static let sessions = BookFolderSpec(
        id: "sessions",
        directoryName: "sessions",
        sidebarDisplayName: "会话",
        cardDisplayName: "会话",
        icon: nil,
        isUserFacing: false
    )

    /// Cross-chapter foreshadowing tracker (= internal
    /// folder; = NOT shown in the sidebar; = no icon (= never
    /// rendered))
    static let foreshadowing = BookFolderSpec(
        id: "foreshadowing",
        directoryName: "foreshadowing",
        sidebarDisplayName: "伏笔",
        cardDisplayName: "伏笔",
        icon: nil,
        isUserFacing: false
    )

    /// TODO / hint placeholders the user plants
    /// during drafting; = internal folder; = NOT shown in the
    /// sidebar; = no icon (= never rendered))
    static let placeholders = BookFolderSpec(
        id: "placeholders",
        directoryName: "placeholders",
        sidebarDisplayName: "占位符",
        cardDisplayName: "占位符",
        icon: nil,
        isUserFacing: false
    )

    /// All 8 standard folders, in sidebar display order (=
    /// user-facing folders first, internal folders last).
    /// This order matches the sidebar's natural reading
    /// flow (world → characters → outlines → chapters →
    /// drafts at the top; = sessions / foreshadowing /
    /// placeholders accessible only via the card grid or
    /// the LibraryMigrator path).
    static let allBookFolders: [BookFolderSpec] = [
        world, characters, outlines, chapters, drafts,
        sessions, foreshadowing, placeholders
    ]

    /// The 5 user-facing folders (= sidebar-visible). Used by
    /// SidebarService.folderCatalog as the canonical row list.
    static let userFacing: [BookFolderSpec] = allBookFolders.filter(\.isUserFacing)

    /// Lookup by id (= the same identifier used by
    /// PreviewPane.BookFolder.rawValue and
    /// BookStore.StandardBookFolder.rawValue). Returns nil
    /// if no folder matches (= caller falls back to a sane
    /// default like 'file-text').
    static func spec(for id: String) -> BookFolderSpec? {
        allBookFolders.first(where: { $0.id == id })
    }
}
