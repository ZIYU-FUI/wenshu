//  BookStyleSheetTests.swift
//  wenshu
//
//  A book's style sheet is BOOK-level: = one set runs through the whole
//  book, = and every adjustment acts on the whole book.
//
//  These tests lock three things: = the DEFAULT set is the measured
//  print baseline (= not a guess), = every knob holds a FIXED POSITION
//  (= a sheet cannot express a size the printer would not set), = and the
//  sheet round-trips through book.json = while a book that predates it
//  still decodes.

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookStyleSheet (the book's own style set)")
struct BookStyleSheetTests {
    // MARK: - The default IS the print baseline

    @Test("the default sheet is the measured print baseline")
    func theDefaultSheetIsThePrintBaseline() {
        let sheet = BookStyleSheet.default
        // = the print minimum for a novel's body is 五号 / 10.5pt, = and
        // 13pt is the HIG body size, = so the baseline is the middle one.
        #expect(sheet.bodySize == .medium)
        #expect(sheet.bodySize.points == 13)
        // = print 1.50-1.60 (= 五号 with 5.25-6.25pt of leading).
        #expect(sheet.lineSpacing == .standard)
        #expect(sheet.lineSpacing.multiple == 1.55)
        // = print 首行缩进 2 字, = and print 段间距 0.
        #expect(sheet.firstLineIndent == .twoCharacters)
        #expect(sheet.firstLineIndent.characters == 2)
        #expect(sheet.segmentSpacing == .none)
        #expect(sheet.segmentSpacing.characters == 0)
        // = the body is the print body face (= 宋体).
        #expect(sheet.bodyFamily == .songti)
        // = print 三号 / 四号 / 小四 = (16 / 14 / 12pt).
        #expect(sheet.headingSizes == [16, 14, 12])
        // = a print note and a print caption are always SMALLER than the
        // body, = and a print quote is a different face AND size.
        #expect(sheet.noteSize < sheet.bodySize.points)
        #expect(sheet.captionSize < sheet.bodySize.points)
        #expect(sheet.quoteSize != sheet.bodySize.points)
    }

    @Test("the heading ladder descends for every level")
    func theHeadingLadderDescends() {
        let sheet = BookStyleSheet.default
        #expect(sheet.headingSize(forLevel: 1) == 16)
        #expect(sheet.headingSize(forLevel: 2) == 14)
        #expect(sheet.headingSize(forLevel: 3) == 12)
        #expect(sheet.headingSize(forLevel: 1) > sheet.headingSize(forLevel: 2))
        #expect(sheet.headingSize(forLevel: 2) > sheet.headingSize(forLevel: 3))
    }

    @Test("a level past the ladder falls back to the body size")
    func aLevelPastTheLadderFallsBackToTheBodySize() {
        let sheet = BookStyleSheet.default
        // = a document with more levels than the ladder still has a
        // defined size, = and it is the body's.
        #expect(sheet.headingSize(forLevel: 4) == sheet.bodySize.points)
        #expect(sheet.headingSize(forLevel: 0) == sheet.bodySize.points)
    }

    // MARK: - Positions, = not free numbers

    @Test("every knob offers positions, = and none of them is a free number")
    func everyKnobOffersPositions() {
        // = the boss's rule: = a writer chooses a style, = not that a
        // writer sets a size. = So the sizes a sheet can hold are the
        // positions, = and they are enumerable.
        #expect(BookBodySize.allCases.map(\.points) == [12, 13, 14])
        #expect(BookLineSpacing.allCases.map(\.multiple) == [1.45, 1.55, 1.70])
        #expect(BookFirstLineIndent.allCases.map(\.characters) == [0, 2])
        #expect(BookSegmentSpacing.allCases.map(\.characters) == [0, 0.5])
        #expect(BookBodyFamily.allCases.count == 4)
    }

    @Test("each body family names a face, = and the heading face is a different one")
    func eachBodyFamilyNamesAFace() {
        for family in BookBodyFamily.allCases {
            #expect(!family.postScriptName.isEmpty)
            #expect(!family.headingPostScriptName.isEmpty)
        }
        // = a printed book's headings are a different face from its body.
        #expect(BookBodyFamily.songti.postScriptName != BookBodyFamily.songti.headingPostScriptName)
    }

    // MARK: - Persistence

    @Test("the sheet round-trips through the book")
    func theSheetRoundTripsThroughTheBook() throws {
        var sheet = BookStyleSheet.default
        sheet.bodySize = .large
        sheet.lineSpacing = .loose
        sheet.bodyFamily = .kai
        let book = Book(
            title: "Untitled",
            author: "",
            shelfId: UUID(),
            styleSheet: sheet,
            createdAt: .now,
            updatedAt: .now
        )
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded.styleSheet == sheet)
        #expect(decoded.effectiveStyleSheet == sheet)
    }

    @Test("a book without a sheet reads the default")
    func aBookWithoutASheetReadsTheDefault() throws {
        let book = Book(title: "Untitled", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded.styleSheet == nil)
        #expect(decoded.effectiveStyleSheet == BookStyleSheet.default)
    }

    @Test("a book.json written before the sheet existed still decodes")
    func aBookJSONWrittenBeforeTheSheetStillDecodes() throws {
        // = the repo's own convention: = every optional field is added
        // with a default, = so an older file decodes. = This is the raw
        // JSON of a book as it was written before the sheet.
        let raw = """
        {
          "id": "\(UUID().uuidString)",
          "title": "Old Book",
          "author": "",
          "shelfId": "\(UUID().uuidString)",
          "length": "medium",
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let data = Data(raw.utf8)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded.styleSheet == nil)
        #expect(decoded.effectiveStyleSheet == BookStyleSheet.default)
        #expect(decoded.title == "Old Book")
    }

    @Test("a sheet missing a key reads that key's default")
    func aSheetMissingAKeyReadsThatKeysDefault() throws {
        // = a sheet written with fewer keys still reads, = and each
        // missing key falls back to the default's value.
        let raw = """
        { "bodySize": "large" }
        """
        let decoded = try JSONDecoder().decode(BookStyleSheet.self, from: Data(raw.utf8))
        #expect(decoded.bodySize == .large)
        #expect(decoded.lineSpacing == BookStyleSheet.default.lineSpacing)
        #expect(decoded.firstLineIndent == BookStyleSheet.default.firstLineIndent)
        #expect(decoded.segmentSpacing == BookStyleSheet.default.segmentSpacing)
        #expect(decoded.bodyFamily == BookStyleSheet.default.bodyFamily)
        #expect(decoded.headingSizes == BookStyleSheet.default.headingSizes)
    }
}
