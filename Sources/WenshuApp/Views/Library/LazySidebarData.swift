// LazySidebarData.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the sidebar's DATA HELPERS (= the read-only views
// over in-memory state that LazySidebarView needs to render the
// tree). No SwiftUI imports (= pure data + business logic; = no view
// dependencies).
//
// What lives here:
//   - standardFolderNames: the 5 standard sub-folders a book exposes
//     in the sidebar (= world / characters / outlines / chapters /
//     drafts). Already exposed as LazySidebarStandardFolders in
//     LazySidebarFileOps.swift; re-exported here for view-layer use.
//   - shelfBooks(_:in:): filter helper (= books that belong to a
//     given shelf).
//   - usedEntityCategories(in:): filter helper (= EntityCategory
//     values that have at least one reference in the given set).
//   - isShelfSelected / isBookSelected / isReferenceCategorySelected:
//     small predicates that map SidebarItem to a Bool for the
//     selection-tint background.
//
// What does NOT live here:
//   - business logic (= LazySidebarFileOps).
//   - state persistence (= LazySidebarState).
//   - view body composition (= LazySidebarView).

import Foundation

enum LazySidebarData {

    /// Filter the in-memory books collection to those belonging to
    /// a given shelf (= the sidebar's per-shelf children list).
    static func shelfBooks(
        shelfId: UUID,
        in books: [Book]
    ) -> [Book] {
        books.filter { $0.shelfId == shelfId }
    }

    /// Subset of EntityCategory that has at least one reference in
    /// the given `references` set (= the sidebar's reference library
    /// = the categories the user has actually populated).
    static func usedEntityCategories(
        in references: [Reference]
    ) -> [EntityCategory] {
        let entityRefs = references.filter { $0.layer == .layerEntities }
        let used = Set(entityRefs.compactMap { $0.category })
        return EntityCategory.allCases.filter { used.contains($0) }
    }

    /// True if the current SidebarItem is the given shelf id.
    static func isShelfSelected(
        _ shelfId: UUID,
        in selection: SidebarItem?
    ) -> Bool {
        if case .shelf(let id) = selection { return id == shelfId }
        return false
    }

    /// True if the current SidebarItem is the given book id.
    static func isBookSelected(
        _ bookId: UUID,
        in selection: SidebarItem?
    ) -> Bool {
        if case .book(let id) = selection { return id == bookId }
        return false
    }

    /// True if the current SidebarItem is a .referenceCategory with
    /// the given raw value.
    static func isReferenceCategorySelected(
        _ raw: String,
        in selection: SidebarItem?
    ) -> Bool {
        if case .referenceCategory(let r) = selection { return r == raw }
        return false
    }

    /// Selected reference-category raw value (= nil if the selection
    /// is not a referenceCategory).
    static func selectedReferenceCategoryRaw(
        _ selection: SidebarItem?
    ) -> String? {
        if case .referenceCategory(let r) = selection { return r }
        return nil
    }
}