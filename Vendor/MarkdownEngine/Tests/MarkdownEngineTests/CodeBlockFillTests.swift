//
//  CodeBlockFillTests.swift
//  MarkdownEngineTests
//
//  A fenced code block's fill is the block's OWN knob, separate from the
//  inline code's.
//
//  WHY
//  ===
//  The engine used to give the fenced block and the inline code ONE value
//  (= the syntax highlighter's background), so the two could not be told
//  apart. A fenced block then painted the highlighter's background across
//  the container's FULL width (= the wide slab the editor showed around
//  every fenced code block).
//
//  The knob gives the fenced block its own fill (= `.highlighter` = the
//  upstream behaviour, = `.none` = no fill of the block's own), and the
//  inline code keeps the highlighter's background either way.
//
//  WHAT THIS TEST DOES
//  ===================
//  It reads the STYLED ATTRIBUTES (= what the renderer draws from), for
//  three cases:
//
//    * the default (= `.highlighter`): the fenced block carries the
//      highlighter's background (= the upstream behaviour, = so the knob's
//      default changes nothing for an embedder that does not set it),
//    * `.none`: the fenced block carries NO background at all,
//    * `.none` and an inline code span in the same document: the INLINE
//      code still carries the highlighter's background (= the knob is the
//      fenced block's own, = turning it off does not turn the inline
//      code's off with it).
//
//  A source-text assertion cannot catch this: the fill reaches the screen
//  through the attributes the styler writes, and the renderer keys the
//  full-width slab off the very same attribute.
//

import AppKit
import Testing
@testable import MarkdownEngine

@MainActor
@Suite("Code block fill")
struct CodeBlockFillTests {

    /// A highlighter with a background of its own, so the test can tell
    /// the highlighter's colour from any other background.
    private struct FixedBackgroundHighlighter: SyntaxHighlighter {
        let background = NSColor(calibratedWhite: 0.42, alpha: 1)

        func codeFont(size: CGFloat) -> NSFont {
            NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }

        func backgroundColor() -> NSColor { background }

        func highlight(code: String, language: String?) -> NSAttributedString? { nil }

        var appearanceDidChangeNotification: Notification.Name? { nil }
    }

    /// The fenced block's own background, read from the styled ranges.
    ///
    /// The code's characters are the ones the fenced block owns; the
    /// markers around them are the engine's own (= hidden at 0.1 PT).
    private func fencedBackground(
        _ text: String,
        configuration: MarkdownEditorConfiguration
    ) -> NSColor? {
        let styled = MarkdownASTStyler.styleAttributes(
            text: text,
            fontName: "SF Pro",
            fontSize: 14,
            configuration: configuration
        )
        // The code's own characters: the run between the fences.
        let code = "let answer = 42"
        let position = (text as NSString).range(of: code).location
        var result: NSColor?
        for (range, attributes) in styled where NSLocationInRange(position, range) {
            if let color = attributes[.backgroundColor] as? NSColor { result = color }
        }
        return result
    }

    /// The inline code's own background, read from the styled ranges.
    private func inlineBackground(
        _ text: String,
        configuration: MarkdownEditorConfiguration
    ) -> NSColor? {
        let styled = MarkdownASTStyler.styleAttributes(
            text: text,
            fontName: "SF Pro",
            fontSize: 14,
            configuration: configuration
        )
        let code = "inline"
        let position = (text as NSString).range(of: code).location
        var result: NSColor?
        for (range, attributes) in styled where NSLocationInRange(position, range) {
            if let color = attributes[.backgroundColor] as? NSColor { result = color }
        }
        return result
    }

    /// A configuration whose highlighter paints a background of its own.
    private func configuration(fill: CodeBlockFill) -> MarkdownEditorConfiguration {
        var config = MarkdownEditorConfiguration.default
        var services = config.services
        services.syntaxHighlighter = FixedBackgroundHighlighter()
        config.services = services
        config.codeBlock.fill = fill
        return config
    }

    private static let fenced = """
    ```swift
    let answer = 42
    ```
    """

    @Test("the default paints the highlighter's background (= the upstream behaviour)")
    func theDefaultKeepsTheHighlighterBackground() {
        let config = configuration(fill: .highlighter)
        #expect(config.codeBlock.fill == .highlighter,
                "the knob's default must stay the upstream behaviour")
        let background = fencedBackground(Self.fenced, configuration: config)
        #expect(background != nil,
                "the fenced block must carry the highlighter's background by default")
    }

    @Test("no fill means the fenced block carries no background at all")
    func noFillRemovesTheFencedBackground() {
        let config = configuration(fill: .none)
        let background = fencedBackground(Self.fenced, configuration: config)
        #expect(background == nil,
                """
                the fenced code block still carries a background \
                (\(background?.description ?? "nil")): the block paints a fill of \
                its own, = so it reads as a slab laid over the page.
                """)
    }

    @Test("the inline code keeps its background when the block's fill is off")
    func inlineCodeKeepsItsBackground() {
        let text = "A line with `inline` code in it."
        let config = configuration(fill: .none)
        let background = inlineBackground(text, configuration: config)
        #expect(background != nil,
                """
                the inline code lost its background: the knob is the FENCED \
                block's own, = so turning the block's fill off must not turn the \
                inline code's off with it.
                """)
    }
}
