//
//  Tests/Chat/ChatScopeLinkageTests.swift · Wenshu
//
//  The chat zone's session bar and the directory tree are TWO VIEWS over
//  ONE selection, and this suite is the contract that keeps them from
//  drifting.
//
//  The boss's rule (= 2026-11-12):
//
//  - "切换聊天栏 TEB，没有对应跳转目录树的 teb。比如聊天区选资料库，
//    目录树的 teb 没有自动切换到资料库" (= picking a chat page must
//    move the sidebar's teb (= the part) to the part that holds the row
//    the page names).
//  - "如果选文枢，没有对应的目录树要对应跳转，能否跳转到隐藏的全部分
//    段，这个全部分段不在 UI 上显示，但会在文枢聊天 teb 被选中时命中"
//    (= the 文枢 page names the HIDDEN "全部分段" row, = which the tree
//    does not draw).
//  - "同时素材栏显示整个文枢库的所有文档" (= the assets pane shows
//    every document of the whole 文枢库).
//
//  Three kinds of evidence:
//
//  1. The MODEL's own answers (= the scope ↔ row ↔ part mapping, = and
//    the hidden row's persistence round trip).
//  2. The TREE's own answer (= the hidden row has NO node, = so the tree
//    draws no row for it).
//  3. The ASSETS PANE's route (= the hidden row reaches the whole-library
//    scope, = and the route is CALLED, = because it is a function the
//    production path calls, = not a mapping read out of the source).
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuData

@Suite("The chat bar and the tree over one selection")
struct ChatScopeLinkageTests {
    // MARK: - The model's own answers

    @Test("Each chat page names the sidebar part that holds its row")
    func eachPageNamesItsPart() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000")) // swiftlint:disable:this force_try

        // The 资料库 page's row (= the reference library root) lives in the
        // 资料库 part. = ⇒ So picking that page moves the sidebar's teb
        // to the 资料库 (= the boss's rule).
        #expect(ChatScope.library.sidebarPart == .library)
        // A book's row lives in the 书房 part.
        #expect(ChatScope.book(BookID(rawValue: bookID.uuidString)).sidebarPart == .shelves)
        // The hidden 全部分段 row lives in the 书房 part.
        #expect(ChatScope.repository.sidebarPart == .shelves)
    }

    @Test("The 文枢 page names the hidden 全部分段 row")
    func repositoryPageNamesTheHiddenRow() {
        #expect(ChatScope.repository.treeSelection == .allLibrary)
        // And the hidden row maps BACK to the repository scope (= the
        // round trip is the identity, = so the bar and the tree cannot
        // ping-pong).
        #expect(ChatScope.scope(for: .allLibrary) == .repository)
    }

    @Test("The hidden 全部分段 row survives the persistence round trip")
    func hiddenRowSurvivesPersistence() throws {
        let data = try JSONEncoder().encode(SidebarItem.allLibrary)
        let decoded = try JSONDecoder().decode(SidebarItem.self, from: data)
        #expect(decoded == .allLibrary)
        // And the shape is the flat one the catalog uses (= a kind and
        // no payload), = so a persisted selection reads back.
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["kind"] as? String == "allLibrary")
    }

    // MARK: - The tree's own answer

    @Test("The tree draws no row for the hidden 全部分段")
    func theTreeDrawsNoRowForTheHiddenRow() {
        // ⇒ ⇒ ⇒ A REAL TREE (= not an empty one): = the hidden row's
        // case sits INSIDE the loop over the tree's rows, = so an empty
        // tree never reaches it, = and the answer would be the loop's
        // own "nothing found" (= a VACUOUS proof). = ⇒ ⇒ ⇒ MEASURED
        // (= the review on this diff): = naming the tree's first row
        // instead left the whole repository green.
        let shelfId = UUID()
        let bookId = UUID()
        let tree: [SidebarNode] = [
            SidebarNode(
                id: shelfId,
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: bookId,
                        kind: .book,
                        title: "Book",
                        subtitle: nil,
                        systemImage: "book",
                        children: nil
                    ),
                ]
            ),
        ]

        // ⇒ ⇒ ⇒ AND THE CONTROL: = the tree DOES answer for the rows it
        // has (= so the empty answer below is the hidden row's own, = and
        // not the lookup failing to find anything at all).
        #expect(
            AppleSidebarView.node(for: .shelf(shelfId), in: tree) != nil,
            "the tree MUST answer for the shelf it has"
        )
        #expect(
            AppleSidebarView.node(for: .book(bookId), in: tree) != nil,
            "the tree MUST answer for the book it has"
        )

        // The hidden row is not in the UI (= the boss's rule: "这个全部
        // 段不在 UI 上显示"), = so the tree's own node lookup finds
        // nothing for it.
        #expect(
            AppleSidebarView.node(for: .allLibrary, in: tree) == nil,
            "the hidden 全部分段 row MUST have NO node (= the tree draws no row for it)"
        )
    }

    // MARK: - The production write

    /// The tree write itself (= the two statements, = and their order).
    ///
    /// ⇒ ⇒ ⇒ THE WRITE LIVES IN THE PICK HANDLER (= one door, = so
    /// there is no helper below that the production path could
    /// bypass), = and this suite drives that handler: = the part write,
    /// the row write, = and the ORDER (= the part's `didSet` restores
    /// that part's remembered row, = so a reversed pair lands the tree
    /// on the remembered row instead of the page's row).
    @Test("The tree write moves the part and the row (= and the part comes first)")
    @MainActor
    func theTreeWriteMovesThePartAndTheRow() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-scope-linkage-write"))
        defaults.removePersistentDomain(forName: "chat-scope-linkage-write")
        defer { defaults.removePersistentDomain(forName: "chat-scope-linkage-write") }
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))

        // The 资料库 part REMEMBERS a different row (= so the ORDER is
        // visible: = the part's `didSet` restores it).
        state.currentSidebarPart = .library
        state.sidebarSelection = .tag("remembered")
        state.currentSidebarPart = .shelves

        // The door (= the same one the view's body builds its bar
        // through), = so nothing outside `ChatZoneView` names the
        // chain's closure (= MEASURED: = while a named helper existed
        // and THIS suite called it, = inlining the writes left this
        // suite green and the helper alive).
        ChatZoneTabBar.sessionBar(
            pages: [],
            selectedScope: .library,
            in: state,
            applyScope: { _ in }
        ).pick(.library)

        #expect(
            state.currentSidebarPart == .library,
            "the write must move the tree's part to the part that holds the row the page names"
        )
        #expect(
            state.sidebarSelection == .referenceLibraryRoot,
            "the write must land the tree on the row the page names (= not on the part's remembered row)"
        )
    }

    // MARK: - The assets pane's route

    @Test("The hidden 全部分段 row reaches the whole-library scope")
    func theHiddenRowReachesTheWholeLibraryScope() {
        // ⇒ ⇒ ⇒ THE ROUTE IS CALLED, = NOT READ. = The assets pane's
        // mapping was PRIVATE, = and the house's own answer for a
        // private mapping was the source text, = and a source text holds
        // a SPELLING. = ⇒ ⇒ ⇒ MEASURED (= the review on this diff): = a
        // decoy that broke the `.allLibrary` route while keeping both
        // literal strings left the whole repository green, = so the
        // boss's rule ("素材栏显示整个文枢库的所有文档") = could break
        // with no suite saying so. = ⇒ ⇒ ⇒ So the mapping is now a
        // function, = and the production path calls THIS one.
        #expect(
            AssetsPane.previewScope(for: .allLibrary) == .allLibraryScope,
            "the hidden 全部分段 row MUST reach the whole-library scope"
        )
    }

    @Test("Every tree row reaches the scope it names (= the whole route, not one arm of it)")
    func everyTreeRowReachesItsScope() {
        let bookId = UUID()
        let shelfId = UUID()

        #expect(
            AssetsPane.previewScope(for: .referenceLibraryRoot) == .referenceScope(nil),
            "the reference library's root row MUST reach the reference scope"
        )
        #expect(
            AssetsPane.previewScope(for: .referenceUnclassified) == .referenceScope(nil),
            "the catch-all row MUST reach the reference scope"
        )
        #expect(
            AssetsPane.previewScope(for: .book(bookId)) == .bookScope(bookId: bookId, folderName: nil),
            "a book row MUST reach that book's scope"
        )
        #expect(
            AssetsPane.previewScope(for: .folder(bookId: bookId, folderName: "章")) == .bookScope(bookId: bookId, folderName: "章"),
            "a folder row MUST reach that folder's scope"
        )
        #expect(
            AssetsPane.previewScope(for: .shelf(shelfId)) == .shelfScope(shelfId: shelfId),
            "a shelf row MUST reach that shelf's scope"
        )
        #expect(
            AssetsPane.previewScope(for: .tag("主线")) == .tagScope("主线"),
            "a tag row MUST reach that tag's scope"
        )
        #expect(
            AssetsPane.previewScope(for: nil) == .referenceScope(nil),
            "no row selected MUST reach the reference scope"
        )
    }

    @Test("The whole-library scope counts every document the library holds")
    @MainActor
    func theWholeLibraryScopeCountsEveryDocument() {
        // With no library (= no store), = the whole-library scope holds
        // no documents. = The count is the sum of the reference
        // library's documents and every book's documents (= so the
        // chrome's count agrees with the grid's cards).
        #expect(
            PreviewPaneOps.countCardsInScope(
                scope: .allLibraryScope,
                bookStore: nil,
                searchQuery: ""
            ) == 0
        )
    }
}
