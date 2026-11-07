//
//  WenshuContentRolesTests.swift
//
//  The engine's two new content roles: = the footnote and the caption.
//
//  WHY THEY ARE HERE AND NOT IN THE APP: = these are the ENGINE's
//  knobs, = so the engine's own suite is where they are proved. = The
//  app's bridge (= `EngineStyleSheetBridge`) maps the sheet onto them,
//  and its own suite measures that mapping.
//
//  EVERY CASE ASSERTS THE RENDERED ATTRIBUTES (= the font and the
//  paragraph style the engine actually painted), = not a helper's return
//  value, = because a test that only read the property's name would
//  pass on the wrong property.
//

import AppKit
import Foundation
import Testing
@testable import MarkdownEngine

@Suite("Wenshu's two new content roles")
struct WenshuContentRolesTests {
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

    /// The paragraph style the engine put on the text at `needle`.
    private func paragraphStyle(
        _ text: String,
        at needle: String,
        configuration: MarkdownEditorConfiguration
    ) -> NSParagraphStyle? {
        let styled = MarkdownASTStyler.styleAttributes(
            text: text,
            fontName: "Songti SC",
            fontSize: 13,
            configuration: configuration
        )
        let position = (text as NSString).range(of: needle).location
        var result: NSParagraphStyle?
        for (range, attributes) in styled where NSLocationInRange(position, range) {
            if let style = attributes[.paragraphStyle] as? NSParagraphStyle { result = style }
        }
        return result
    }

    /// A configuration whose two caption sizes DIFFER (= so a swap
    /// between them is visible).
    ///
    /// = The book's own sheet gives both captions the same size (= 11pt
    /// each, = the print rule), = so a test built from the sheet could
    /// not tell the two apart. = Here the two are 9 and 11, = so the
    /// figure's caption and the table's caption are told apart by their
    /// SIZE, = which is the thing the engine's own knob decides.
    private func configurationWithDistinctCaptionSizes() -> MarkdownEditorConfiguration {
        var config = MarkdownEditorConfiguration.default
        config.footnotes = FootnoteStyle(fontName: "Kaiti SC", fontSize: 9)
        config.captions = CaptionStyle(figureFontSize: 9, tableFontSize: 11)
        return config
    }

    // MARK: - The footnote

    /// A footnote definition is painted at the note's own size.
    ///
    /// MUTATION: = the engine's `footnoteFont` drops the note's size
    /// (= it reads the base font's size) = → the note is painted at the
    /// body's size.
    @Test("a footnote definition is painted at the note's own size")
    func aFootnoteDefinitionIsPaintedAtTheNoteSize() {
        let config = configurationWithDistinctCaptionSizes()
        let text = "[^note]: 这是注释。\n"

        let noteFont = font(text, at: "这是注释", configuration: config)

        #expect(noteFont != nil, "the note must carry a font of its own")
        #expect(noteFont?.pointSize == 9, "the note must be painted at the note's own size")
        #expect(noteFont?.pointSize != 13,
                "the note's size must differ from the body's (= the body's own size is 13)")
    }

    /// A footnote definition wears the note's own face.
    ///
    /// MUTATION: = the engine's `footnoteFont` drops the note's face
    /// (= it keeps the body's) = → the note is painted in the body's
    /// face.
    @Test("a footnote definition wears the note's own face")
    func aFootnoteDefinitionWearsTheNoteFace() {
        let config = configurationWithDistinctCaptionSizes()
        let text = "[^note]: 这是注释。\n"

        let noteFont = font(text, at: "这是注释", configuration: config)

        #expect(noteFont?.fontName.contains("Kaiti") == true,
                "the note must wear the note's own face")
    }

    /// A footnote definition carries no first-line indent (= it is not
    /// an ordinary body paragraph).
    ///
    /// = The BODY carries one (= 26pt, = the sheet's own indent), = so
    /// the assertion is not vacuous: = a note that inherited the
    /// body's indent would show 26 here, = and a note with no indent of
    /// its own shows 0.
    ///
    /// MUTATION: = the engine's `ownSizeParagraphStyle` takes the
    /// body's first-line indent = → the note is indented like a body
    /// paragraph.
    @Test("a footnote definition carries no first-line indent")
    func aFootnoteDefinitionCarriesNoFirstLineIndent() {
        var config = configurationWithDistinctCaptionSizes()
        config.paragraph.firstLineHeadIndent = 26
        let text = "[^note]: 这是注释。\n"

        let style = paragraphStyle(text, at: "这是注释", configuration: config)

        #expect(style != nil, "the note must carry a paragraph style of its own")
        #expect(style?.firstLineHeadIndent == 0,
                "a note is not an ordinary body paragraph (= it carries no first-line indent)")
        #expect(style?.firstLineHeadIndent != 26,
                "the note must not inherit the body's own indent")
    }

    /// A footnote with NO voice of its own reads as the body (= the
    /// engine's default is upstream's own behaviour).
    ///
    /// MUTATION: = the engine's `footnoteVoiceIsOn` always returns true
    /// (= the note is given a size even with no knob) = → the note is
    /// painted at a size of its own instead of the body's.
    @Test("a footnote with no voice of its own reads as the body")
    func aFootnoteWithNoVoiceReadsAsTheBody() {
        var config = MarkdownEditorConfiguration.default
        // = No voice: = neither knob is set.
        let text = "[^note]: 这是注释。\n"

        let noteFont = font(text, at: "这是注释", configuration: config)

        #expect(noteFont == nil,
                "with no voice of its own the note must carry no font (= the body renders it)")
    }

    // MARK: - The captions

    /// A figure caption is painted at the FIGURE's own size.
    ///
    /// MUTATION: = the engine's `captionSize` returns the TABLE's size
    /// for a figure caption (= the two are swapped) = → the figure
    /// caption is painted at the table's size.
    @Test("a figure caption is painted at the figure's own size")
    func aFigureCaptionIsPaintedAtItsOwnSize() {
        let config = configurationWithDistinctCaptionSizes()
        // = A figure caption FOLLOWS an image block, = so the caption
        // paragraph is the one right after the image.
        let text = "![图](a.png)\n\n这是图注。\n"

        let captionFont = font(text, at: "这是图注", configuration: config)

        #expect(captionFont != nil, "the caption must carry a font of its own")
        #expect(captionFont?.pointSize == 9,
                "a figure caption must be painted at the figure caption's own size")
    }

    /// A table caption is painted at the TABLE's own size.
    ///
    /// MUTATION: = the engine's `captionSize` returns the FIGURE's size
    /// for a table caption (= the two are swapped) = → the table
    /// caption is painted at the figure's size.
    @Test("a table caption is painted at the table's own size")
    func aTableCaptionIsPaintedAtItsOwnSize() {
        let config = configurationWithDistinctCaptionSizes()
        // = A table caption PRECEDES a table block.
        let text = "这是表注。\n\n| a | b |\n| - | - |\n| 1 | 2 |\n"

        let captionFont = font(text, at: "这是表注", configuration: config)

        #expect(captionFont != nil, "the caption must carry a font of its own")
        #expect(captionFont?.pointSize == 11,
                "a table caption must be painted at the table caption's own size")
    }

    /// The two caption sizes REACH DIFFERENT PARAGRAPHS (= the figure's
    /// caption and the table's caption are told apart by their size).
    ///
    /// = This case exists because the two roles are told apart by their
    /// NEIGHBOUR (= an image above, = a table below), = so a caption
    /// that took the wrong role's size would still be painted = = unless
    /// the two roles' sizes differ, = and only then.
    @Test("the two caption roles take their own sizes")
    func theTwoCaptionRolesTakeTheirOwnSizes() {
        let config = configurationWithDistinctCaptionSizes()
        let text = "![图](a.png)\n\n这是图注。\n\n这是表注。\n\n| a | b |\n| - | - |\n| 1 | 2 |\n"

        let figureFont = font(text, at: "这是图注", configuration: config)
        let tableFont = font(text, at: "这是表注", configuration: config)

        #expect(figureFont?.pointSize == 9, "the figure caption takes the figure's size")
        #expect(tableFont?.pointSize == 11, "the table caption takes the table's size")
    }
}
