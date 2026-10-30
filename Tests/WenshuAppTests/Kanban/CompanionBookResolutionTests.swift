//
//  CompanionBookResolutionTests.swift · Wenshu · v1.45 ticket 001
//
//  Tests for the sidebar row's own book-resolution helper.
//
//  The board follows the session, and the session names its book, so a
//  sidebar click reaches a session through the row's book. The helper
//  lives on the row itself (= `SidebarItem.bookId`), and these cases
//  assert the BEHAVIOUR (= which rows name a book) rather than the
//  source text.
//
//  A book row and a folder row both name a book (= a folder is a sub-row
//  of one book). Every other selection (= a shelf, a reference category,
//  an unclassified reference, a tag, nothing) names no book.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Companion book resolution")
struct CompanionBookResolutionTests {

    @Test("a book row names its book")
    func bookRowNamesItsBook() {
        let id = UUID()
        #expect(SidebarItem.book(id).bookId == id)
    }

    @Test("a folder row names its parent book")
    func folderRowNamesItsParentBook() {
        let id = UUID()
        #expect(SidebarItem.folder(bookId: id, folderName: "Worldview").bookId == id)
    }

    @Test("a shelf, a reference category, a tag, and nothing name no book")
    func otherSelectionsNameNoBook() {
        #expect(SidebarItem.shelf(UUID()).bookId == nil)
        #expect(SidebarItem.referenceCategory("Characters").bookId == nil)
        #expect(SidebarItem.referenceUnclassified.bookId == nil)
        #expect(SidebarItem.tag("Foreshadowing").bookId == nil)
        let noSelection: SidebarItem? = nil
        #expect(noSelection?.bookId == nil)
    }
}
