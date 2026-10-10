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
    /// v2.7 (= boss 2026-10-09 round-18 "右键
    /// 点资料库，点导入，进到弹窗后，目
    /// 标自动选好资料库。右键点书的时
    /// 候目标自动选好对应的书" directive).
    /// When the user right-clicks the
    /// reference library, the menu adds
    /// an "导入" row that opens the sheet
    /// with `prefillDestination =
    /// .referenceLibrary`. When the user
    /// right-clicks a book, the menu adds
    /// an "导入" row that opens the sheet
    /// with `prefillDestination = .book` +
    /// `prefillBookID = book.id`. Boss
    /// 2026-10-09 round-21 "改成导入，不
    /// 要导入 MD" (= "导入" is the
    /// format-agnostic label; = the
    /// sheet's file-type picker is the
    /// source of truth for which file
    /// types the import accepts; = the
    /// row label must NOT bind to a
    /// single extension).
    let onImportToReferenceLibrary: () -> Void
    let onImportToBook: (UUID) -> Void

    func body(content: Content) -> some View {
        // v2.7 round-33 (= boss "如果当前选中
        // 是别的，但鼠标直接在十二地仙处
        // 右键，点导入，就不能带入" directive):
        // the per-row context menu (=
        // `SidebarRowView`'s
        // `.contextMenu(menuItems:)`) is now the
        // canonical right-click target source
        // (= the right-click hit target IS the
        // row that hosts the menu; = no
        // List-selection routing). The
        // list-level `forSelectionType:` here
        // is now used ONLY for the multi-select
        // batch delete path (= the closure body
        // returns an empty menu when items.count
        // <= 1; = the per-row menu owns the
        // single-click case; = the forSelectionType
        // menu owns the multi-select case).
        content.contextMenu(forSelectionType: SidebarNode.self) { items in
            // Single-item case: per-row menu owns
            // this (= the per-row .contextMenu
            // fires first; = returning EmptyView
            // from the forSelectionType closure
            // suppresses the duplicate menu).
            // Multi-select = batch destructive
            // only (= the v2.6 sidebar feedback
            // bundle canonical = cmd+click 2+
            // rows + right-click = batch delete).
            if items.count > 1 {
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
            }
            // items.count <= 1: no list-level
            // menu items (= the per-row
            // .contextMenu owns the single-
            // click case; = returning nothing
            // = SwiftUI shows no list-level
            // menu; = the per-row menu is
            // the only menu the user sees).
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
