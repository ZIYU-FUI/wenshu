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

    @Test("the first-line indent reaches the body paragraph (= 首行缩进)")
    func theFirstLineIndentReachesTheBodyParagraph() {
        var config = MarkdownEditorConfiguration.default
        config.paragraph.firstLineHeadIndent = 26

        let (_, style) = TextStylingService.makeBaseFontAndStyle(
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )

        #expect(style.headIndent == 26, "two characters at 13pt")
    }

    @Test("a quote wears a face and a size of its own (= the print quote)")
    func theQuoteWearsItsOwnFaceAndSize() {
        var config = MarkdownEditorConfiguration.default
        config.blockquote.fontName = "Kaiti SC"
        config.blockquote.fontSize = 12.5

        let styled = MarkdownASTStyler.styleAttributes(
            text: "> 引文",
            fontName: "Songti SC",
            fontSize: 13,
            configuration: config
        )
        let fonts = styled.compactMap { $0.1[.font] as? NSFont }

        #expect(fonts.contains { $0.fontName.contains("Kaiti") },
                "the quote must wear the quote's face")
        #expect(fonts.contains { $0.pointSize == 12.5 },
                "the quote must be set at the quote's size")
    }
}
