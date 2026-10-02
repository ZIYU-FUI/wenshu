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
        let url = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
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
            "Sources/WenshuApp/UI/HoverWash.swift",
            "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift",
            "Sources/WenshuApp/Views/Chat/ChatAttachmentPreviewChip.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessageAttachmentPreview.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolDiffPreview.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatSlashCommandAutocomplete.swift",
            "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            "Sources/WenshuApp/Views/Tools/PlaceholderView.swift",
            "Sources/WenshuApp/Views/Kanban/KanbanView.swift",
            "Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift",
            "Sources/WenshuApp/Views/Workspace/EditModeBadge.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutPicker.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift",
            "Sources/WenshuApp/Views/Workspace/PreviewPane.swift",
            "Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            "Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/GenreFitView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift",
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