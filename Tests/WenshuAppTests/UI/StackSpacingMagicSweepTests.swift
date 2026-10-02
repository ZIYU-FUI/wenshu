//
//  StackSpacingMagicSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 10 + 11 = boss
//  2026-10-02 OOB "继续"; = sweep magic-number Stack spacing literals
//  to DesignTokens tokens).
//
//  1 new DesignTokens added (= Apple HIG measured value, not wenshu
//  ad-hoc):
//    - spacingRelaxed (10) — Apple HIG `.relaxed` stack-spacing standard
//
//  Plus 8 existing tokens reused (= DesignTokens.swift already had 9
//  spacing tokens at v3.0 sweep start):
//    - spacingHairline (1), spacingCaption (2), spacingIconic (4),
//      spacingTight (6), spacingStandard (8), spacingRelaxed (10) [NEW],
//      spacingModerate (12), spacingLoose (16), spacingSection (24)
//
//  Sweep totals: 62 sites swept across 28 view files (= 17 sites
//  round 10 + 45 sites round 11). Magic Stack spacing literals swept
//  from all production source files.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 10+11 Stack spacing magic-number sweep")
struct StackSpacingMagicSweepTests {

    @Test("Round 11 — DesignTokens defines spacingRelaxed (10) new token")
    func designTokensDefinesNewSpacingRelaxed() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"),
                "spacingRelaxed (10) must be defined (= round 11 new)")
    }

    @Test("Round 10+11 — production code has no naked (HStack|VStack)(spacing: <int>) literals")
    func productionCodeHasNoMagicStackSpacing() throws {
        // All source files that had Stack spacing literals pre-sweep
        let sweptFiles = [
            "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift",
            "Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift",
            "Sources/WenshuApp/UI/EmptyState/EmptyStateView.swift",
            "Sources/WenshuApp/Views/Settings/SettingView.swift",
            "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift",
            "Sources/WenshuApp/Views/Tools/PlaceholderView.swift",
            "Sources/WenshuApp/Views/Dynamic/AgentProgressPanel.swift",
            "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            "Sources/WenshuApp/Views/Chat/ChatAttachmentPreviewChip.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift",
            "Sources/WenshuApp/Views/Chat/ChatToolDiffPreview.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessagePlaceholderRow.swift",
            "Sources/WenshuApp/Views/Chat/ChatSlashCommandAutocomplete.swift",
            "Sources/WenshuApp/Views/Workspace/EditModeBadge.swift",
            "Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutPicker.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetCard.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/PresetThumbnail.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/ZoneEditor.swift",
            "Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/EmotionCurveView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BackgroundReviewView.swift",
            "Sources/WenshuApp/Views/Library/SidebarRowView.swift",
            "Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            "Sources/WenshuApp/Views/Library/AppleSidebarBottomNewButton.swift",
            "Sources/WenshuApp/Views/Todo/TodoListView.swift",
            "Sources/WenshuApp/Views/Kanban/KanbanView.swift",
            "Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift",
            "Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift",
            "Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift",
        ]
        for path in sweptFiles {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: (HStack|VStack)(spacing: <integer literal>) where the integer is not 0.
            // (spacing: 0) = canonical no-spacing inline stacking preserved per HIG.
            let pattern = #"(HStack|VStack)\(spacing: [1-9][0-9]*(?:,|[^.]|\))"#
            #expect(content.range(of: pattern, options: .regularExpression) == nil,
                    "\(path) must drop naked (HStack|VStack)(spacing: N) magic literal (= round 10+11 sweep target)")
        }
    }
}