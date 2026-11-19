// SidebarNode.swift · Wenshu
//
// Tree data model for the macOS 27 Apple HIG sidebar
// (= List(data, children: \.children) + .listStyle(.sidebar)).
//
// The wenshu domain models are flat (= no `var children: [Self]?`),
// so Apple's List(_, children: \.children) initializer (= which
// requires each row's children to be a `[Self]?` on the row's
// own type) cannot be wired up directly.
//
// Solution: project the flat shelves + books into a SidebarNode tree
// at view-layer (= inside the sidebar view's state object). Domain
// models stay flat (= no surprise for downstream callers); = the
// sidebar gets the Apple HIG canonical surface.
//
// b differs from the reverted v1.68a (= same idea, =
// the user accepted the architecture but rejected the rest of the
// a patch because it leaked changes into LibraryStores /
// BookStore.init / 12 test fixtures — none of those are touched
// here).

import Foundation

/// One row in the macOS 27 sidebar (= shelf root, book, folder leaf,
/// tag leaf, section divider, or the synthetic Reference-Library root).
/// The children property is what Apple's `List(_, children:)` initializer
/// needs to render disclosure indicators automatically (= non-nil = parent,
/// nil = leaf).
///
/// ', 
/// . ': the user-facing `title` MUST carry
/// the Chinese display label (= the user reads the sidebar in
/// ), NOT the routing key. The routing key (= the string that
/// survives the round-trip from sidebar click → SidebarItem →
/// PreviewScope) is stored in the dedicated
/// `routingKey` field (= only set for the tag rows).
/// `AppleSidebarView.forwardSelection` reads
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

    init(
        id: UUID,
        kind: Kind,
        title: String,
        subtitle: String?,
        systemImage: String,
        children: [SidebarNode]?,
        routingKey: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.children = children
        self.routingKey = routingKey
    }

    /// : routing key for sidebar
    /// selection = the string that survives the round-trip
    /// from sidebar click → SidebarItem → PreviewScope
    /// case-insensitive lookup. Set on the `.tag`
    /// rows to the tag string. Nil for every other Kind
    /// (= the existing shelf / book / library root rows
    /// route via the row id or the title respectively; =
    /// no separate routing key needed).
    var routingKey: String?

    /// The row's stable key for the tree's expansion state.
    ///
    /// The expansion state is remembered across a relaunch, = so the
    /// key names the row by its business identity (= the shelf's id, =
    /// the book's id, = the category's routing key), = NOT by the row's
    /// `id`: = the folder rows' ids are hashed per process (= they
    /// change on every launch), = so an id-keyed expansion state would
    /// lose the folder rows on every relaunch.
    ///
    /// Nil for a leaf (= a row without children is never open).
    var expansionKey: SidebarItem? {
        guard let children, !children.isEmpty else { return nil }
        switch kind {
        case .shelf:
            return .shelf(id)
        case .book:
            // A book row and a folder row share the `.book` kind, = but
            // only a book row has children (= the folder rows are
            // leaves), = so the kind tells the two apart here.
            return .book(id)
        case .reference:
            // The reference library's root row (= the synthetic root
            // the tag rows hang under).
            return .referenceLibraryRoot
        case .tag, .divider:
            return nil
        }
    }

    /// The row's identity (= what the tree matches a row by).
    ///
    /// ⇒ ⇒ ⇒ A ROW IS ITS OWN DATA, = NOT ITS SUBTREE: = the tree's
    /// rows are matched by identity, = so a row whose children changed
    /// (= the tree was rebuilt) is still the same row, = and the tree
    /// does not destroy it and draw it again under the user.
    ///
    /// ⇒ ⇒ ⇒ The synthesized conformance hashed the children too, =
    /// so every row under a parent changed identity when that parent's
    /// subtree changed (= the selection's highlight was lost, = and the
    /// row was redrawn).
    ///
    /// ⇒ ⇒ ⇒ THE ROW'S OWN DATA IS PART OF ITS IDENTITY, = so a row
    /// whose title or count changed is a new row (= the tree draws the
    /// new text, = and a row whose text did not change is not).
    static func == (lhs: SidebarNode, rhs: SidebarNode) -> Bool {
        lhs.id == rhs.id
            && lhs.kind == rhs.kind
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.systemImage == rhs.systemImage
            && lhs.routingKey == rhs.routingKey
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(kind)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(systemImage)
        hasher.combine(routingKey)
    }

    /// The row's DRAWING identity (= what the view matches a drawn row by).
    ///
    /// ⇒ ⇒ ⇒ EQUALITY IS THE ROW'S OWN DATA, = BUT THE DRAWING IS THE
    /// ROW'S SUBTREE: = a row whose descendant changed must be drawn
    /// again, = so the identity the view matches a row by carries the
    /// subtree's content.
    ///
    /// ⇒ ⇒ ⇒ THE EQUALITY ABOVE CANNOT CARRY IT: = a row's own data
    /// did not change when a book appeared under the shelf, = so the
    /// row compared EQUAL, = so the tree kept the row it had drawn, =
    /// and the book under it never appeared. = ⇒ ⇒ ⇒ The equality says
    /// what a row IS; = the drawing identity says what the tree must
    /// DRAW AGAIN.
    ///
    /// ⇒ ⇒ ⇒ The digest names the row's OWN DATA and every
    /// descendant's own data, = so a renamed, added or removed
    /// descendant changes its ancestor's identity (= the ancestor's row
    /// is drawn again, = and its subtree is drawn with it).
    ///
    /// ⇒ ⇒ ⇒ A rebuild that yields the same shape and the same content
    /// yields the same identity, = so the row the tree already drew is
    /// the row the tree draws again (= the tree does not destroy the
    /// row under the user).
    var drawIdentity: String {
        var digest = SidebarSubtreeDigest()
        digest.combine(id.uuidString)
        digest.combine(kind.drawToken)
        digest.combine(title)
        digest.combine(subtitle ?? "")
        digest.combine(systemImage)
        digest.combine(routingKey ?? "")
        for child in children ?? [] {
            digest.combine(child.drawIdentity)
        }
        return digest.hex
    }

    /// The tree's shape (= the digest of every top-level row's subtree).
    ///
    /// ⇒ ⇒ ⇒ THE TREE'S SHAPE IS ITS OWN IDENTITY: = the rows are
    /// compared by their own data, = so two trees whose rows differ
    /// only BELOW the top compare equal, = and the view that holds
    /// them would never read them again (= the rows under the user
    /// would keep the text they had). = ⇒ ⇒ ⇒ The shape is what tells
    /// the view that the tree it holds is a NEW tree.
    static func treeIdentity(of nodes: [SidebarNode]) -> String {
        var digest = SidebarSubtreeDigest()
        for node in nodes {
            digest.combine(node.drawIdentity)
        }
        return digest.hex
    }

    enum Kind: Hashable, Sendable {
        case shelf
        case book
        case reference
        /// A tag row (= a cross-cutting
        /// facet; = one SidebarNode per unique tag string; =
        /// the reference library's whole browse surface).
        /// Children = nil (= leaf; = clicking a tag row routes
        /// `workspaceUI.sidebarSelection = .tag(<tagString>)` and
        /// PreviewPane filters its card grid by
        /// `tags.contains(<tag>)`).
        case tag
        // bb (see OOB.md #2026-09-23) OOB '
        // ': non-interactive row that renders a horizontal
        // Divider (= the Apple HIG section separator idiom; =
        // same role as the section header divider at the
        // top of the sidebar). Inserted between the shelves
        // (= user shelves) and the reference library (= the
        // synthetic `reference` root node) by SidebarService.
        case divider

        /// The kind's stable name (= the digest's own token, = so a
        /// row's kind is part of the digest that names its subtree).
        var drawToken: String {
            switch self {
            case .shelf: return "shelf"
            case .book: return "book"
            case .reference: return "reference"
            case .tag: return "tag"
            case .divider: return "divider"
            }
        }
    }
}

/// The tree the sidebar publishes (= the rows, = and the tree's shape).
///
/// ⇒ ⇒ ⇒ THE TREE'S SHAPE IS THE TREE'S IDENTITY: = the rows are
/// compared by their OWN data, = so a tree whose rows differ only
/// BELOW the top compares EQUAL, = and the observation that carries
/// the tree never fires (= the rows under the user keep the text they
/// had). = ⇒ ⇒ ⇒ The shape is the digest of every row's subtree, = so
/// a tree that changed IS a new tree (= the sidebar reads it again), =
/// and a tree that did not change is the same tree (= the sidebar does
/// not destroy the rows under the user).
///
/// ⇒ ⇒ ⇒ THE ROWS KEEP THEIR OWN IDENTITY: = the tree's shape says
/// what the tree IS; = the rows still say what each row IS (= its own
/// data, = = the card's premise).
struct SidebarTree: Equatable {
    /// The tree's rows.
    let nodes: [SidebarNode]

    /// The tree's shape (= the digest of every row's subtree).
    let shape: String

    init(nodes: [SidebarNode]) {
        self.nodes = nodes
        shape = SidebarNode.treeIdentity(of: nodes)
    }

    static func == (lhs: SidebarTree, rhs: SidebarTree) -> Bool {
        lhs.shape == rhs.shape
    }
}

/// The digest of a row's subtree (= the row's own id + every
/// descendant's).
///
/// ⇒ ⇒ ⇒ A DIGEST, = NOT A LIST: = the tree compares digests, = so a
/// deep subtree does not make a row's identity long.
///
/// ⇒ ⇒ ⇒ The digest is FNV-1a, = and it is NOT seeded per process
/// (= Swift's own Hasher is), = so the same tree yields the same
/// identity in every launch (= the identity means the same thing
/// tomorrow as it means today).
private struct SidebarSubtreeDigest {
    /// FNV-1a's 64-bit offset basis.
    private var accumulator: UInt64 = 0xCBF2_9CE4_8422_2325

    /// FNV-1a's 64-bit prime.
    private static let prime: UInt64 = 0x0000_0100_0000_01B3

    /// Fold one field into the digest.
    ///
    /// ⇒ ⇒ ⇒ The field's end is folded in too, = so two fields can
    /// never be read as one (= "ab" + "c" is not "a" + "bc").
    mutating func combine(_ field: String) {
        for byte in field.utf8 {
            accumulator ^= UInt64(byte)
            accumulator = accumulator &* Self.prime
        }
        accumulator ^= 0x1F
        accumulator = accumulator &* Self.prime
    }

    /// The digest, as the row's identity.
    var hex: String {
        String(format: "%016llx", accumulator)
    }
}
