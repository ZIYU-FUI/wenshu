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
        preset: BookStylePreset,
        to bookID: UUID,
        store: BookStore
    ) throws -> Book? {
        guard let index = store.books.firstIndex(where: { $0.id == bookID }) else {
            return nil
        }
        var book = store.books[index]
        let sheet = preset.sheet(bodyFamily: book.effectiveStyleSheet.bodyFamily)
        guard sheet != book.effectiveStyleSheet else { return book }
        book.styleSheet = sheet
        try store.sidebarSaveBook(book)
        return book
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
        try store.sidebarSaveBook(book)
        return book
    }
}
