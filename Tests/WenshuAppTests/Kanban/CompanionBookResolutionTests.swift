//
//  CompanionBookResolutionTests.swift · Wenshu · v1.45 ticket 001
//
//  Tests for the board's own book-resolution helper.
//
//  The board reads the book the sidebar names, and it resolves that name
//  with `KanbanView.bookId(for:)`. The helper used to live on the board's
//  own window, and the window's test file was the only thing that covered
//  it; when the window was deleted the helper moved to the board and the
//  coverage did not move with it. These cases are that coverage, and they
//  assert the BEHAVIOUR (= which selections name a book) rather than the
//  source text.
//
//  A book row and a folder row both name a book (= a folder is a sub-row
//  of one book). Every other selection (= a shelf, a reference category,
//  an unclassified reference, a tag, nothing) names no book, and the board
//  then shows its own picker.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Companion book resolution")
struct CompanionBookResolutionTests {

    @Test("a book row names its book")
    func bookRowNamesItsBook() {
        let id = UUID()
        #expect(KanbanView.bookId(for: .book(id)) == id)
    }

    @Test("a folder row names its parent book")
    func folderRowNamesItsParentBook() {
        let id = UUID()
        #expect(KanbanView.bookId(for: .folder(bookId: id, folderName: "Worldview")) == id)
    }

    @Test("a shelf, a reference category, a tag, and nothing name no book")
    func otherSelectionsNameNoBook() {
        #expect(KanbanView.bookId(for: .shelf(UUID())) == nil)
        #expect(KanbanView.bookId(for: .referenceCategory("Characters")) == nil)
        #expect(KanbanView.bookId(for: .referenceUnclassified) == nil)
        #expect(KanbanView.bookId(for: .tag("Foreshadowing")) == nil)
        #expect(KanbanView.bookId(for: nil) == nil)
    }
}
