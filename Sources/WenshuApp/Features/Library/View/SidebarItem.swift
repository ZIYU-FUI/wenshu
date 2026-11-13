// SidebarItem.swift
//
// c sidebar MVVM cleanup (= (see OOB.md #2026-09-22) OOB '
// , UI//'): extracted from the deleted
// NewLibraryOutlineView.swift (the pre-v1.69e 2366-LOC legacy
// sidebar that packed view body + selection handling + state
// persistence + business logic into one file).
//
// SidebarItem is the data model (= a Hashable + Codable enum
// that identifies one row in the sidebar tree = the union of
// all selectable rows: shelf / book / folder / reference
// category). Lives in its own file (= no SwiftUI import) so:
//   - PreviewPane / WorkspaceView / ShellMiddleColumn can read
//     the same SidebarItem without importing the sidebar view
//     (= clean module boundary).
//   - ShellState.sidebarSelection (= the Codable property in
//     State/ShellState.swift) persists the selection via the Codable
//     conformance here.
//   - Tests (= WorkspaceViewPreviewScopeTests + future tests)
//     can target the enum independently of any view code.

import Foundation

/// Identifies a single sidebar item for List(selection:) binding.
/// composite enum (= book OR reference category) because
/// Apple HIG allows ONE selection type per List, so we unify
/// both selection kinds into one Hashable enum.
enum SidebarItem: Hashable, Codable {
    case book(UUID)
    /// (see OOB.md #2026-08-31) (sidebar feedback bundle #1+2): shelf
    /// (= first tree level) is now a clickable tree row, not just a
    /// SwiftUI Section header. Tagging it with .shelf(UUID) lets
    /// the user select a shelf directly (= will eventually scope preview
    /// pane to the shelf; for now it just keeps the shelf row
    /// highlighted when selected).
    case shelf(UUID)
    // (see OOB.md #2026-08-31) (sidebar feedback bundle #3): folder row
    // (= third tree level, e.g. Worldview / Characters / Chapter Outline / Novel Body /
    // Novel Drafts). Tagging with .folder(bookId, folderName) lets
    // the user select a folder directly; preview pane will scope to
    // that folder's content (= shows the .md files inside).
    case folder(bookId: UUID, folderName: String)
    case referenceCategory(String) // = EntityCategory.directoryName

    /// The catch-all category row (= the row that collects the references
    /// no category claims). It has no category behind it, so it cannot use
    /// the category route (= that route carries a directory name that
    /// resolves back to a category). Its own case value keeps it
    /// distinguishable from a real category, and the preview pane
    /// resolves it to the same "no category" scope the root row uses.
    case referenceUnclassified

    /// tag selection. Selecting a tag filters the
    /// preview pane / card grid to references carrying that tag.
    /// Cross-cutting (= orthogonal to category + entityType).
    case tag(String)

    /// The HIDDEN "全部分段" row (= every section of the whole 文枢库).
    ///
    /// The boss's rule (= 2026-11-12): "如果选文枢，没有对应的目录树要
    /// 对应跳转，能否跳转到隐藏的全部分段，这个全部分段不在 UI 上显示，
    /// 但会在文枢聊天 teb 被选中时命中" (= the 文枢 chat page names no
    /// visible tree row, = so it names THIS one, = which the tree does
    /// not draw).
    ///
    /// ⇒ ⇒ ⇒ SO IT IS A ROW WITHOUT A NODE: = the tree never renders
    /// it (= so the user sees no row to click), = but the selection can
    /// name it (= so the chat's 文枢 page and the tree agree on "the
    /// whole library").
    case allLibrary

    static let referenceLibraryRoot = SidebarItem.referenceCategory("__root__")

    /// The book this row belongs to.
    ///
    /// A book row names its own book and a folder row names its parent
    /// book (= a folder is a sub-row of one). Every other row (= a
    /// shelf, a reference category, the unclassified row, a tag, no
    /// row) names no book.
    ///
    /// The board follows the session, and the session names its book,
    /// so this is how a sidebar click reaches a session (= and through
    /// it, the session's board).
    var bookId: UUID? {
        switch self {
        case let .book(id):
            return id
        case let .folder(bookId, _):
            return bookId
        case .shelf, .referenceCategory, .referenceUnclassified, .tag, .allLibrary:
            return nil
        }
    }
}
