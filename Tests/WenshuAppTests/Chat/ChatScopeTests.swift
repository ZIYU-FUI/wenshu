//
//  Tests/Chat/ChatScopeTests.swift · Wenshu · the chat zone's session tab bar
//
//  Verifies the scope model that the bar, the directory tree and the
//  asset pane all share. The contract under test is:
//    1. the page list = the repository page, one page per ordinary book,
//       and the library page, in that order;
//    2. the help book contributes NO page;
//    3. a book that was just created gets a page at once, and a book
//       that was just deleted leaves no page behind (= the pages come
//       from the collection, = not from the session history);
//    4. the tree's rows map onto scopes, and the scopes map back onto
//       the tree's rows (= the two directions agree);
//    5. the two fixed scopes own distinct session keys, and the
//       repository conversation keeps the historical `default` key
//       (= the rows written before this feature existed stay reachable).
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuData

/// A book with the given id and title (= the shape the page list reads).
private func makeBook(_ id: UUID, _ title: String) -> Book {
    Book(
        id: id,
        title: title,
        author: "wenshu",
        shelfId: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
        createdAt: Date(),
        updatedAt: Date()
    )
}

@Suite("Chat scope")
struct ChatScopeTests {
    // MARK: - The page list

    @Test("The page list is the repository page, one page per ordinary book, and the library page")
    func pageListOrder() throws {
        let bookA = try makeBook(#require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000")), "Book A")
        let bookB = try makeBook(#require(UUID(uuidString: "bbbbbbbb-0000-0000-0000-000000000000")), "Book B")

        let pages = ChatScope.pageList(
            books: [bookA, bookB],
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )

        #expect(pages.count == 4)
        #expect(pages[0].scope == .repository)
        #expect(pages[0].title == "Wenshu")
        #expect(pages[1].scope == .book(BookID(rawValue: bookA.id.uuidString)))
        #expect(pages[1].title == "Book A")
        #expect(pages[2].scope == .book(BookID(rawValue: bookB.id.uuidString)))
        #expect(pages[2].title == "Book B")
        #expect(pages[3].scope == .library)
        #expect(pages[3].title == "Reference Library")
    }

    @Test("The help book contributes no page")
    func helpBookHasNoPage() throws {
        let help = makeBook(ChatScope.helpBookID, "Help")
        let ordinary = try makeBook(#require(UUID(uuidString: "cccccccc-0000-0000-0000-000000000000")), "Ordinary")

        let pages = ChatScope.pageList(
            books: [help, ordinary],
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )

        #expect(pages.count == 3)
        #expect(pages.contains { $0.scope == .book(BookID(rawValue: ChatScope.helpBookID.uuidString)) } == false)
        #expect(pages.contains { $0.title == "Ordinary" })
    }

    @Test("A book with no page yet still gets one, and a deleted book leaves none behind")
    func pagesFollowTheCollection() throws {
        let bookA = try makeBook(#require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000")), "Book A")

        // The book was just created: it has no session rows at all (= the
        // page list reads the collection, = not the session history), and
        // it still has its page.
        let afterCreate = ChatScope.pageList(
            books: [bookA],
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )
        #expect(afterCreate.count == 3)
        #expect(afterCreate[1].title == "Book A")

        // The book was just deleted: no page for it is left behind.
        let afterDelete = ChatScope.pageList(
            books: [],
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )
        #expect(afterDelete.count == 2)
        #expect(afterDelete.map(\.title) == ["Wenshu", "Reference Library"])
    }

    @Test("The library has no books and still has its page")
    func libraryPageSurvivesAnEmptyLibrary() {
        let pages = ChatScope.pageList(
            books: [],
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )

        #expect(pages.map(\.scope) == [.repository, .library])
    }

    // MARK: - The tree ↔ scope mapping

    @Test("A book row maps to that book's scope")
    func bookRowMapsToItsScope() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        let scope = ChatScope.scope(for: .book(bookID))

        #expect(scope == .book(BookID(rawValue: bookID.uuidString)))
    }

    @Test("A folder row maps to its book's scope")
    func folderRowMapsToItsBookScope() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        let scope = ChatScope.scope(for: .folder(bookId: bookID, folderName: "Chapters"))

        #expect(scope == .book(BookID(rawValue: bookID.uuidString)))
    }

    @Test("The reference-library root row maps to the library scope")
    func libraryRootRowMapsToTheLibraryScope() {
        #expect(ChatScope.scope(for: .referenceLibraryRoot) == .library)
    }

    @Test("Every other tree row maps to the repository scope")
    func otherRowsMapToTheRepositoryScope() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        #expect(ChatScope.scope(for: nil) == .repository)
        #expect(ChatScope.scope(for: .shelf(bookID)) == .repository)
        #expect(ChatScope.scope(for: .referenceCategory("some-category")) == .repository)
        #expect(ChatScope.scope(for: .referenceUnclassified) == .repository)
        #expect(ChatScope.scope(for: .tag("some-tag")) == .repository)
    }

    @Test("The help book's row maps to the repository scope (= it has no page of its own)")
    func helpBookRowMapsToTheRepositoryScope() {
        #expect(ChatScope.scope(for: .book(ChatScope.helpBookID)) == .repository)
    }

    @Test("A scope maps back onto the tree's row")
    func scopeMapsBackToItsRow() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        #expect(ChatScope.book(BookID(rawValue: bookID.uuidString)).treeSelection == .book(bookID))
        #expect(ChatScope.library.treeSelection == .referenceLibraryRoot)
        // The repository scope names the HIDDEN "全部分段" row (= the
        // boss's rule: "如果选文枢，没有对应的目录树要对应跳转，能否跳转
        // 到隐藏的全部分段，这个全部分段不在 UI 上显示，但会在文枢聊天
        // teb 被选中时命中").
        #expect(ChatScope.repository.treeSelection == .allLibrary)
    }

    @Test("The hidden 全部分段 row maps to the repository scope")
    func hiddenAllLibraryRowMapsToTheRepositoryScope() {
        #expect(ChatScope.scope(for: .allLibrary) == .repository)
    }

    @Test("Each scope names the sidebar part that holds its row")
    func eachScopeNamesItsPart() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        // The library row lives in the 资料库 part (= the boss's rule:
        // "比如聊天区选资料库，目录树的 teb 没有自动切换到资料库").
        #expect(ChatScope.library.sidebarPart == .library)
        // A book's row lives in the 书房 part.
        #expect(ChatScope.book(BookID(rawValue: bookID.uuidString)).sidebarPart == .shelves)
        // The hidden 全部分段 row lives in the 书房 part (= the whole
        // library's row).
        #expect(ChatScope.repository.sidebarPart == .shelves)
    }

    @Test("The hidden 全部分段 row survives the persistence round trip")
    func hiddenAllLibraryRowSurvivesPersistence() throws {
        let data = try JSONEncoder().encode(SidebarItem.allLibrary)
        let decoded = try JSONDecoder().decode(SidebarItem.self, from: data)
        #expect(decoded == .allLibrary)
    }

    @Test("A book row and its scope name each other (= the two directions agree)")
    func bookRowAndScopeAreInverses() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        let scope = ChatScope.scope(for: .book(bookID))

        #expect(scope.treeSelection == .book(bookID))
    }

    @Test("Every scope survives the round trip through the tree (= the identity)")
    func everyScopeSurvivesTheTreeRoundTrip() throws {
        // The round trip is the IDENTITY for all three scopes, and that
        // is what keeps the bar and the tree from ping-ponging: the bar
        // writes the tree, the tree maps back to the SAME scope, and the
        // view model then does nothing because the scope is unchanged.
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        for scope in [ChatScope.repository, ChatScope.library, ChatScope.book(BookID(rawValue: bookID.uuidString))] {
            let back = ChatScope.scope(for: scope.treeSelection)
            #expect(back == scope, "the scope \(scope) did not survive the round trip")
        }
    }

    @Test("The library row and its scope name each other")
    func libraryRowAndScopeAreInverses() {
        let scope = ChatScope.scope(for: .referenceLibraryRoot)

        #expect(scope.treeSelection == .referenceLibraryRoot)
    }

    // MARK: - The session keys

    @Test("The two fixed scopes own distinct session keys")
    func fixedScopesOwnDistinctSessionKeys() {
        #expect(ChatScope.repository.sessionID != ChatScope.library.sessionID)
    }

    @Test("The repository conversation keeps the historical session key")
    func repositoryScopeKeepsTheHistoricalKey() {
        // The rows written before this feature existed live under the
        // `default` key, = so the repository conversation must keep it
        // (= or its history would become unreachable).
        #expect(ChatScope.repository.sessionID == SessionID(rawValue: "default"))
    }

    @Test("A book scope keeps the per-book session key")
    func bookScopeKeepsThePerBookKey() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        let scope = ChatScope.book(BookID(rawValue: bookID.uuidString))

        #expect(scope.sessionID == SessionID(rawValue: "book:\(bookID.uuidString):default"))
    }

    @Test("Only a book scope carries a book id")
    func onlyABookScopeCarriesABookID() throws {
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000"))

        #expect(ChatScope.repository.bookID == nil)
        #expect(ChatScope.library.bookID == nil)
        #expect(ChatScope.book(BookID(rawValue: bookID.uuidString)).bookID == BookID(rawValue: bookID.uuidString))
    }
}
