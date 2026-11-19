//
//  SidebarTreeExpansionTests.swift · wenshu
//
//  The sidebar tree's expansion: which rows are open, which rows a
//  selection opens, and what survives a relaunch.
//
//  Coverage:
//    1. The reveal opens the path's rows (= the named row's
//       ancestors AND the named container itself).
//    2. A reveal of a deep row opens the shelf above it AND the book
//       the conversation names.
//    3. The top row opens itself, = and so does the reference
//       library's root row (= a row with no ancestor has itself as
//       its whole path).
//    4. A row the tree does not carry, = or carries but cannot see, =
//       opens nothing.
//    5. The reveal of a row in one part does not open rows in
//       another part.
//    6. The reveal only ADDS (= the rows the user opened elsewhere
//       stay open, = and it closes nothing: = a row the user closed
//       comes back when a selection needs its path).
//    7. The open rows round-trip through the user's defaults.
//    8. A row's expansion key names the same row after the tree is
//       rebuilt (= the key is the business identity, = not the row's
//       per-process id).
//    9. The reveal request counts (= so the same selection can be
//       asked for twice) and is not persisted (= it is a request, = not
//       a state).
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
struct SidebarTreeExpansionTests {
    // MARK: - The tree

    private static func shelfTree() -> [SidebarNode] {
        let shelfID = UUID()
        let bookID = UUID()
        let folderID = UUID()
        return [
            SidebarNode(
                id: shelfID,
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: bookID,
                        kind: .book,
                        title: "Book",
                        subtitle: nil,
                        systemImage: "book",
                        children: [
                            SidebarNode(
                                id: folderID,
                                kind: .book,
                                title: "Worldview",
                                subtitle: nil,
                                systemImage: "globe",
                                children: nil
                            ),
                        ]
                    ),
                ]
            ),
        ]
    }

    /// The one book under the tree's shelf (= the row the reveal
    /// cases name).
    private static func bookID(of tree: [SidebarNode]) throws -> UUID {
        let shelf = try #require(tree.first)
        let children = try #require(shelf.children)
        let book = try #require(children.first)
        return book.id
    }

    // MARK: - The reveal

    /// The reference library's tree (= the other part's hierarchy).
    ///
    /// Its rows are the library root and the tag rows under it, = so the
    /// two parts' rows are told apart by their OWN kind (= a shelf
    /// against a tag).
    private static func libraryTree() -> [SidebarNode] {
        return [
            SidebarNode(
                id: SidebarService.referenceLibraryRootId,
                kind: .reference,
                title: "Reference Library",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: UUID(),
                        kind: .tag,
                        title: "poet",
                        subtitle: nil,
                        systemImage: "tag",
                        children: nil,
                        routingKey: "poet"
                    ),
                ]
            ),
        ]
    }

    @Test("The reveal opens the path's rows (= the named container too)")
    func theRevealOpensThePathsRows() throws {
        let tree = Self.shelfTree()
        let bookID = try Self.bookID(of: tree)

        let keys = AppleSidebarView.revealExpansionKeys(for: .book(bookID), in: tree)

        // ⇒ ⇒ ⇒ THE NAMED ROW IS PART OF THE PATH: = the book has
        // children (= its folders), = so the reveal opens the book as
        // well as the shelf above it.
        #expect(keys == [.shelf(tree[0].id), .book(bookID)])
    }

    @Test("The reveal of the top row opens the top row")
    func theRevealOfTheTopRowOpensTheTopRow() {
        let tree = Self.shelfTree()
        let shelfID = tree[0].id

        let keys = AppleSidebarView.revealExpansionKeys(for: .shelf(shelfID), in: tree)

        // ⇒ ⇒ ⇒ THE TOP ROW IS A CONTAINER (= it holds the books), =
        // so naming it opens it: = a selection with no row above it
        // must still show what it named.
        #expect(keys == [.shelf(shelfID)])
    }

    @Test("The reveal of the library root opens the root")
    func theRevealOfTheLibraryRootOpensTheRoot() {
        let library = Self.libraryTree()

        let keys = AppleSidebarView.revealExpansionKeys(
            for: .referenceLibraryRoot,
            in: library
        )

        // ⇒ ⇒ ⇒ THE LIBRARY SCOPE'S REVEAL: = the root's path is the
        // root alone, = so the rule that opened only the rows ABOVE
        // the selection opened nothing at all (= the root's tag rows
        // stayed hidden). = ⇒ ⇒ ⇒ The named container is on the path.
        #expect(keys == [.referenceLibraryRoot])
    }

    @Test("The reveal of a folder row opens the shelf and the book")
    func theRevealOfAFolderRowOpensTheShelfAndTheBook() throws {
        let tree = Self.shelfTree()
        let bookID = try Self.bookID(of: tree)

        let keys = AppleSidebarView.revealExpansionKeys(
            for: .folder(bookId: bookID, folderName: "Worldview"),
            in: tree
        )

        #expect(keys == [.shelf(tree[0].id), .book(bookID)])
    }

    @Test("The reveal of a row the tree does not draw opens nothing")
    func theRevealOfAnAbsentRowOpensNothing() {
        let tree = Self.shelfTree()

        #expect(AppleSidebarView.revealExpansionKeys(for: .book(UUID()), in: tree).isEmpty)
        #expect(AppleSidebarView.revealExpansionKeys(for: nil, in: tree).isEmpty)
    }

    @Test("The reveal of a hidden row opens nothing")
    func theRevealOfTheHiddenRowOpensNothing() {
        let tree = Self.shelfTree()

        let keys = AppleSidebarView.revealExpansionKeys(for: .allLibrary, in: tree)

        #expect(keys.isEmpty)
    }

    @Test("The reveal of a row in one part does not open rows in another part")
    func theRevealOfOnePartDoesNotOpenAnotherPartsRows() throws {
        let shelves = Self.shelfTree()
        let library = Self.libraryTree()
        let bookID = try #require(shelves[0].children?[0].id)

        // The shelves part's reveal names a shelf (= the shelf above
        // the book), = and the library part's reveal names the library
        // root (= the root above the tag). = ⇒ ⇒ ⇒ The two parts'
        // keys are told apart by their own kind, = so a row in one part
        // can never be opened by the other part's reveal.
        let shelfKeys = AppleSidebarView.revealExpansionKeys(for: .book(bookID), in: shelves)
        let libraryKeys = AppleSidebarView.revealExpansionKeys(
            for: .tag("poet"),
            in: library
        )

        #expect(shelfKeys == [.shelf(shelves[0].id), .book(bookID)])
        #expect(libraryKeys == [.referenceLibraryRoot])
        #expect(
            shelfKeys.isDisjoint(with: libraryKeys),
            "the two parts' open rows must not name each other (= the parts are separate trees)"
        )
    }

    // MARK: - The reveal's union

    @Test("The reveal only adds (= the rows the user opened elsewhere stay open)")
    func theRevealOnlyAdds() throws {
        let suite = "sidebar-tree-reveal-union-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let tree = Self.shelfTree()
        let bookID = try Self.bookID(of: tree)

        // The row the user opened by hand (= a shelf of their own, = not
        // on the selected row's path).
        let openedByHand = SidebarItem.shelf(UUID())
        state.expandedSidebarRows = [openedByHand]

        let keys = AppleSidebarView.revealExpansionKeys(for: .book(bookID), in: tree)
        state.openRows(keys)

        // ⇒ ⇒ ⇒ THE UNION: = the path's rows open, = and the row the
        // user opened stays open. = ⇒ ⇒ ⇒ A reveal is NEVER a reset.
        #expect(
            state.expandedSidebarRows == [openedByHand, .shelf(tree[0].id), .book(bookID)],
            """
            the open rows are \(state.expandedSidebarRows) (= they must hold the row the \
            user opened AND the path's row: = a reveal only adds).
            """
        )

        // ⇒ ⇒ ⇒ AND A SECOND REVEAL OF THE SAME PATH CHANGES NOTHING
        // (= the set is already a superset, = so nothing is written).
        let before = state.expandedSidebarRows
        state.openRows(keys)
        #expect(state.expandedSidebarRows == before)
    }

    @Test("The reveal opens the path's rows (= even one the user closed) and closes nothing")
    func theRevealOpensThePathsRowsAndClosesNothing() throws {
        let suite = "sidebar-tree-reveal-closed-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let tree = Self.shelfTree()
        let bookID = try Self.bookID(of: tree)

        // The user closed the shelf (= it is NOT in the set), = and the
        // selection still names the book under it.
        let closedByHand = SidebarItem.shelf(tree[0].id)
        #expect(!state.expandedSidebarRows.contains(closedByHand))

        // The reveal's keys are what the path needs (= the shelf), = so
        // the reveal OPENS it. = ⇒ ⇒ ⇒ A row the user closed comes
        // back when a selection needs the path again, = because the
        // path IS the requirement: = the row the conversation names
        // has to be visible. = ⇒ ⇒ ⇒ The rule that matters here is the
        // one the boss's own needs rest on: = a reveal is a union, = so
        // it can only add (= it never closes a row).
        let keys = AppleSidebarView.revealExpansionKeys(for: .book(bookID), in: tree)
        state.openRows(keys)
        #expect(state.expandedSidebarRows.contains(closedByHand))

        // ⇒ ⇒ ⇒ AND THE OTHER DIRECTION: = the rows that are open and
        // are NOT on the path are untouched by the reveal (= they stay
        // open).
        let unrelated = SidebarItem.shelf(UUID())
        state.expandedSidebarRows = [unrelated]
        state.openRows(keys)
        #expect(state.expandedSidebarRows.contains(unrelated))
    }

    // MARK: - The keys

    @Test("A row's expansion key survives the tree being rebuilt")
    func theExpansionKeySurvivesTheTreeBeingRebuilt() {
        let shelfID = UUID()
        let bookID = UUID()
        let makeBook = { id in
            SidebarNode(
                id: id,
                kind: .book,
                title: "Book",
                subtitle: nil,
                systemImage: "book",
                children: nil
            )
        }
        let first = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            subtitle: nil,
            systemImage: "books.vertical",
            children: [makeBook(bookID)]
        )
        let second = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            subtitle: nil,
            systemImage: "books.vertical",
            children: [makeBook(bookID)]
        )

        #expect(first.expansionKey == second.expansionKey)
        #expect(first.expansionKey == .shelf(shelfID))
    }

    @Test("A leaf row has no expansion key")
    func aLeafRowHasNoExpansionKey() {
        let leaf = SidebarNode(
            id: UUID(),
            kind: .tag,
            title: "poet",
            subtitle: nil,
            systemImage: "tag",
            children: nil
        )

        #expect(leaf.expansionKey == nil)
    }

    @Test("The reference library root's key is the library root")
    func theReferenceLibraryRootsKeyIsTheLibraryRoot() {
        let root = SidebarNode(
            id: SidebarService.referenceLibraryRootId,
            kind: .reference,
            title: "Reference Library",
            subtitle: nil,
            systemImage: "books.vertical",
            children: [
                SidebarNode(
                    id: UUID(),
                    kind: .tag,
                    title: "poet",
                    subtitle: nil,
                    systemImage: "tag",
                    children: nil
                ),
            ]
        )

        #expect(root.expansionKey == .referenceLibraryRoot)
    }

    // MARK: - The persistence

    @Test("The open rows round-trip through the user's defaults")
    func theOpenRowsRoundTripThroughTheDefaults() throws {
        let suite = "sidebar-tree-expansion-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let shelfID = UUID()
        let bookID = UUID()

        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        state.expandedSidebarRows = [.shelf(shelfID), .book(bookID)]

        let restored = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let expected: Set<SidebarItem> = [.shelf(shelfID), .book(bookID)]
        #expect(restored.expandedSidebarRows == expected)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("The open rows start empty when nothing was persisted")
    func theOpenRowsStartEmptyWhenNothingWasPersisted() throws {
        let suite = "sidebar-tree-expansion-empty-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))

        #expect(state.expandedSidebarRows.isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - The reveal request

    @Test("A reveal request counts, = so the same selection can be asked for twice")
    func aRevealRequestCounts() throws {
        let suite = "sidebar-tree-reveal-request-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        #expect(state.revealRequestCount == 0)

        // The SAME selection value, asked for twice: = the request
        // still counts twice (= a tree that watches the value would
        // hear nothing on the second ask).
        let bookID = UUID()
        state.sidebarSelection = .book(bookID)
        state.requestReveal()
        state.requestReveal()

        #expect(state.revealRequestCount == 2)
        #expect(state.sidebarSelection == .book(bookID))
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("The reveal request is not persisted (= it is a request, = not a state)")
    func theRevealRequestIsNotPersisted() throws {
        let suite = "sidebar-tree-reveal-request-persistence-test"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        state.requestReveal()

        let restored = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        #expect(restored.revealRequestCount == 0)
        defaults.removePersistentDomain(forName: suite)
    }
}
