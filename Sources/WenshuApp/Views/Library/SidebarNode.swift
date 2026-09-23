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
///
/// v1.69p boss 2026-09-22 OOB '资料库分类, 现在显示是的一个
/// 字母. 不是中文分类名': the user-facing `title` MUST carry
/// the Chinese display label (= the user reads the sidebar in
/// 中文), NOT the routing key. The routing key (= the
/// EntityCategory.directoryName that ShellMiddleColumn
/// previewScope's case-insensitive rawValue lookup resolves
/// to an EntityCategory) is stored in the dedicated
/// `routingKey` field (= only set for .referenceCategory
/// rows). `AppleSidebarView.forwardSelection` reads
/// `routingKey ?? node.title` so the routing contract is
/// preserved without putting the routing key in the
/// user-visible title slot.
struct SidebarNode: Identifiable, Hashable, Sendable {
    let id: UUID
    var kind: Kind
    var title: String
    var subtitle: String?
    var systemImage: String
    var children: [SidebarNode]?

    /// v1.69p boss 2026-09-22 OOB: routing key for sidebar
    /// selection = the string that survives the round-trip
    /// from sidebar click → SidebarItem → PreviewScope
    /// case-insensitive EntityCategory lookup. Set on
    /// `.referenceCategory` rows to EntityCategory
    /// .directoryName (= "a" / "b" / ... / "其它" / "未分类").
    /// Nil for every other Kind (= the existing
    /// shelf / book / reference rows route via the row id
    /// or the title respectively; = no separate routing key
    /// needed).
    var routingKey: String?

    enum Kind: Hashable, Sendable {
        case shelf
        case book
        case reference
        // v1.69 boss 2026-09-22 OOB: reference-library
        // category parent (= one of 22 CLC top-level categories
        // = EntityCategory). Children = the references in that
        // category.
        case referenceCategory
        // v1.69bb boss 2026-09-23 OOB '现在把资料库上面也加一条
        // 分割线': non-interactive row that renders a horizontal
        // Divider (= the Apple HIG section separator idiom;
        // = same role as the section header divider at the
        // top of the sidebar). Inserted between the shelves
        // (= user shelves) and the reference library (= the
        // synthetic `reference` root node) by SidebarService.
        case divider
    }
}