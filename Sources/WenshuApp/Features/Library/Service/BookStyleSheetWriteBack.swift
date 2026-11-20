//
//  BookStyleSheetWriteBack.swift · Wenshu
//
//  A knob of a book's style sheet, moved, and written down.
//
//  WHY A SEPARATE FILE AND NOT A LINE IN THE VIEW
//
//  The page that shows the knobs is a SwiftUI view, = and a view's
//  own action is not something a test can drive. = So the write-back
//  lives here, = and BOTH the page and the tests call it: = the test
//  measures the same operation the page performs, = so a change that
//  stops writing the sheet down turns the on-disk test red, = and not
//  only a test of a copy of the logic.
//
//  WHAT IT DOES
//
//  A knob moves to a POSITION (= the sheet's own enum's name), = the
//  sheet is written onto the book, = and the book is saved through the
//  app's own save path for an existing book (= `sidebarSaveBook`, =
//  which writes `book.json` and keeps the store's own array in step).
//  = A knob already at that position changes nothing, = and a
//  position the sheet cannot read back changes nothing.
//

import Foundation

/// Writes a knob of a book's style sheet back onto the book.
@MainActor
enum BookStyleSheetWriteBack {
    /// Write one of the two sets onto the book, = and save the book.
    ///
    /// A set is a WHOLE SHEET, = so this writes the whole sheet down
    /// (= and not knob by knob, = which would leave the book half
    /// written if one write failed).
    @discardableResult
    static func apply(
        selection: BookStyleSelection,
        to bookID: UUID,
        store: BookStore
    ) throws -> Book? {
        guard let index = store.books.firstIndex(where: { $0.id == bookID }) else {
            return nil
        }
        var book = store.books[index]
        let sheet: BookStyleSheet
        switch selection {
        case let .preset(preset):
            sheet = preset.sheet(bodyFamily: book.effectiveStyleSheet.bodyFamily)
        //  A set is chosen OVER the tuning, = and the tuning is not
        //  deleted by it: = `customStyleSheet` keeps what the reader
        //  had (= General and back to Custom returns the book to the tuning it
        //  was at, = not to the set it passed through).
        case .custom:
            //  Custom is the book's own saved tuning when it has one. = A
            //  book that has never been tuned has nothing to come back to,
            //  = and starts from the general set (= Custom is entered, = then tuned
            //  by hand) (see OOB.md #2026-11-19), = so the segment is always
            //  reachable and never a dead click.
            sheet = book.customStyleSheet
                ?? BookStylePreset.general.sheet(bodyFamily: book.effectiveStyleSheet.bodyFamily)
        }
        //  A click that moved nothing writes nothing. = Note that the SHEET
        //  moving is not the only thing a click does: = entering Custom from
        //  the general set leaves the sheet exactly as it was (= the general
        //  set's own), = and the PLACE still has to be written, = because a
        //  switcher that springs back on a click the reader can see is what
        //  he calls a bug.
        let sheetAlreadyThere = sheet == book.effectiveStyleSheet
        let placeAlreadyRecorded = book.styleSelection == selection
        if sheetAlreadyThere, placeAlreadyRecorded {
            return book
        }
        book.styleSheet = sheet
        book.styleSelectionIdentifier = selection.persistedIdentifier
        try store.sidebarSaveBook(book)
        return book
    }

    /// Choose one of the sets, = by name.
    ///
    /// The page's own call site reads clearer with the set in it than with
    /// a case of an enum the reader has to unwrap.
    @discardableResult
    static func apply(
        preset: BookStylePreset,
        to bookID: UUID,
        store: BookStore
    ) throws -> Book? {
        try apply(selection: .preset(preset), to: bookID, store: store)
    }

    /// Move one knob of the book to a position, and save the book.
    ///
    /// Returns the saved book, = or nil when the store does not carry
    /// the book.
    ///
    /// IT THROWS WHEN THE SAVE FAILS: = a write that could not reach
    /// the disk is not a write, = and a caller that cannot see the
    /// failure would report success for a book that did not change.
    @discardableResult
    static func apply(
        knob: BookStyleKnob,
        position: String,
        to bookID: UUID,
        store: BookStore
    ) throws -> Book? {
        guard let index = store.books.firstIndex(where: { $0.id == bookID }) else {
            return nil
        }
        var book = store.books[index]
        let sheet = book.effectiveStyleSheet.setting(knob, to: position)
        // A knob already at that position changes nothing, = so the
        // book is not rewritten for nothing.
        guard sheet != book.effectiveStyleSheet else { return book }
        book.styleSheet = sheet
        //  A move that leaves the book at none of the sets IS the book's
        //  own tuning, = so the tuning is saved where Custom can find it
        //  again (= and a move that lands the book exactly back on a set
        //  leaves the saved tuning alone: = the reader who nudged a knob
        //  and nudged it back has not lost the tuning they meant).
        //  The place the switcher shows is recorded from the sheet the
        //  move made, = so a knob nudged under either set springs the
        //  switcher to Custom by itself, = and a nudge that lands back on
        //  a set's values is honest about being at that set (= the boss's
        //  ruling of 2026-11-19: = this auto-switch is kept).
        let place = BookStyleSelection.select(sheet: sheet)
        book.styleSelectionIdentifier = place.persistedIdentifier
        if place == .custom {
            book.customStyleSheet = sheet
        }
        try store.sidebarSaveBook(book)
        return book
    }
}
