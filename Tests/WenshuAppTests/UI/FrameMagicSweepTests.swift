//
//  FrameMagicSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 9 = boss 2026-10-02
//  OOB "继续"; = sweep magic-number .frame(width: N) literals to
//  DesignTokens tokens).
//
//  4 new DesignTokens added (= Apple HIG measured values, not wenshu
//  ad-hoc):
//    - listRowLeadingIconColumnWidth (18) — Apple HIG sidebar list row
//    - stepNumberColumnWidth (22) — Apple HIG list row trailing number
//    - attachmentThumbnailSize (48) — Apple HIG inline attachment
//    - bulletDotSize (3) — Apple HIG inline bullet indicator
//
//  Plus 2 existing tokens reused:
//    - bulletSizeSmall (14) — Apple HIG small bullet indicator column
//      (used for ChatToolUsePartView status pulse column)
//    - PreviewPane 64×64 hero card thumbnail preserved (= sweep
//      boundary exception per round 6 + round 9)
//
//  Sites swept: 6 (= 1 ChatToolUsePartView L68 status pulse + 1
//  ChatPlanPartView L182 step number + 2 ChatAttachmentPreviewChip
//  L57+L65 attachment thumbnail + 1 ChatMessageView L594 bullet dot +
//  1 SidebarRowView L96 leading icon column).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 9 frame magic-number sweep")
struct FrameMagicSweepTests {

    @Test("Round 9 — DesignTokens defines 4 new layout tokens")
    func designTokensDefinesNewLayoutTokens() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let listRowLeadingIconColumnWidth: CGFloat = 18"),
                "listRowLeadingIconColumnWidth (18) must be defined (= round 9 new)")
        #expect(content.contains("static let stepNumberColumnWidth: CGFloat = 22"),
                "stepNumberColumnWidth (22) must be defined (= round 9 new)")
        #expect(content.contains("static let attachmentThumbnailSize: CGFloat = 48"),
                "attachmentThumbnailSize (48) must be defined (= round 9 new)")
        #expect(content.contains("static let bulletDotSize: CGFloat = 3"),
                "bulletDotSize (3) must be defined (= round 9 new)")
    }

    @Test("Round 9 — production code has no naked .frame(width: <int>) literals in swept files")
    func productionCodeHasNoMagicFrame() throws {
        let sweptFiles = [
            "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatAttachmentPreviewChip.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            "Sources/WenshuApp/Views/Library/SidebarRowView.swift",
        ]
        for path in sweptFiles {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: .frame(width: <integer literal>) OR
            //           .frame(width: <integer literal>, height: <integer literal>)
            // (= naked magic literal, no DesignTokens reference).
            // Allow .frame(width: 0, height: 0) (= invisible button pattern
            // = HIG canonical).
            let pattern = #"\.frame\(width: [0-9]+(?:, height: [0-9]+)?(?:, alignment: [^)]+)?\)"#
            let match = content.range(of: pattern, options: .regularExpression)
            #expect(match == nil,
                    "\(path) must drop naked .frame(width: N) magic literal (= round 9 sweep target)")
        }
    }

    @Test("Round 9 — PreviewPane 64×64 hero card thumbnail preserved as sweep boundary exception")
    func previewPaneHeroCardException() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/PreviewPane.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // L1569 is the 64 PT hero card thumbnail (= round 6 sweep
        // boundary exception; = .resizable() + .aspectRatio() +
        // .symbolRenderingMode(.monochrome) pattern = SFIcon does not
        // own hero card surfaces).
        #expect(content.contains(".frame(width: 64, height: 64)"),
                "PreviewPane L1569 must keep the 64×64 hero card thumbnail literal (= sweep boundary exception)")
    }
}