//  BookStyleSheetTests.swift
//  wenshu
//
//  A book's style sheet is BOOK-level: = one set runs through the whole
//  book, = and every adjustment acts on the whole book.
//
//  These tests lock four things: = the DEFAULT set is the measured
//  print baseline (= not a guess), = every knob holds a FIXED POSITION
//  (= a sheet cannot express a size the printer would not set), = the
//  persisted sheet carries those positions as NAMES (= never as a list
//  of numbers), = and the sheet round-trips through book.json = while a
//  book that predates it still decodes.

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookStyleSheet (the book's own style set)")
struct BookStyleSheetTests {
    // MARK: - The default IS the print baseline

    @Test("the default sheet is the measured print baseline")
    func theDefaultSheetIsThePrintBaseline() {
        let sheet = BookStyleSheet.default
        // = the print minimum for a novel's body is the fifth size at
        // 10.5pt, = and 13pt is the HIG body size, = so the baseline is
        // the middle one.
        #expect(sheet.bodySize == .medium)
        #expect(sheet.bodySize.points == 13)
        // = print 1.50-1.60 (= the fifth size with 5.25-6.25pt of leading).
        #expect(sheet.lineSpacing == .standard)
        #expect(sheet.lineSpacing.multiple == 1.55)
        // = print first-line indent of two characters, = and print segment
        // spacing of zero.
        #expect(sheet.firstLineIndent == .twoCharacters)
        #expect(sheet.firstLineIndent.characters == 2)
        #expect(sheet.segmentSpacing == .none)
        #expect(sheet.segmentSpacing.characters == 0)
        // = the body is the print body face (= Songti).
        #expect(sheet.bodyFamily == .songti)
        // = a print quote is set in the literary face (= Kai).
        #expect(sheet.quoteFamily == .kai)
        // = print size 3 / size 4 / small size 4 = (16 / 14 / 12pt).
        #expect(sheet.headingLadder == .printStandard)
        #expect(sheet.headingSizes == [16, 14, 12])
        // = a print note and a print caption are always SMALLER than the
        // body, = and a print quote is a different face AND size.
        for body in BookBodySize.allCases {
            #expect(sheet.noteSize < body.points)
            #expect(sheet.figureCaptionSize < body.points)
            #expect(sheet.tableCaptionSize < body.points)
        }
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
        // = a writer chooses a style, = not that a writer sets a size. =
        // So the sizes a sheet can hold are the positions, = and they are
        // enumerable.
        #expect(BookBodySize.allCases.map(\.points) == [12, 13, 14])
        #expect(BookLineSpacing.allCases.map(\.multiple) == [1.45, 1.55, 1.70])
        #expect(BookFirstLineIndent.allCases.map(\.characters) == [0, 2])
        #expect(BookSegmentSpacing.allCases.map(\.characters) == [0, 0.5])
        #expect(BookBodyFamily.allCases.count == 4)
    }

    @Test("every heading ladder a book can hold descends, = and holds printed sizes only")
    func everyHeadingLadderDescendsAndHoldsPrintedSizesOnly() {
        // = the ladder is a POSITION, = so the invariant is checked on
        // EVERY position the type can express (= the default alone would
        // hold whatever the type permits). = A hostile ladder is not
        // expressible at all: = the sizes a sheet can hold are exactly
        // these seven, = and nothing else is reachable.
        #expect(BookHeadingLadder.allCases.count == 3)
        for ladder in BookHeadingLadder.allCases {
            let sizes = ladder.sizes
            #expect(sizes.count == 3)
            // = the ladder DESCENDS: = each size is smaller than the one
            // above it, = and no level repeats. = (= compared without
            // indexing, = so a ladder that is short or empty FAILS the
            // check here = instead of trapping the whole test run.)
            #expect(sizes == sizes.sorted(by: >))
            #expect(Set(sizes).count == sizes.count)
            for size in sizes {
                #expect(Self.printedHeadingSizes.contains(size))
            }
        }
        // = the whole set of sizes a sheet can reach, = and no other.
        let reachable = Set(BookHeadingLadder.allCases.flatMap(\.sizes))
        #expect(reachable == Self.printedHeadingSizes)
    }

    @Test("the sheet holds no stored list of numbers, = so no hostile ladder can be written")
    func theSheetHoldsNoStoredListOfNumbers() {
        // = the invariant the type must HOLD: = a sheet stores POSITIONS,
        // = and a list of numbers is a free knob. = This reads the
        // sheet's own STORED properties, = so it fails the moment a
        // stored array of sizes comes back, = whatever it is called.
        let stored = Mirror(reflecting: BookStyleSheet.default).children
        #expect(!stored.isEmpty)
        for child in stored {
            #expect(
                !(child.value is [Double]),
                "the sheet stores \(child.label ?? "?") as a list of numbers, = and a free knob is what this file forbids"
            )
        }
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

    @Test("every knob and the ladder carry a localized name")
    func everyKnobCarriesALocalizedName() {
        // = the names are LOCALIZED: = a Chinese label, = and never the
        // machine name the file persists.
        for size in BookBodySize.allCases {
            #expect(!size.displayName.isEmpty)
            #expect(size.displayName != size.rawValue)
        }
        for spacing in BookLineSpacing.allCases {
            #expect(!spacing.displayName.isEmpty)
            #expect(spacing.displayName != spacing.rawValue)
        }
        for indent in BookFirstLineIndent.allCases {
            #expect(!indent.displayName.isEmpty)
            #expect(indent.displayName != indent.rawValue)
        }
        for spacing in BookSegmentSpacing.allCases {
            #expect(!spacing.displayName.isEmpty)
            #expect(spacing.displayName != spacing.rawValue)
        }
        for family in BookBodyFamily.allCases {
            #expect(!family.displayName.isEmpty)
            #expect(family.displayName != family.rawValue)
        }
        for ladder in BookHeadingLadder.allCases {
            #expect(!ladder.displayName.isEmpty)
            #expect(ladder.displayName != ladder.rawValue)
        }
    }

    // MARK: - Persistence

    @Test("the sheet round-trips through the book")
    func theSheetRoundTripsThroughTheBook() throws {
        var sheet = BookStyleSheet.default
        sheet.bodySize = .large
        sheet.lineSpacing = .loose
        sheet.bodyFamily = .kai
        sheet.headingLadder = .compact
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

    @Test("the persisted sheet carries the ladder as a NAME, = never as a list of numbers")
    func thePersistedSheetCarriesTheLadderAsAName() throws {
        var sheet = BookStyleSheet.default
        sheet.headingLadder = .compact
        let data = try JSONEncoder().encode(sheet)
        // = the persisted field holds the position's name, = so a reader
        // (= the app, = or another build) reads a POSITION back.
        let persisted = try (JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        #expect(persisted["headingLadder"] as? String == "compact")
        #expect(persisted["headingSizes"] == nil)
        // = and NO number reaches the file: = every persisted value is a
        // name, = so a free size cannot be written at all.
        for (_, value) in persisted {
            #expect(!(value is NSNumber))
        }
    }

    @Test("a hostile or unknown ladder reads as the print baseline")
    func aHostileOrUnknownLadderReadsAsThePrintBaseline() throws {
        // = an unknown name, = a value of the wrong shape, = a null, = a
        // missing key, = and the old persisted shape ( = a list of
        // numbers) all read as the baseline: = a hostile size never
        // survives a decode.
        let hostile = [
            #"{"headingLadder":"hostile"}"#,
            #"{"headingLadder":[16,14,12]}"#,
            #"{"headingLadder":null}"#,
            #"{"headingSizes":[137.5,3.25]}"#,
            #"{"headingSizes":[]}"#,
            #"{"headingSizes":[20,18,16]}"#,
            #"{}"#,
        ]
        for raw in hostile {
            let decoded = try JSONDecoder().decode(BookStyleSheet.self, from: Data(raw.utf8))
            #expect(decoded.headingLadder == .printStandard)
            #expect(decoded.headingSizes == [16, 14, 12])
        }
    }

    @Test("a book.json written with a hostile ladder reads as the print baseline")
    func aBookJSONWrittenWithAHostileLadderReadsAsThePrintBaseline() throws {
        // = the production path: = the file the store writes (= and any
        // file a hostile hand wrote) is read back through the Book, = and
        // the sheet's sizes are the printed ones.
        let raw = """
        {
          "id": "\(UUID().uuidString)",
          "title": "Old Book",
          "author": "",
          "shelfId": "\(UUID().uuidString)",
          "length": "medium",
          "styleSheet": { "headingSizes": [20, 18, 16] },
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let decoded = try JSONDecoder().decode(Book.self, from: Data(raw.utf8))
        #expect(decoded.effectiveStyleSheet.headingLadder == .printStandard)
        #expect(decoded.effectiveStyleSheet.headingSizes == [16, 14, 12])
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

    @Test("the production store writes the ladder as a NAME, = and reads it back")
    @MainActor
    func theProductionStoreWritesTheLadderAsAName() throws {
        // = the production path, = measured on the file the store itself
        // writes: = a hostile ladder cannot be stored, = and the file
        // carries the ladder's name, = never a list of numbers.
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileSystemLibraryStore(rootURL: root)
        let shelf = Bookshelf(id: UUID(), name: "S", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        var sheet = BookStyleSheet.default
        sheet.headingLadder = .compact
        let book = Book(
            id: UUID(),
            title: "X",
            author: "",
            shelfId: shelf.id,
            styleSheet: sheet,
            createdAt: .now,
            updatedAt: .now
        )
        try store.saveBook(book)
        // = the file on disk: = the ladder is a name, = and no number of
        // any kind reaches it.
        let jsonURL = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("books")
            .appendingPathComponent(book.directoryName)
            .appendingPathComponent("book.json")
        let persisted = try (JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String: Any]) ?? [:]
        let sheetJSON = persisted["styleSheet"] as? [String: Any] ?? [:]
        #expect(sheetJSON["headingLadder"] as? String == "compact")
        #expect(sheetJSON["headingSizes"] == nil)
        for (_, value) in sheetJSON {
            #expect(!(value is NSNumber))
        }
        // = and the store reads the position back, = not a size.
        let loaded = try store.loadBook(id: book.id)
        #expect(loaded?.effectiveStyleSheet.headingLadder == .compact)
        #expect(loaded?.effectiveStyleSheet.headingSizes == [15, 13, 11])
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
        #expect(decoded.quoteFamily == BookStyleSheet.default.quoteFamily)
        #expect(decoded.headingLadder == BookStyleSheet.default.headingLadder)
    }

    /// The heading sizes a sheet can reach: = the print baseline and its
    /// two neighbours, = and nothing else.
    private static let printedHeadingSizes: Set<Double> = [11, 12, 13, 14, 15, 16, 18]
}
