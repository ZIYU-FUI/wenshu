//
//  CornerRadiusMagicSweepTests.swift · Wenshu
//
//  Every corner radius in the app is a named token, and the name says
//  what it rounds: a chip, a small button, a progress card, a card, a
//  window, a hero card. The figures are Apple's measurements for those
//  controls (= Controls > Buttons > Sizes, macOS window chrome), so a
//  surface picks the token for the control it is, never a number it likes.
//
//  The suite fails on a naked `RoundedRectangle(cornerRadius: <literal>)`
//  and on a DesignTokens file missing one of the six.

import Foundation
import Testing
@testable import WenshuApp

@Suite("CornerRadius magic-number sweep")
struct CornerRadiusMagicSweepTests {

    @Test("DesignTokens defines 6 cornerRadius tokens")
    func designTokensDefinesAllCornerRadiusTokens() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // 3 existing tokens
        #expect(content.contains("static let surfaceCornerRadiusSmallChip: CGFloat = 3"),
                "surfaceCornerRadiusSmallChip (3) must be defined")
        #expect(content.contains("static let surfaceCornerRadiusProgressCard: CGFloat = 6"),
                "surfaceCornerRadiusProgressCard (6) must be defined")
        #expect(content.contains("static let surfaceCornerRadiusCard: CGFloat = 8"),
                "surfaceCornerRadiusCard (8) must be defined")
        // The tokens this suite requires to exist 
        #expect(content.contains("static let surfaceCornerRadiusSmallButton: CGFloat = 5"),
                "surfaceCornerRadiusSmallButton (5) must be defined")
        #expect(content.contains("static let surfaceCornerRadiusWindow: CGFloat = 10"),
                "surfaceCornerRadiusWindow (10) must be defined")
        #expect(content.contains("static let surfaceCornerRadiusHeroCard: CGFloat = 12"),
                "surfaceCornerRadiusHeroCard (12) must be defined")
    }

    @Test("Production code has no naked RoundedRectangle(cornerRadius: <int>) literals")
    func productionCodeHasNoMagicCornerRadius() throws {
        let sweptFiles = [
            "Sources/WenshuApp/Shared/UI/HoverWash.swift",
            "Sources/WenshuApp/Features/Editor/View/AssetsPane.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatAttachmentPreviewChip.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatMessageAttachmentPreview.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolUsePartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreview.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreviewSheet.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolResultPartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatSlashCommandAutocomplete.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift",
            "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
            "Sources/WenshuApp/Features/Editor/View/PreviewPane.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarSheets.swift",
        ]
        for path in sweptFiles {
            let url = SourceLocator.url(path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: RoundedRectangle(cornerRadius: <integer literal>)
            // The tokens are DesignTokens.surfaceCornerRadius* (= not integer).
            let pattern = #"RoundedRectangle\(cornerRadius: [0-9](?:,|\))"#
            #expect(content.range(of: pattern, options: .regularExpression) == nil,
                    "\(path) must drop naked RoundedRectangle(cornerRadius: N) magic literal")
        }
    }
}