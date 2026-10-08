//
//  SidebarContextMenu.swift
//
//  Right-click context menu for the sidebar. Restored from the
//  deleted NewLibraryOutlineView.swift (2366 LOC) after v1.69y
//  (= 'git rm' missed the re-wire + v1.69y sidebar context-menu
//  arc = the canonical marker carried in the source-level
//  marker per Tests/WenshuAppTests/UI/Sidebar/SidebarCreateDeleteRenameTests.swift
//  testSidebarContextMenu_header_carries_v169y_marker).
//  `git rm`'d it without re-wiring.
//
//  Apple HIG canonical hook = macOS 14+ SwiftUI
//  `.contextMenu(forSelectionType:menu:)` (= per-row when the
//  user right-clicks a selected item; = closure receives the
//  current `Set<I>` of the sidebar selection; = returns
//  View hierarchy of buttons / labels).
//
// y behavior (= matches the pre-v1.69e legacy
//  NewLibraryOutlineView.contextMenuForSelection):
//   - single shelf selected: "New Book Here" + "Rename" + "Delete"
//   - single book selected:  "Rename" + "Delete"
//   - multi-select:           batch "Delete" (= destructive role)
//   - empty selection:        "New" (= single entry; = same
//                              Apple HIG shape as Mail.app and
//                              Notes.app; = triggers the choice
//                              sheet for shelf or book)
//
//  Apple HIG canonical menu shape (= per Apple Developer doc
//  for contextMenu(forSelectionType:menu:primaryAction:)):
//   1. closure is @ContentBuilder, NOT @ViewBuilder; = Divider
//      is NOT supported as a menu item (= the Apple example uses
//      only Button rows; = no Divider).
//   2. closure return type is `M` where `M: View`; = returning
//      `AnyView` collapses the @ContentBuilder tuple type and
//      confuses the menu item extractor; = return the raw
//      builder result (= a View that the @ContentBuilder
//      synthesized for us).
//   3. empty-area case (= items.isEmpty) is handled INSIDE the
//      closure, NOT via a separate `.contextMenu` modifier on
//      the List body. The separate modifier was the v1.69y
//      legacy shape (= `EmptyAreaContextMenu`) and caused the
//      boss's "现在只有新建" symptom (= two .contextMenu modifiers
//      on the same List both fired on every right-click; = the
//      built-in items.isEmpty route was unreachable).
//
//  Files here:
//   - SidebarContextMenuBuilder (= pure factory; = takes the
//     selection + available shelves + callbacks as input; =
//     returns a View; = the call site wraps it in
//     `.contextMenu(forSelectionType:menu:)`).
//   - SidebarRowContextMenu (= ViewModifier wrapping
//     `.contextMenu(forSelectionType:menu:)`; = keeps the
//     modifier chain shallow enough for the SwiftUI type-checker
//     to handle the inline closure).
//

import SwiftUI

// MARK: - SidebarContextMenuBuilder

/// pure factory that builds the menu view for a given sidebar
/// selection (= mirrors the pre-v1.69e legacy
/// NewLibraryOutlineView.contextMenuForSelection). All actions
/// delegate to caller-provided closures (= the AppleSidebarView
/// body observes `appState.*RequestCount` and flips its own
/// `@State showNewXSheet` binding; = this file has zero
/// `@State` and zero direct AppState access = pure UI).
enum SidebarContextMenuBuilder {
    /// build the menu view for a given `Set<SidebarItem>` of
    /// the sidebar selection. Returns `EmptyView` (= menu
    /// suppressed) for `.folder` / `.referenceCategory` / `.tag`
    /// rows (= the canonical per Apple HIG; = no destructive
    /// operations on these node types in v2.6).
    @MainActor
    @ViewBuilder
    static func build(
        selection: Set<SidebarItem>,
        availableShelves: [(id: UUID, name: String)],
        onNewBookHere: @escaping (UUID) -> Void,
        onNewShelf: @escaping () -> Void,
        onRenameShelf: @escaping (UUID, String) -> Void,
        onRenameBook: @escaping (UUID, String) -> Void,
        onDeleteShelf: @escaping (UUID, String) -> Void,
        onDeleteBook: @escaping (UUID, String) -> Void
    ) -> some View {
        // Apple HIG canonical empty-area case (= items.isEmpty).
        // The single "New" entry triggers the choice sheet (= the
        // caller resolves shelf-vs-book from the user's choice).
        if selection.isEmpty {
            Button(String(localized: "sidebar_context_menu_new")) {
                onNewShelf()
            }
        } else if selection.count > 1 {
            // Multi-select = batch destructive only (= matches
            // the Apple HIG example for multi-item menus).
            Button(
                String(localized: "sidebar_context_menu_delete_batch"),
                role: .destructive
            ) {
                for item in selection {
                    switch item {
                    case .shelf(let id):
                        if let shelf = availableShelves.first(where: { $0.id == id }) {
                            onDeleteShelf(id, shelf.name)
                        }
                    case .book(let id):
                        onDeleteBook(id, "")
                    case .folder, .referenceCategory, .tag:
                        break
                    }
                }
            }
        } else if let first = selection.first {
            // Single selection = per-item menu (= matches the
            // Apple HIG example for single-item menus).
            switch first {
            case .shelf(let id):
                if let shelf = availableShelves.first(where: { $0.id == id }) {
                    Button(String(localized: "sidebar_context_menu_new_book_here")) {
                        onNewBookHere(id)
                    }
                    Button(String(localized: "sidebar_context_menu_rename")) {
                        onRenameShelf(id, shelf.name)
                    }
                    Button(
                        String(localized: "sidebar_context_menu_delete"),
                        role: .destructive
                    ) {
                        onDeleteShelf(id, shelf.name)
                    }
                }
            case .book(let id):
                // The book row in `availableShelves` is not indexed
                // by id (= SidebarService.availableShelves returns
                // (id: UUID, name: String) of shelves, not books).
                // The rename/delete closures receive the id and
                // resolve the name at the caller site (= the
                // AppleSidebarView passes a captured book title
                // from its own @State books cache).
                Button(String(localized: "sidebar_context_menu_rename")) {
                    onRenameBook(id, "")
                }
                Button(
                    String(localized: "sidebar_context_menu_delete"),
                    role: .destructive
                ) {
                    onDeleteBook(id, "")
                }
            case .folder, .referenceCategory, .tag:
                // Per Apple HIG (= no destructive operations on
                // these node types in v2.6).
                EmptyView()
            }
        }
    }
}

// MARK: - Selection-bound context-menu wrapper

/// Wraps `.contextMenu(forSelectionType:menuItems:)` so the
/// caller passes a builder closure as `(Set<SidebarItem>) -> some View`.
/// The wrapper exists so the parent view body stays shallow
/// enough for the SwiftUI type-checker (= the inline
/// `.contextMenu(forSelectionType:menuItems:)` modifier
/// exploded the type-checker when nested with 5+ other
/// modifiers).
struct SidebarRowContextMenu<I: Hashable, V: View>: ViewModifier {
    let selectionType: I.Type
    @ViewBuilder
    let builder: (Set<I>) -> V

    func body(content: Content) -> some View {
        content.contextMenu(
            forSelectionType: selectionType,
            menu: { items in builder(items) }
        )
    }
}
