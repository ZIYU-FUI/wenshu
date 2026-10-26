//
//  MarkdownBlocksView.swift · wenshu
//
//  Renders a text as its markdown blocks.
//
//  This is hermes's shape: = the structure is rendered (= a paragraph,
//  = a list, = a heading, = a code block), = and the model's syntax
//  never reaches the screen. The inline markdown still runs inside a
//  block (= the bold, = the italic, = the code span), = so the words
//  keep their emphasis.
//
//  While the reply streams it stays plain text (= the same reason the
//  chat's text part does: = a half-written marker would make the block
//  layout flicker between two renderings).
//

import SwiftUI

struct MarkdownBlocksView: View {
    /// The text to render.
    let text: String

    /// Whether the reply is still arriving (= plain text while it does).
    let isStreaming: Bool

    /// The font the blocks use (= the caller sets the size, = this view
    /// only adds the bold for a heading and the monospaced for code).
    var baseFont: Font = .body

    init(text: String, isStreaming: Bool = false, baseFont: Font = .body) {
        self.text = text
        self.isStreaming = isStreaming
        self.baseFont = baseFont
    }

    var body: some View {
        if isStreaming {
            // The raw text (= the markers are still being written).
            Text(text)
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(blocks) { block in
                    blockView(block)
                }
            }
        }
    }

    /// The blocks of the text.
    private var blocks: [MarkdownBlock] {
        MarkdownBlocks.parse(text)
    }

    /// One block.
    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(Self.inline(text))
                .font(baseFont)
        case .heading(_, let text):
            Text(Self.inline(text))
                .font(baseFont.bold())
                // The heading trait (= VoiceOver reads it as a heading,
                // = so the reader can jump between the sections).
                .accessibilityAddTraits(.isHeader)
        case .list(let items):
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                        Text(verbatim: "•")
                            .font(baseFont)
                        Text(Self.inline(item.text))
                            .font(baseFont)
                    }
                    .padding(.leading, CGFloat(item.depth) * 16)
                }
            }
        case .code(let text):
            Text(verbatim: text)
                .font(baseFont.monospaced())
                .textSelection(.enabled)
        }
    }

    /// The inline markdown of a block's text.
    ///
    /// The inline parser keeps the whitespace (= the block's own line
    /// breaks), = and the block structure has already been taken out of
    /// the text (= the markers are gone by then).
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
