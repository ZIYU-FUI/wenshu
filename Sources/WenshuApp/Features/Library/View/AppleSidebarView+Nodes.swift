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
                if node.kind == .referenceCategory, node.routingKey == key {
                    return node
                }
                if node.kind == .referenceCategory, node.title == key {
                    return node
                }
            case .referenceUnclassified:
                if node.kind == .referenceCategory,
                   node.routingKey == SidebarService.unclassifiedRoutingKey
                {
                    return node
                }
            case let .tag(tag):
                if node.kind == .tag, node.title == tag {
                    return node
                }
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
        switch title {
        case "世界观": return "world"
        case "角色": return "characters"
        case "小说正文": return "chapters"
        case "小说草稿": return "drafts"
        default: return title
        }
    }
}
