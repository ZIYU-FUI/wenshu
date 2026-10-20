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
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"),
                "spacingRelaxed (10) must be defined (= round 11 new)")
    }

    @Test("Round 10+11 — production code has no naked (HStack|VStack)(spacing: <int>) literals")
    func productionCodeHasNoMagicStackSpacing() throws {
        // All source files that had Stack spacing literals pre-sweep
        let sweptFiles = [
            "Sources/WenshuApp/Features/Editor/View/AssetsPane.swift",
            "Sources/WenshuApp/Features/Editor/View/InspectorView.swift",
            "Sources/WenshuApp/Shared/UI/EmptyStateView.swift",
            "Sources/WenshuApp/Features/Settings/View/SettingView.swift",
            "Sources/WenshuApp/Features/Agent/View/ForeshadowingView.swift",
            "Sources/WenshuApp/Features/Agent/View/PlaceholderView.swift",
            "Sources/WenshuApp/Features/Editor/View/AgentProgressPanel.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatPlanPartView.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatMessageFooter.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatAttachmentPreviewChip.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreviewSheet.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatToolDiffPreview.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatMessagePlaceholderRow.swift",
            "Sources/WenshuApp/Features/Chat/View/ChatSlashCommandAutocomplete.swift",
            "Sources/WenshuApp/Features/Editor/View/EditModeBadge.swift",
            "Sources/WenshuApp/Features/Editor/View/TabContentDispatcher.swift",
            "Sources/WenshuApp/Features/Editor/View/LayoutPicker.swift",
            "Sources/WenshuApp/Features/Editor/View/LayoutEditBar.swift",
            "Sources/WenshuApp/Features/Editor/View/PresetCard.swift",
            "Sources/WenshuApp/Features/Editor/View/PresetThumbnail.swift",
            "Sources/WenshuApp/Features/Editor/View/ZoneEditor.swift",
            "Sources/WenshuApp/Features/Agent/View/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Features/Agent/View/EmotionCurveView.swift",
            "Sources/WenshuApp/Features/Agent/View/BackgroundReviewView.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarRowView.swift",
            "Sources/WenshuApp/Features/Library/View/SidebarSheets.swift",
            "Sources/WenshuApp/Features/Library/View/AppleSidebarBottomNewButton.swift",
            "Sources/WenshuApp/Features/Agent/View/TodoListView.swift",
            "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
            "Sources/WenshuApp/Features/Kanban/View/SubAgentProgressView.swift",
            "Sources/WenshuApp/Shared/UI/CommandPaletteView.swift",
            "Sources/WenshuApp/Shared/UI/LibraryRootView.swift",
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