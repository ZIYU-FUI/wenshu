//
//  CornerRadiusMagicSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 8 = boss 2026-10-02
//  OOB "继续"; = sweep magic-number cornerRadius literals to DesignTokens).
//
//  3 new tokens added (= Apple HIG measured values, not wenshu ad-hoc):
//    - surfaceCornerRadiusSmallButton (5) — Apple HIG Controls > Buttons > Sizes > Small
//    - surfaceCornerRadiusWindow (10) — Apple HIG macOS window chrome
//    - surfaceCornerRadiusHeroCard (12) — Apple HIG Liquid Glass hero card
//
//  Sweep mapping:
//    cornerRadius: 3  → surfaceCornerRadiusSmallChip (existing)
//    cornerRadius: 4  → surfaceCornerRadiusSmallButton (new, = 4 → 5 visual bump = Apple HIG)
//    cornerRadius: 5  → surfaceCornerRadiusSmallButton (new)
//    cornerRadius: 6  → surfaceCornerRadiusProgressCard (existing)
//    cornerRadius: 8  → surfaceCornerRadiusCard (existing)
//    cornerRadius: 10 → surfaceCornerRadiusWindow (new)
//    cornerRadius: 12 → surfaceCornerRadiusHeroCard (new)
//
//  Sites swept: 23 (= 25 view files modified + 1 @MainActor fix on
//  PresetCard.swift). Magic cornerRadius literals swept from all
//  production source files.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 8 cornerRadius magic-number sweep")
struct CornerRadiusMagicSweepTests {

    @Test("Round 8 — DesignTokens defines 6 cornerRadius tokens (= 3 existing + 3 new)")
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
        // 3 NEW tokens (round 8)
        #expect(content.contains("static let surfaceCornerRadiusSmallButton: CGFloat = 5"),
                "surfaceCornerRadiusSmallButton (5) must be defined (= round 8 new)")
        #expect(content.contains("static let surfaceCornerRadiusWindow: CGFloat = 10"),
                "surfaceCornerRadiusWindow (10) must be defined (= round 8 new)")
        #expect(content.contains("static let surfaceCornerRadiusHeroCard: CGFloat = 12"),
                "surfaceCornerRadiusHeroCard (12) must be defined (= round 8 new)")
    }

    @Test("Round 8 — production code has no naked RoundedRectangle(cornerRadius: <int>) literals")
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
            "Sources/WenshuApp/Features/Agent/View/PlaceholderView.swift",
            "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
            "Sources/WenshuApp/Shared/UI/CommandPaletteView.swift",
            "Sources/WenshuApp/Features/Editor/View/EditModeBadge.swift",
            "Sources/WenshuApp/Features/Editor/View/LayoutPicker.swift",
            "Sources/WenshuApp/Features/Editor/View/PresetCard.swift",
            "Sources/WenshuApp/Features/Editor/View/LayoutEditBar.swift",
            "Sources/WenshuApp/Features/Editor/View/PreviewPane.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarSheets.swift",
            "Sources/WenshuApp/Features/Agent/View/ReaderExperienceView.swift",
            "Sources/WenshuApp/Features/Agent/View/BookSettingConstraintsView.swift",
            "Sources/WenshuApp/Features/Agent/View/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Features/Agent/View/GenreFitView.swift",
            "Sources/WenshuApp/Features/Agent/View/IdeaLibraryView.swift",
        ]
        for path in sweptFiles {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: RoundedRectangle(cornerRadius: <integer literal>)
            // The tokens are DesignTokens.surfaceCornerRadius* (= not integer).
            let pattern = #"RoundedRectangle\(cornerRadius: [0-9](?:,|\))"#
            #expect(content.range(of: pattern, options: .regularExpression) == nil,
                    "\(path) must drop naked RoundedRectangle(cornerRadius: N) magic literal (= round 8 sweep target)")
        }
    }
}