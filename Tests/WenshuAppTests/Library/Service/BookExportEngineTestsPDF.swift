//
//  BookExportEngineTestsPDF.swift · Wenshu
//
//  The PDF export pays for the whole chapter. A chapter longer than one
//  page prints on more pages, every line of it is drawn exactly once, and
//  the setting it prints in is the book's own sheet rather than a size the
//  exporter picked for itself.
//

import AppKit
import Foundation
import PDFKit
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("BookExportEngine PDF pagination")
struct BookExportEngineTestsPDF {

    /// A chapter of `segments` paragraphs of `sentences` sentences each.
    private static func chapter(segments: Int, sentences: Int = 6) -> String {
        (1...segments).map { index in
            (1...sentences).map { "第\(index)段第\($0)句，文枢导出整章的内容。" }.joined()
        }.joined(separator: "\n\n")
    }

    /// The bottom of the last line a page's glyph range holds.
    private static func lastLineBottom(_ layout: NSLayoutManager, range: NSRange) -> CGFloat {
        var bottom: CGFloat = 0
        layout.enumerateLineFragments(forGlyphRange: range) { rect, used, _, _, _ in
            bottom = max(bottom, rect.minY + used.height)
        }
        return bottom
    }

    private static func laidOut(_ text: String, sheet: BookStyleSheet = .default)
            -> BookPDFTypesetter.LaidOutText {
        BookPDFTypesetter.laidOutBody(text, sheet: sheet)
    }

    /// The whole of the short chapter, and the body of the one that runs long.
    private static let shortChapterBody = "\u{5f88}\u{77ed}\u{7684}\u{4e00}\u{7ae0}\u{3002}"

    /// How many times a sentence reads in extracted page text.
    private static func occurrences(of sentence: String, in text: String) -> Int {
        max(0, text.components(separatedBy: sentence).count - 1)
    }

    @Test("A chapter longer than one page is cut across pages")
    func longChapterGetsPages() {
        let laid = Self.laidOut(Self.chapter(segments: 40))
        #expect(laid.pages.count > 1,
                "a 40-segment chapter printed on one page (= the rest of the chapter was thrown away)")
        #expect(laid.layout.numberOfGlyphs > 0,
                "the chapter's text was never set, so there was nothing to lay out")
    }

    @Test("Pages are cut at whole lines: none missing, none twice")
    func pagesCoverEveryLineOnce() {
        let laid = Self.laidOut(Self.chapter(segments: 25))
        let pages = laid.pages
        #expect(pages.first?.glyphRange.location == 0,
                "the first page starts at the chapter's first glyph")
        #expect(pages.last?.glyphRange.upperBound == laid.layout.numberOfGlyphs,
                "the last page ends at the chapter's last glyph")
        for (previous, next) in zip(pages, pages.dropFirst()) {
            #expect(next.glyphRange.location == previous.glyphRange.upperBound,
                    "a page opened where the one before it stopped closed (= lines between them would be lost, and lines in both would print twice)")
        }
        for page in pages {
            #expect(page.glyphRange.length > 0, "an empty page carries no text to print")
        }
    }

    @Test("The page count rises with the amount of text")
    func pageCountRisesWithText() {
        let short = Self.laidOut(Self.chapter(segments: 8)).pages.count
        let long = Self.laidOut(Self.chapter(segments: 40)).pages.count
        #expect(long > short,
                "five times the chapter printed on the same number of pages")
    }

    @Test("No page is given more column than it holds")
    func everyPageFitsItsColumn() {
        let laid = Self.laidOut(Self.chapter(segments: 30))
        for (index, page) in laid.pages.enumerated() {
            let budget = index == 0
                ? BookPDFTypesetter.firstPageTextHeight
                : BookPDFTypesetter.pageTextHeight
            let used = Self.lastLineBottom(laid.layout, range: page.glyphRange) - page.firstLineOriginY
            #expect(used <= budget + 1,
                    "page \(index) laid out \(used) pt of text into a \(budget) pt column")
        }
    }

    @Test("The exported chapter is set from the book's sheet")
    func theSettingComesFromTheSheet() {
        let sheet = BookStyleSheet.default
        let text = BookPDFTypesetter.bodyText("一段正文。", sheet: sheet)
        let size = CGFloat(sheet.bodySize.points)
        let attributes = text.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? NSFont
        let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle

        #expect(font?.pointSize == size,
                "the exported body is not set at the sheet's body size")
        #expect(font?.fontName == NSFont(name: sheet.bodyFamily.postScriptName, size: size)?.fontName,
                "the exported body does not wear the face the sheet names (= the one installed on this machine)")
        #expect(paragraph?.lineHeightMultiple == CGFloat(sheet.lineSpacing.multiple),
                "the line height is not the sheet's multiple of the body size")
        #expect(paragraph?.firstLineHeadIndent == CGFloat(sheet.firstLineIndent.characters) * size,
                "the opening line is not pushed in by the sheet's own count of characters")
        #expect(paragraph?.paragraphSpacing == CGFloat(sheet.segmentSpacing.characters) * size,
                "the gap between segments is not the sheet's own gap")
    }

    @Test("A title is set from the sheet's ladder, not a size the exporter picked")
    func theTitleComesFromTheLadder() {
        let sheet = BookStyleSheet.default
        let font = BookPDFTypesetter.titleText("第一章", sheet: sheet)
            .attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        #expect(font?.pointSize == CGFloat(sheet.headingSize(forLevel: 1)),
                "the chapter title is not the ladder's own top size")
    }

    @Test("The written PDF carries every page the chapter was cut into")
    func theWrittenPDFCarriesTheWholeChapter() async throws {
        let fm = FileManager.default
        let libraryRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-pdf-\(UUID().uuidString)")
        let bookDir = libraryRoot
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000000", isDirectory: true)
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent("00000000-0000-0000-0000-000000000001", isDirectory: true)
        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        try fm.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: libraryRoot) }

        let longChapterID = UUID(uuidString: "22222222-2222-3333-4444-555555555555")!
        let shortChapterID = UUID(uuidString: "33333333-2222-3333-4444-555555555555")!
        let longChapter = Self.chapter(segments: 40)
        try Data(longChapter.utf8).write(
            to: chaptersDir.appendingPathComponent("\(longChapterID.uuidString).md"))
        try Data(Self.shortChapterBody.utf8).write(
            to: chaptersDir.appendingPathComponent("\(shortChapterID.uuidString).md"))

        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-pdf-out-\(UUID().uuidString).pdf")
        defer { try? fm.removeItem(at: destination) }

        let expectedPages = Self.laidOut(longChapter).pages.count
        try await PathGuard.$libraryRootOverride.withValue(libraryRoot.path) {
            _ = try await BookExportEngine().exportBook(
                id: bookID, to: destination, format: .pdf)
        }

        guard let document = PDFDocument(url: destination) else {
            Issue.record("the export wrote no readable PDF at \(destination.path)")
            return
        }
        #expect(document.pageCount == expectedPages + 1,
                "the PDF holds the long chapter's pages plus the short chapter's one page")
        #expect(expectedPages > 1,
                "the fixture chapter fits on one page, so it proves nothing about the rest")

        // The text is drawn as text, so what each page holds reads back: a
        // page whose lines were never set reads empty, and a line set twice
        // reads twice. The two sentences named below are the chapter's own
        // first and last, and they hold no character a PDF reader may hand
        // back as a Kangxi-radical code point instead (= the check on the
        // words is a check on the words).
        var pageReads: [String] = []
        for pageIndex in 0..<document.pageCount {
            let onPage = document.page(at: pageIndex)?.string ?? ""
            #expect(!onPage.isEmpty, "page \(pageIndex) of the export holds no text at all")
            pageReads.append(onPage)
        }
        let printed = pageReads.joined()
        #expect(Self.occurrences(of: "第1段第1句", in: printed) == 1,
                "the chapter's opening sentence does not read exactly once")
        #expect(Self.occurrences(of: "第40段第6句", in: printed) == 1,
                "the chapter's closing sentence does not read exactly once (= the export stops short of the end of the chapter)")

        // Reading back cannot hand over less than the book holds.
        let readCharacters = pageReads.reduce(0) { $0 + $1.count }
        let bookCharacters = longChapter.count + Self.shortChapterBody.count
        #expect(readCharacters >= bookCharacters,
                "the export read \(readCharacters) characters out of a book holding \(bookCharacters)")

        // The short chapter's page carries more than the title it was named
        // with, so its body was set on that page too.
        let shortPage = pageReads[expectedPages]
        #expect(shortPage.count > shortChapterID.uuidString.count,
                "the short chapter's page holds its title and none of its body")
    }
}
