//
//  WenshuStyleKnobsTests.swift
//
//  The three knobs the book style sheet needs, = measured on the engine
//  itself: = the heading face, = the first-line indent, = and the line
//  height as a multiple of the body's own size.
//
//  WHY THEY ARE HERE AND NOT IN THE APP: = these are the ENGINE's
//  knobs, = so the engine's own suite is where they are proved. = The
//  app's bridge (= `EngineStyleSheetBridge`) maps the sheet onto them,
//  and its own suite measures that mapping.
//

import AppKit
import Foundation
import Testing
@testable import MarkdownEngine

@Suite("Wenshu's style knobs")
struct WenshuStyleKnobsTests {
    /// The font the engine put on the text at `needle`.
    private func font(
        _ text: String,
        at needle: String,
        configuration: MarkdownEditorConfiguration
    ) -> NSFont? {
        let styled = MarkdownASTStyler.styleAttributes(
            text: text,
            fontName: "Songti SC",
            fontSize: 13,
            configuration: configuration
        )
        let position = (text as NSString).range(of: needle).location
        var result: NSFont?
        for (range, attributes) in styled where NSLocationInRange(position, range) {
            if let font = attributes[.font] as? NSFont { result = font }
        }
        return result
    }

    @Test("the heading face is used for the headings, = and the body keeps its own")
    func theHeadingFaceIsUsedForTheHeadings() {
        var config = MarkdownEditorConfiguration.default
        config.headings.fontName = "Heiti SC"

        let text = "# 标题\n\n正文。"
        let heading = font(text, at: "标题", configuration: config)
        let body = font(text, at: "正文", configuration: config)

        // The engine BOLDS the heading (= so its PostScript name is the
        // bold variant), = so the family is what the face is read from.
        #expect(heading?.fontName.contains("Heiti") == true,
                "the heading must wear the heading face")
        // The body carries NO font attribute of its own (= the engine
        // gives the text view the base font), = so the body keeps the
        // body's face.
        #expect(body == nil, "the body must not be given a font of its own")
    }

    @Test("no heading face = the body face (= the behaviour before the knob)")
    func noHeadingFaceKeepsTheBodyFace() {
        var config = MarkdownEditorConfiguration.default
        config.headings.fontName = nil

        let text = "# 标题\n\n正文。"
        let heading = font(text, at: "标题", configuration: config)

        #expect(heading?.fontName.contains("Songti") == true,
                "without a heading face the heading wears the body face")
        #expect(heading?.fontName.contains("Heiti") != true,
                "without a heading face the heading is not in the heading face")
    }

    @Test("the line height as a multiple of the body's own size (= 行距)")
    func theLineHeightIsAMultipleOfTheBodySize() {
        var config = MarkdownEditorConfiguration.default
        config.paragraph.lineHeightMultipleOfFontSize = 1.55

        let (font, style) = TextStylingService.makeBaseFontAndStyle(
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )

        #expect(font.pointSize == 13)
        #expect(style.minimumLineHeight == ceil(13 * 1.55) + config.paragraph.lineHeightExtraSpacing,
                "the line height is 1.55 x the body size (= plus the extra points)")
    }

    @Test("no multiple = the font's own leading (= the behaviour before the knob)")
    func noMultipleKeepsTheFontsOwnLeading() {
        var config = MarkdownEditorConfiguration.default
        config.paragraph.lineHeightMultipleOfFontSize = nil

        let (font, style) = TextStylingService.makeBaseFontAndStyle(
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )

        let leading = font.ascender - font.descender + font.leading
        #expect(style.minimumLineHeight == ceil(leading) + config.paragraph.lineHeightExtraSpacing)
    }

    @Test("the first-line indent reaches the body paragraph (= the FIRST line only)")
    func theFirstLineIndentReachesTheBodyParagraph() {
        var config = MarkdownEditorConfiguration.default
        config.paragraph.firstLineHeadIndent = 26

        let (font, style) = TextStylingService.makeBaseFontAndStyle(
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )

        // The shape is measured, = not the property's name: = the two
        // AppKit properties are not interchangeable (= `headIndent`
        // moves the CONTINUATION lines, = `firstLineHeadIndent` moves
        // the first one), = and a test that only reads the property
        // would pass on the wrong one.
        #expect(style.firstLineHeadIndent == 26, "two characters at 13pt")
        #expect(style.headIndent == 0, "the wrapped lines stay at the margin")

        let lines = renderedLineLeftEdges(
            text: "一二三四五六七八九十一二三四五六七八九十",
            font: font,
            style: style,
            width: 60
        )
        #expect(lines.count >= 2, "the text must wrap, = or there is no second line to measure")
        #expect(lines.first == 26, "the FIRST line is indented by the knob")
        #expect(lines.dropFirst().allSatisfy { $0 == 0 },
                "the wrapped lines are NOT indented (= the knob is not a hanging indent)")
    }

    /// The left edge of every rendered line, = measured through a real
    /// layout manager (= so the paragraph style's own effect is read
    /// back, = not the property that was set).
    private func renderedLineLeftEdges(
        text: String,
        font: NSFont,
        style: NSParagraphStyle,
        width: CGFloat
    ) -> [CGFloat] {
        let storage = NSTextStorage(string: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: 1000))
        // The container's own padding (5pt by default) sits BETWEEN the
        // margin and the text, = so it would be measured as part of the
        // indent. = It is zeroed here so the number read back is the
        // paragraph's own.
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let range = NSRange(location: 0, length: (text as NSString).length)
        storage.addAttribute(.font, value: font, range: range)
        storage.addAttribute(.paragraphStyle, value: style, range: range)
        layout.ensureLayout(for: container)

        var edges: [CGFloat] = []
        var glyphIndex = 0
        let glyphCount = layout.numberOfGlyphs
        while glyphIndex < glyphCount {
            var effectiveRange = NSRange()
            _ = layout.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let lineOrigin = layout.location(forGlyphAt: glyphIndex)
            edges.append(lineOrigin.x)
            glyphIndex = NSMaxRange(effectiveRange)
        }
        return edges
    }

    @Test("a quote wears a face and a size of its own (= the print quote)")
    func theQuoteWearsItsOwnFaceAndSize() {
        var config = MarkdownEditorConfiguration.default
        config.blockquote.fontName = "Kaiti SC"
        config.blockquote.fontSize = 12.5

        // = The quote carries an emphasised word, = because that is
        // where the voice used to break: = the plain text wore the
        // quote's face, = and the emphasised word reverted to the
        // body's.
        let styled = MarkdownASTStyler.styleAttributes(
            text: "> 引文 **粗**",
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )
        // = The engine hides a marker (= the `>` and the `**`) by
        // drawing it in its own 0.1pt font, = so those ranges are the
        // engine's marker ranges and NOT the quote's text. = The
        // quote's own ranges are the ones a reader sees.
        let fonts = styled.compactMap { $0.1[.font] as? NSFont }
            .filter { $0.pointSize > 1 }

        #expect(fonts.count >= 2, "the quote's text carries at least the plain and the emphasised range")
        // = EVERY one of the quote's ranges wears the quote's face AND
        // its size, = the emphasised word included (= a quote whose
        // paragraph is set in one face and whose emphasised word is set
        // in another would be two voices in one paragraph).
        for font in fonts {
            #expect(font.fontName.contains("Kaiti"),
                    "every range of a quote wears the quote's face: \(font.fontName)")
            #expect(font.pointSize == 12.5,
                    "every range of a quote wears the quote's size: \(font.pointSize)")
        }
    }
}
