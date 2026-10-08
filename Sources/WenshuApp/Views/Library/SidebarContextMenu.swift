//
//  SidebarContextMenu.swift
//
//  Right-click context menu for the sidebar. v2.x arc
//  (= post 5f7978bef / a35a0ef19):
//
//  The v1.69y legacy code used a `AnyView(Group { ... })` factory
//  builder that the macOS 27 menu item extractor dropped the
//  trailing items from (= the boss's 'only 新建 shows' symptom).
//  The v2.0 arc trimmed the factory down to a simple
//  if/else-if pattern (= per Apple HIG canonical from the
//  official Apple Developer doc example for
//  `contextMenu(forSelectionType:menu:primaryAction:)`).
//  v2.0 still wrapped the menu in a `Group { ... Divider ... }`
//  shape; = the boss's third report
//  ('三个都只有新建') confirmed that the wrapping
//  (= AnyView / Group / Divider) is the actual root cause.
//
//  v2.1 fix (= the canonical Apple HIG shape):
//  - Drop the factory builder. Drop AnyView. Drop Group.
//    Drop Divider. (= the menu item extractor on macOS 27
//    sees the @ContentBuilder tuple directly; = each Button
//    becomes one menu row; = the menu native separator
//    is auto-injected between Buttons that have different
//    roles).
//  - Move the closure body into a ViewModifier (= the
//    inline expression on the List body triggered the
//    SwiftUI type-checker timeout; = the ViewModifier
//    keeps the closure body out of the type-checker's
//    hot path while preserving the @ViewBuilder shape
//    end-to-end).
//  - Empty-area case (= items.isEmpty) is handled INSIDE
//    the .contextMenu(forSelectionType:menu:) closure as
//    a Button (= per Apple HIG canonical; = no separate
//    EmptyAreaContextMenu ViewModifier is needed; = the
//    `forSelectionType:menu:` hook fires for empty-area
//    right-clicks on macOS 27 with an empty Set<I>).
//
//  Behavior (= matches the pre-v1.69e legacy
//  NewLibraryOutlineView.contextMenuForSelection):
//   - empty selection (= empty-area right-click): "New"
//     entry (= triggers the choice sheet; = same Apple
//     HIG shape as Mail.app / Notes.app).
//   - single shelf selected: "New Book Here" + "Rename" + "Delete"
//   - single book selected:  "Rename" + "Delete"
//   - multi-select:           batch "Delete" (= destructive role)
//   - folder / referenceCategory / tag: empty (= no destructive
//     operations on these node types in v2.6).
//

import SwiftUI

/// wraps the sidebar right-click context menu in a single
/// `ViewModifier` (= the inline `.contextMenu(forSelectionType:menu:)`
/// modifier on the List body triggered the SwiftUI type-checker
/// timeout when nested with 5+ other modifiers; = extracting it
/// into a ViewModifier keeps the type-checker happy AND keeps
/// the @ViewBuilder closure shape (= the closure body is
/// inline here, not passed as a parameter; = no AnyView; = no
/// Group; = no Divider; = Apple HIG canonical).
///
/// The closure body is the canonical Apple HIG menu shape
/// (= from the official Apple Developer doc example): an
/// `if items.isEmpty / else if items.count > 1 / else if let first`
/// chain of `Button` rows. No `Divider` (= not a valid menu
/// item in macOS 27's `contextMenu(forSelectionType:menu:)`).
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
        content.contextMenu(forSelectionType: SidebarItem.self) { items in
            // Apple HIG canonical menu shape (= direct Button
            // rows; = no Divider; = no Group; = no AnyView).
            if items.isEmpty {
                // Empty-area right-click (= user clicked the
                // sidebar background; = no row selected). Apple
                // HIG canonical = single "New" entry; = triggers
                // the choice sheet (= the user picks shelf vs
                // book).
                Button(String(localized: "sidebar_context_menu_new")) {
                    onNewShelf()
                }
            } else if items.count > 1 {
                // Multi-select = batch destructive only.
                Button(
                    String(localized: "sidebar_context_menu_delete_batch"),
                    role: .destructive
                ) {
                    for item in items {
                        switch item {
                        case .shelf(let id):
                            if let shelf = resolveShelf(id) {
                                onDeleteShelf(shelf.id, shelf.name)
                            }
                        case .book(let id):
                            if let book = resolveBook(id) {
                                onDeleteBook(book.id, book.name)
                            }
                        case .folder, .referenceCategory, .tag:
                            break
                        }
                    }
                }
            } else if let first = items.first {
                // Single selection = per-item menu.
                switch first {
                case .shelf(let id):
                    if let shelf = resolveShelf(id) {
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
                case .book(let id):
                    if let book = resolveBook(id) {
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
                case .folder, .referenceCategory, .tag:
                    // No destructive operations on these node types
                    // in v2.6 (= Apple HIG canonical = empty menu).
                    EmptyView()
                }
            }
        }
    }
}
