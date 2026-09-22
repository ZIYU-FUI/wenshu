// SidebarNode.swift · Wenshu · v1.68b
//
// Tree data model for the macOS 27 Apple HIG sidebar
// (= List(data, children: \.children) + .listStyle(.sidebar)).
//
// Boss 2026-09-22 OOB '数据结构不要有变化' (= don't mutate the
// existing Bookshelf / Book / Reference / Document domain models):
// the wenshu domain models are flat (= no `var children: [Self]?`),
// so Apple's List(_, children: \.children) initializer (= which
// requires each row's children to be a `[Self]?` on the row's
// own type) cannot be wired up directly.
//
// Solution: project the flat shelves + books into a SidebarNode tree
// at view-layer (= inside the sidebar view's state object). Domain
// models stay flat (= no surprise for downstream callers); = the
// sidebar gets the Apple HIG canonical surface.
//
// v1.68b differs from the reverted v1.68a (= same idea, =
// the boss accepted the architecture but rejected the rest of the
// v1.68a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import Foundation

/// One row in the macOS 27 sidebar (= shelf root, book,
/// reference category folder, reference leaf, or the synthetic
/// Reference-Library root). The children property is what Apple's
/// `List(_, children:)` initializer needs to render disclosure
/// indicators automatically (= non-nil = parent, nil = leaf).
///
/// v1.69 boss 2026-09-22 OOB '资料库自动分类目录的展示': adds
/// the `.referenceCategory` Kind case (= the 22 CLC top-level
/// categories that auto-classify references). When
/// SidebarService projects the Reference-Library subtree, it
/// emits one `.referenceCategory` parent per category that has
/// >= 1 reference (the v0.29 boss 'category folders grow with
/// the content, instead of being laid out all at once' rule).
/// The category parent's children are the reference leaves.
struct SidebarNode: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: Kind
    var title: String
    var subtitle: String?
    var systemImage: String
    var children: [SidebarNode]?

    enum Kind: Hashable, Sendable {
        case shelf
        case book
        case reference
        // v1.69 boss 2026-09-22 OOB: reference-library
        // category parent (= one of 22 CLC top-level categories
        // = EntityCategory). Children = the references in that
        // category.
        case referenceCategory
    }
}