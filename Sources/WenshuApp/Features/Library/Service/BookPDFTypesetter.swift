//
//  BookPDFTypesetter.swift · Wenshu
//
//  The PDF export's typographer: it turns a chapter plus the book's
//  style sheet into laid-out pages. It holds no document state, reads no
//  file, and writes nothing but the PDF's drawing operations.
//
//  The page is US Letter at 72 dpi, which is the PDF unit, so one point
//  is one PDF unit and the margin is the same on every side. Text is
//  flowed by TextKit: a column is laid out once at the page's width and
//  cut between whole lines, so a line that does not fit the page starts
//  the next one instead of being clipped away.
//
//  A layout travels with its text. NSLayoutManager reads its glyphs from
//  the text storage when it is asked to draw and holds it only weakly, so
//  a layout left alone after its storage goes away has nothing to draw:
//  the storage is kept for as long as any page is still drawn from it.
//

import AppKit
import Foundation

enum BookPDFTypesetter {

    /// The page a book exports onto.
    static let pageSize = CGSize(width: 612, height: 792)

    /// The band every side keeps clear of text.
    static let pageMargin: CGFloat = 50

    /// The room a chapter's title takes on its first page; the body
    /// starts under it.
    static let titleBandHeight: CGFloat = 40

    /// One page's worth of an already laid-out column.
    struct PagePlan {
        /// The glyphs the page draws (= whole lines, so a line is drawn
        /// once and never dropped).
        let glyphRange: NSRange
        /// Where that range's first line sits in the laid-out column, so
        /// the page can be drawn with that line at the top of its text.
        let firstLineOriginY: CGFloat
    }

    /// Text set into a column, and the pages it was cut into. The storage
    /// is held here so the layout can still read its glyphs at the moment
    /// a page is drawn.
    struct LaidOutText {
        let storage: NSTextStorage
        let layout: NSLayoutManager
        let pages: [PagePlan]
    }

    /// The column's width and the text height of a page, once the margin
    /// and the title band are taken off the sheet.
    static var columnWidth: CGFloat { pageSize.width - 2 * pageMargin }
    static var pageTextHeight: CGFloat { pageSize.height - 2 * pageMargin }
    static var firstPageTextHeight: CGFloat { pageTextHeight - titleBandHeight }

    /// The body of a chapter as the sheet sets it: the face the sheet
    /// names when the system has it and the system face when it does not,
    /// the line height as a multiple of the body's own size, the opening
    /// line of each segment pushed in by the sheet's count of characters,
    /// and the gap between segments the same way.
    static func bodyText(_ body: String, sheet: BookStyleSheet) -> NSAttributedString {
        let size = EngineStyleSheetBridge.fontSize(for: sheet)
        let paragraph = NSMutableParagraphStyle()
        let multiple = CGFloat(sheet.lineSpacing.multiple)
        if multiple > 0 { paragraph.lineHeightMultiple = multiple }
        paragraph.firstLineHeadIndent = CGFloat(sheet.firstLineIndent.characters) * size
        paragraph.paragraphSpacing = CGFloat(sheet.segmentSpacing.characters) * size
        return NSAttributedString(string: body, attributes: [
            .font: face(EngineStyleSheetBridge.fontName(for: sheet), size: size),
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.black,
        ])
    }

    /// The chapter title, set in the sheet's heading face at the ladder's
    /// own top size.
    static func titleText(_ title: String, sheet: BookStyleSheet) -> NSAttributedString {
        let size = CGFloat(sheet.headingSize(forLevel: 1))
        return NSAttributedString(string: title, attributes: [
            .font: face(EngineStyleSheetBridge.headingFontName(for: sheet), size: size,
                        fallbackWeight: .bold),
            .foregroundColor: NSColor.black,
        ])
    }

    /// The sheet's face at the size it is used at, and the system face
    /// when the named one is not installed: a book set in a face the
    /// machine does not have still exports, in a face it can read.
    private static func face(_ name: String, size: CGFloat,
                             fallbackWeight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
    }

    /// Lay text out in one column and cut it at whole lines. The first
    /// page is given a shorter column than the pages after it (= the
    /// title band it has already paid for).
    static func layout(
        _ text: NSAttributedString,
        columnWidth: CGFloat,
        firstPageTextHeight: CGFloat,
        pageTextHeight: CGFloat
    ) -> LaidOutText {
        let unlimited = CGFloat(Double.greatestFiniteMagnitude)
        let container = NSTextContainer(size: CGSize(width: columnWidth, height: unlimited))
        container.lineFragmentPadding = 0
        let glyphLayout = NSLayoutManager()
        glyphLayout.addTextContainer(container)
        let storage = NSTextStorage(attributedString: text)
        storage.addLayoutManager(glyphLayout)
        glyphLayout.ensureLayout(for: container)

        let glyphCount = glyphLayout.numberOfGlyphs
        guard glyphCount > 0 else {
            return LaidOutText(storage: storage, layout: glyphLayout, pages: [])
        }

        var lines: [(range: NSRange, top: CGFloat, bottom: CGFloat)] = []
        glyphLayout.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: glyphCount)
        ) { fragmentRect, usedRect, _, lineGlyphRange, _ in
            lines.append((lineGlyphRange,
                          fragmentRect.minY,
                          fragmentRect.minY + usedRect.height))
        }

        var plans: [PagePlan] = []
        var index = 0
        var budget = firstPageTextHeight
        while index < lines.count {
            let pageFirst = lines[index]
            var last = index
            while last + 1 < lines.count,
                  lines[last + 1].bottom - pageFirst.top <= budget {
                last += 1
            }
            plans.append(PagePlan(
                glyphRange: NSRange(location: pageFirst.range.location,
                                    length: lines[last].range.upperBound - pageFirst.range.location),
                firstLineOriginY: pageFirst.top))
            index = last + 1
            budget = pageTextHeight
        }
        return LaidOutText(storage: storage, layout: glyphLayout, pages: plans)
    }

    /// The body of one chapter, set from the sheet and cut across as many
    /// pages as its lines need.
    static func laidOutBody(_ body: String, sheet: BookStyleSheet) -> LaidOutText {
        layout(bodyText(body, sheet: sheet),
               columnWidth: columnWidth,
               firstPageTextHeight: firstPageTextHeight,
               pageTextHeight: pageTextHeight)
    }

    /// Draw the book onto `destination` as a PDF: every chapter opens on
    /// a page and runs onto as many further pages as its lines need.
    ///
    /// The pages go into one PDF context (CoreGraphics writes the
    /// document, so the text stays selectable and a page is not a fixed
    /// grid of pixels). Each page is turned so it is drawn from its top
    /// edge down, which is the direction the column was laid out in: a
    /// page's first line lands under the title band, or at the top margin
    /// on a page that carries no title, and the lines after it follow.
    @discardableResult
    static func write(
        chapters: [(title: String, body: String)],
        sheet: BookStyleSheet,
        to destination: URL
    ) -> Int {
        guard let consumer = CGDataConsumer(url: destination as CFURL) else { return 0 }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return 0 }
        var pageCount = 0

        for chapter in chapters {
            let title = titleText(chapter.title, sheet: sheet)
            let body = laidOutBody(chapter.body, sheet: sheet)

            if body.pages.isEmpty {
                // A chapter with no body still gets its title on a page.
                drawPage(into: context, mediaBox: &mediaBox,
                         title: title, body: nil, plan: nil)
                pageCount += 1
                continue
            }

            for (pageNumber, plan) in body.pages.enumerated() {
                drawPage(into: context, mediaBox: &mediaBox,
                         title: pageNumber == 0 ? title : nil,
                         body: body, plan: plan)
                pageCount += 1
            }
        }

        context.closePDF()
        return pageCount
    }

    /// One printed page inside an open PDF context.
    private static func drawPage(
        into context: CGContext,
        mediaBox: inout CGRect,
        title: NSAttributedString?,
        body: LaidOutText?,
        plan: PagePlan?
    ) {
        context.beginPage(mediaBox: &mediaBox)
        context.saveGState()
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        if let title {
            drawEveryLine(of: title)
        }
        if let body, let plan {
            let top = title == nil ? pageMargin : pageMargin + titleBandHeight
            body.layout.drawGlyphs(
                forGlyphRange: plan.glyphRange,
                at: CGPoint(x: pageMargin, y: top - plan.firstLineOriginY))
        }

        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        context.endPage()
    }

    /// A title takes all of its lines: the band is what the body reserves
    /// for it, not what the title is cut to.
    private static func drawEveryLine(of title: NSAttributedString) {
        let unlimited = CGFloat(Double.greatestFiniteMagnitude)
        let laid = layout(title,
                          columnWidth: columnWidth,
                          firstPageTextHeight: unlimited,
                          pageTextHeight: unlimited)
        guard let first = laid.pages.first, let last = laid.pages.last else { return }
        laid.layout.drawGlyphs(
            forGlyphRange: NSRange(location: first.glyphRange.location,
                                   length: last.glyphRange.upperBound - first.glyphRange.location),
            at: CGPoint(x: pageMargin, y: pageMargin - first.firstLineOriginY))
    }
}
