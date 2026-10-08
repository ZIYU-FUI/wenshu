//
//  SidebarContextMenu.swift
//
//  v1.69y source-level marker (= grep traceability for
//  the restore arc carried in the source-level marker
//  per Tests/WenshuAppTests/UI/Sidebar/SidebarCreateDeleteRenameTests.swift
//  testSidebarContextMenu_header_carries_v169y_marker).
//
//  Right-click context menu for the sidebar. v2.4 arc
//  (= post 86aed30df, 1e7383b0b, 6175323c6, 5f7978bef, a35a0ef19):
//
//  v2.0 through v2.3 all assumed the `.contextMenu(forSelectionType:)`
//  hook fired with `Set<SidebarItem>` (= the in-memory
//  SidebarItem enum used by `workspaceUI.sidebarSelection`).
//  Boss's runtime verification with a throwaway probe app
//  (= /tmp/probe/Probe.swift, 2026-10-08) proved the API
//  itself works (= empty area + single + multi all fire
//  correctly on a plain `List(items, selection: $selection)`;
//  = the button rows render and the action closures
//  receive the selection set).
//
//  The actual wenshu bug was a type mismatch. AppleSidebarView
//  declares the List as
//  `List(service.nodes, children: \.children, selection: $selectedNode)`
//  and SidebarRowView applies `.tag(node)` (= the `SidebarNode`
//  struct). So the List's selection type is `SidebarNode`,
//  NOT `SidebarItem`. The .contextMenu(forSelectionType:)
//  modifier's `forSelectionType:` parameter must match the
//  List's selection type exactly; = the macOS 27 menu item
//  extractor silently ignores a type mismatch (= the
//  closure never fires; = "no menu at all on any
//  right-click").
//
//  v2.4 fix:
//  - Change the `forSelectionType:` parameter from
//    `SidebarItem.self` to `SidebarNode.self`.
//  - The closure body receives `Set<SidebarNode>`; =
//    switch on `node.kind` (= the SidebarNode enum) instead
//    of `SidebarItem`. The same logic maps directly:
//    .shelf / .book / .folder / .reference / .referenceCategory
//    / .divider / .tag.
//  - Resolvers return the data needed for the action
//    closures (= the menu no longer needs to know about
//    SidebarItem).
//  - EmptyAreaContextMenu stays in place (= the plain
//    .contextMenu modifier on the List body covers the
//    empty-area right-click; = this is the
//    ONLY reliable way to get an empty-area menu on
//    macOS 27 with an OutlineGroup-backed List).
//
//  Files here:
//   - SidebarContextMenuModifier (= the v2.x selection-bound
//     ViewModifier; = the closure body lives inline here, not
//     in a factory builder; = the closure is a single
//     @ContentBuilder block of Button rows; = no Divider; =
//     no Group; = no AnyView).
//   - EmptyAreaContextMenu (= the empty-area fallback
//     ViewModifier; = shows the single "新建" entry on
//     right-click of the sidebar background; = the macOS 27
//     .contextMenu(forSelectionType:menu:) hook does NOT
//     fire for empty-area right-clicks on OutlineGroup-
//     backed Lists).
//

import SwiftUI

/// wraps the sidebar right-click context menu in a single
/// `ViewModifier`. The `.contextMenu(forSelectionType:menu:)`
/// closure body uses direct Button rows (= Apple HIG canonical
/// per the Apple Developer doc example for
/// `contextMenu(forSelectionType:menu:primaryAction:)`). The
/// `forSelectionType:` parameter is `SidebarNode.self` to
/// match the `List(service.nodes, children:, selection:)`
/// declaration on the sidebar (= the row view applies
/// `.tag(node)`; = the List's selection type is `SidebarNode`).
///
/// Behavior:
///   - empty selection (= empty-area right-click):
///     EmptyView (= empty-area menu is handled by
///     `EmptyAreaContextMenu`, NOT here; = the
///     `forSelectionType:menu:` hook does not fire
///     for empty-area right-clicks on macOS 27
///     OutlineGroup-backed Lists).
///   - single shelf: "New Book Here" + "Rename" + "Delete"
///   - single book:  "Rename" + "Delete"
///   - multi: batch "Delete" (= destructive role)
///   - folder / reference / referenceCategory / divider / tag:
///     empty (= no destructive operations on these node types
///     in v2.6).
struct SidebarContextMenuModifier: ViewModifier {
    let onNewShelf: () -> Void
    let onNewBookHere: (UUID) -> Void
    let onRenameShelf: (UUID, String) -> Void
    let onRenameBook: (UUID, String) -> Void
    let onDeleteShelf: (UUID, String) -> Void
    let onDeleteBook: (UUID, String) -> Void
    let resolveShelf: (UUID) -> (id: UUID, name: String)?
    let resolveBook: (UUID) -> (id: UUID, name: String)?

    func body(content: Content) -> some View {
        content.contextMenu(forSelectionType: SidebarNode.self) { items in
            // Apple HIG canonical menu shape (= direct Button
            // rows; = no Divider; = no Group; = no AnyView).
            if items.count > 1 {
                // Multi-select = batch destructive only.
                Button(
                    String(localized: "sidebar_context_menu_delete_batch"),
                    role: .destructive
                ) {
                    for node in items {
                        switch node.kind {
                        case .shelf:
                            if let shelf = resolveShelf(node.id) {
                                onDeleteShelf(shelf.id, shelf.name)
                            }
                        case .book:
                            if let book = resolveBook(node.id) {
                                onDeleteBook(book.id, book.name)
                            }
                        case .reference, .referenceCategory, .divider, .tag:
                            break
                        }
                    }
                }
            } else if let node = items.first {
                // Single selection = per-item menu.
                switch node.kind {
                case .shelf:
                    if let shelf = resolveShelf(node.id) {
                        Button(String(localized: "sidebar_context_menu_new_book_here")) {
                            onNewBookHere(shelf.id)
                        }
                        Button(String(localized: "sidebar_context_menu_rename")) {
                            onRenameShelf(shelf.id, shelf.name)
                        }
                        Button(
                            String(localized: "sidebar_context_menu_delete"),
                            role: .destructive
                        ) {
                            onDeleteShelf(shelf.id, shelf.name)
                        }
                    }
                case .book:
                    if let book = resolveBook(node.id) {
                        Button(String(localized: "sidebar_context_menu_rename")) {
                            onRenameBook(book.id, book.name)
                        }
                        Button(
                            String(localized: "sidebar_context_menu_delete"),
                            role: .destructive
                        ) {
                            onDeleteBook(book.id, book.name)
                        }
                    }
                case .reference, .referenceCategory, .divider, .tag:
                    // No destructive operations on these node types
                    // in v2.6 (= Apple HIG canonical = empty menu).
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Empty-area right-click wrapper

/// macOS 27's `.contextMenu(forSelectionType:menu:)` does NOT
/// fire for empty-area right-clicks on OutlineGroup-backed
/// Lists (= the items.isEmpty branch of the closure body is
/// unreachable in practice). We pair the selection-bound
/// menu (= SidebarContextMenuModifier) with this plain
/// `.contextMenu` modifier on the List body (= empty-area
/// fallback) so right-clicks anywhere in the sidebar
/// background show the single "新建" entry (= triggers the
/// choice sheet).
struct EmptyAreaContextMenu: ViewModifier {
    let newLabel: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            Button(newLabel, action: action)
        }
    }
}
