//
//  FontSystemSizeSweepTests.swift · Wenshu
//
//  Monospaced digits in running text are a text style with a design, not a
//  hand-tuned size: `.caption2.monospaced()` and `.caption.monospaced()` are
//  the two sizes a diff viewer reads at, and each carries its own size and
//  weight from the text-style table.
//
//  The icon factory is the exception the third test pins: it sizes a glyph
//  off `IconStyle.pointSize`, a value the caller picks, so no fixed text
//  style can stand in for `.font(.system(size:))` there.


import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 7 font sweep (= .system(size:) monospaced → .caption/.caption2 + .monospaced())")
struct FontSystemSizeSweepTests {

    @Test("Round 7 — ChatToolDiffPreview diff line viewer uses Apple HIG caption2 + monospaced()")
    func chatToolDiffPreviewUsesCaption2Monospaced() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreview.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.caption2.monospaced())"),
                "ChatToolDiffPreview's diff lines read at the caption2 size with monospaced digits")
        #expect(!content.contains(".font(.system(size: 11"),
                "ChatToolDiffPreview must not size a text style by hand")
    }

    @Test("Round 7 — ChatToolDiffPreviewSheet diff body viewer uses Apple HIG caption + monospaced()")
    func chatToolDiffPreviewSheetUsesCaptionMonospaced() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreviewSheet.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.caption.monospaced())"),
                "ChatToolDiffPreviewSheet's diff body reads at the caption size with monospaced digits")
        #expect(!content.contains(".font(.system(size: 12"),
                "ChatToolDiffPreviewSheet must not size a text style by hand")
    }

    @Test("Round 7 — IconStyles.swift preserves the internal .font(.system(size:)) for SFIcon")
    func iconStylesInternalSystemSizePreserved() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.system(size: pointSizeOverride ?? style.pointSize"),
                "The icon factory sizes a glyph off IconStyle.pointSize, a value the caller picks, so no fixed text style can stand in for it")
    }
}