//
//  AppleSidebarView+Nodes.swift
//
//  The sidebar's tree-row lookup: the row a shared selection names,
//  the row's parent book, and a folder row's title mapped back to its
//  filesystem folder name.
//
//  Why: the lookup is four static functions over the tree's nodes, and
//  it reads no instance state, so it is its own cluster and the view's
//  own file was over the file-size cap.
//
import Foundation

extension AppleSidebarView {
    /// / Find the tree row a shared selection names.
    /// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / a row in the tree (= the sidebar draws the same row as selected).
    static func node(for selection: SidebarItem?, in nodes: [SidebarNode]) -> SidebarNode? {
        guard let selection else { return nil }
        return findNode(for: selection, in: nodes)
    }

    /// The rows that have to be open for the selected row to show.
    ///
    /// The path to a row runs from the tree's root down to the row
    /// itself; = the rows above it are the ones whose collapsed
    /// children hide it. = ⇒ ⇒ ⇒ So the reveal opens EVERY row on the
    /// path that can be open: = the rows above it, = and the named row
    /// itself when it has children (= a container: = a shelf, = a book, =
    /// the library root). = ⇒ ⇒ ⇒ A leaf row has no expansion key, = so
    /// naming a leaf opens its rows above it and nothing else.
    ///
    /// ⇒ ⇒ ⇒ THE NAMED CONTAINER IS PART OF THE PATH, = not above it:
    /// = a selection that names the library root opens the root, = so
    /// the root's tag rows show. = ⇒ ⇒ ⇒ The row the user closed comes
    /// back when a selection needs its path again (= the path IS the
    /// requirement).
    ///
    /// The keys come from the rows themselves (= not from the
    /// selection), = so the same row always carries the same key
    /// (= the key survives a tree rebuild and a relaunch).
    static func revealExpansionKeys(
        for selection: SidebarItem?,
        in nodes: [SidebarNode]
    ) -> Set<SidebarItem> {
        guard let selection, let path = findPath(for: selection, in: nodes) else { return [] }
        return Set(path.compactMap(\.expansionKey))
    }

    /// The path from the tree's root down to the row a selection names.
    ///
    /// The path is the row plus its ancestors (= the row itself is the
    /// last element). Nil when the tree draws no such row.
    ///
    /// ⇒ ⇒ ⇒ THE ROW IS FOUND BY THE ROW SEARCH (= `findNode`, = the
    /// one function that answers every selection case), = and the path
    /// is the walk down to it. = ⇒ ⇒ ⇒ So the search itself is NOT
    /// rewritten here, = and the rule it carries (= including the
    /// hidden row's own) stays in one place.
    private static func findPath(for selection: SidebarItem, in nodes: [SidebarNode]) -> [SidebarNode]? {
        guard let row = findNode(for: selection, in: nodes) else { return nil }
        return path(to: row, in: nodes)
    }

    /// The row and the rows above it (= the tree's root first).
    ///
    /// The walk compares the rows' own ids (= every row's id is
    /// unique), = so the path is the row's own line in the tree.
    private static func path(to row: SidebarNode, in nodes: [SidebarNode]) -> [SidebarNode]? {
        for node in nodes {
            if node.id == row.id {
                return [node]
            }
            if let children = node.children, let below = path(to: row, in: children) {
                return [node] + below
            }
        }
        return nil
    }

    /// / The row search itself (= every selection case the tree can make).
    /// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / a category row and a tag row carry a string, not an identifier.
    private static func findNode(for selection: SidebarItem, in nodes: [SidebarNode]) -> SidebarNode? {
        for node in nodes {
            switch selection {
            case let .shelf(id):
                if node.kind == .shelf, node.id == id {
                    return node
                }
            case let .book(id):
                if node.kind == .book, node.id == id {
                    return node
                }
            case let .folder(bookId, folderName):
                // The folder row's title is the display name, so the
                // selection's folder name is compared against the title
                // the row's own name maps back to (= the same mapping the
                // parent-book lookup uses).
                if node.kind == .book, node.id == bookId,
                   let folder = node.children?.first(where: {
                       $0.title == folderName || Self.reverseFolderName(title: $0.title) == folderName
                   })
                {
                    return folder
                }
            case let .referenceCategory(key):
                // The library root's own selection names the root (= the
                // tree draws no category row any more, = so the root is
                // the only row this value can name). = The root's kind
                // is `.reference` (= it is the container, = not a
                // category), = so the search names it by its own
                // selection value.
                if node.kind == .reference,
                   SidebarItem.referenceCategory(key) == .referenceLibraryRoot
                {
                    return node
                }
            case .referenceUnclassified:
                // The catch-all row is gone (= the surface is one flat
                // tag list), = so a persisted catch-all selection names a
                // row the tree does not draw.
                break
            case let .tag(tag):
                if node.kind == .tag, node.title == tag {
                    return node
                }
            case .allLibrary:
                // The HIDDEN "全部分段" row has NO node: = the tree does
                // not draw it (= the boss's rule: "这个全部分段不在 UI
                // 上显示，但会在文枢聊天 teb 被选中时命中"). = ⇒ So the
                // selection names a row the tree cannot show, = and the
                // tree highlights nothing.
                return nil
            }
            if let child = findNode(for: selection, in: node.children ?? []) {
                return child
            }
        }
        return nil
    }

    /// / Walk the sidebar tree to find the parent book + folder name for a row id
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / child books).
    static func parentBookInfo(for rowId: UUID, in nodes: [SidebarNode]) -> (bookId: UUID, folderName: String)? {
        // Walk each top-level shelf. If a shelf's direct child is
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // catalog).
        for root in nodes where root.kind == .shelf {
            guard let shelfChildren = root.children else { continue }
            for book in shelfChildren where book.kind == .book {
                if book.id == rowId {
                    return nil
                }
                if let folderChildren = book.children {
                    for cell in folderChildren where cell.id == rowId {
                        // Recover the folder name from the title.
                        let folderName = Self.reverseFolderName(title: cell.title)
                        return (book.id, folderName)
                    }
                }
            }
        }
        return nil
    }

    /// / Map a folder row's display title back to its filesystem folder name (=
    /// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / either side changes).
    private static func reverseFolderName(title: String) -> String {
        // = The catalog is the SSOT for the folders' labels AND their
        // directory names, = so this map is DERIVED from it: = a folder
        // the catalog declares is reversible by construction, = and the
        // next folder cannot be forgotten here. = The hard-coded switch
        // this replaced had four of the catalog's five user-facing
        // folders (= the ideas folder was missing, = so a selection of it
        // carried its display name instead of its directory name).
        BookFolderCatalog.directoryName(forSidebarDisplayName: title) ?? title
    }
}
