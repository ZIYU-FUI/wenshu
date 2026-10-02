//
//  FontSystemSizeSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 7 = boss 2026-10-02
//  OOB "继续"). The 2 remaining `.font(.system(size: <X>, design: .monospaced))`
//  patterns (= wenshu-ad-hoc monospaced digit text styles) swept to
//  Apple HIG built-in:
//    - `.font(.system(size: 11, weight: .regular, design: .monospaced))`
//      → `.font(.caption2.monospaced())` (= Apple HIG caption2 = 11 PT + monospaced digit)
//    - `.font(.system(size: 12, weight: .regular, design: .monospaced))`
//      → `.font(.caption.monospaced())` (= Apple HIG caption = 12 PT + monospaced digit)
//
//  Sites swept (2 total):
//    - ChatToolDiffPreview.swift L87 (caption2 = diff line viewer)
//    - ChatToolDiffPreviewSheet.swift L90 (caption = diff body viewer)
//
//  Site preserved (= IconStyles.swift L357 — internal SFIcon factory
//  cannot use the built-in pattern because IconStyle.pointSize is a
//  dynamic value):
//    - IconStyles.swift:357 — `.font(.system(size: style.pointSize, weight: style.fontWeight))`
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 7 font sweep (= .system(size:) monospaced → .caption/.caption2 + .monospaced())")
struct FontSystemSizeSweepTests {

    @Test("Round 7 — ChatToolDiffPreview diff line viewer uses Apple HIG caption2 + monospaced()")
    func chatToolDiffPreviewUsesCaption2Monospaced() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolDiffPreview.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.caption2.monospaced())"),
                "ChatToolDiffPreview diff line viewer must use Apple HIG .caption2.monospaced() (= 11 PT monospaced)")
        #expect(!content.contains(".font(.system(size: 11"),
                "ChatToolDiffPreview must drop .font(.system(size: 11)) wenshu-ad-hoc (= v3.0 round 7 sweep)")
    }

    @Test("Round 7 — ChatToolDiffPreviewSheet diff body viewer uses Apple HIG caption + monospaced()")
    func chatToolDiffPreviewSheetUsesCaptionMonospaced() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.caption.monospaced())"),
                "ChatToolDiffPreviewSheet diff body viewer must use Apple HIG .caption.monospaced() (= 12 PT monospaced)")
        #expect(!content.contains(".font(.system(size: 12"),
                "ChatToolDiffPreviewSheet must drop .font(.system(size: 12)) wenshu-ad-hoc (= v3.0 round 7 sweep)")
    }

    @Test("Round 7 — IconStyles.swift preserves the internal .font(.system(size:)) for SFIcon")
    func iconStylesInternalSystemSizePreserved() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/IconStyles.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".font(.system(size: style.pointSize"),
                "IconStyles.swift L357 SFIcon factory must keep .font(.system(size: style.pointSize)) (= IconStyle.pointSize is dynamic; = the canonical built-in is not available for dynamic sizing; = round 7 sweep exception)")
    }
}