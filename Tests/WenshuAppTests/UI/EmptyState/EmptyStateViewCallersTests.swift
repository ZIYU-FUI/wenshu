//
//  EmptyStateViewCallersTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-12 OOB 'the current empty state isn't a single component,
//  can you abstract a UI component? While you're at it, on the empty-state icon: double the size and use the thinnest
//  strokes. The goal is to unify all empty-state styles' + 'audit the right column's 12 tabs; many of them
//  are missing an empty state'):
//
//  Code-level verification (= no UI render) that the 12 specialized
//  tool tabs (= Foreshadowing / Placeholder / Plot Thread / Long-Form
//  Guardrails / Reader Experience / Genre Fit / Emotion Curve / Character
//  Relationships / Character Lifecycle / Idea Library / Tag Manager /
//  Book Settings) + the editor / chat / PreviewPane (= the 3 main
//  empty-state zones) ALL use the unified EmptyStateView component.
//
//  Before this regression test, a single tab could lose its empty state
//  (= e.g. switch to a hand-rolled VStack + Text layout) and ship
//  with the legacy 38 PT icon + wrong padding (= breaking boss's
//  'unify the empty-state style across all of them' directive).
//
//  These tests don't render views; they verify the source-file
//  structure (= code-level verification of the empty-state
//  component discipline).

import Testing
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — EmptyStateView caller coverage (= 12 specialized tool tabs + 3 main zones)")
struct EmptyStateViewCallersTests {

    /// boss 9/12 OOB 'audit the right column's 12 tabs': the 12 specialized tool
    /// tabs MUST use the unified EmptyStateView (= no hand-rolled
    /// VStack + Text duplicates = no legacy 38 PT icons).
    @Test("all_12_specialized_tool_tabs_use_EmptyStateView")
    func all_12_specialized_tool_tabs_use_EmptyStateView() throws {
        // The 12 specialized tool tab files (= the canonical list
        // per the boss's OOB; = the inspector's ZoneContentView tabs).
        let twelveToolFiles = [
            "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift",
            "Sources/WenshuApp/Views/Tools/PlaceholderView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/PlotThreadView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/GenreFitView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/EmotionCurveView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift",
        ]
        #expect(twelveToolFiles.count == 12, "Specialized tool tab list must be 12 (= boss's OOB count)")
        var missing: [String] = []
        for file in twelveToolFiles {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                Issue.record("Specialized tool tab file MUST exist: \(file)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            // The file MUST reference EmptyStateView (= the unified
            // component; = no hand-rolled empty state).
            // Strip comments (= historical notes mentioning
            // EmptyStateView don't count as actual usage).
            let stripped = content.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
            }.joined(separator: "\n")
            if !stripped.contains("EmptyStateView(") {
                missing.append(file)
            }
        }
        #expect(
            missing.isEmpty,
            "Specialized tool tabs not using EmptyStateView (= boss's '统一所有空态的样式' OOB): \(missing)"
        )
    }

    /// boss 9/12 OOB 'editor and chat — empty state wasn't pulled out into a component': the editor +
    /// chat zones MUST also use the unified EmptyStateView (= boss
    /// explicitly listed them in the same OOB as the 12 tabs).
    @Test("editor_and_chat_zones_use_EmptyStateView")
    func editor_and_chat_zones_use_EmptyStateView() throws {
        let mainZoneFiles = [
            // WorkspaceView = editor zone (EditorPlaceholder)
            "Sources/WenshuApp/Views/Workspace/WorkspaceView.swift",
            // PreviewPane = middle-left assets column (the middle-left cards area)
            "Sources/WenshuApp/Views/Workspace/PreviewPane.swift",
            // ChatHelpTextOverlay = chat empty state with inline Settings link
            "Sources/WenshuApp/Views/Chat/ChatHelpTextOverlay.swift",
        ]
        var missing: [String] = []
        for file in mainZoneFiles {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: url.path) else {
                Issue.record("Main zone file MUST exist: \(file)")
                continue
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            let stripped = content.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
            }.joined(separator: "\n")
            if !stripped.contains("EmptyStateView(") {
                missing.append(file)
            }
        }
        #expect(
            missing.isEmpty,
            "Main zones not using EmptyStateView (= boss's '编辑器, 聊天的空态没有取组件' OOB): \(missing)"
        )
    }

    /// boss 9/12 OOB 'audit every icon position and replace them all consistently': the empty state
    /// icons MUST use LucideThinIcon (= 1 PT hairline stroke; =
    /// matches the unified empty-state icon visual contract).
    /// No hand-rolled `Image(systemName:)` (= SF Symbol fallback
    /// would break the unified icon style).
    @Test("EmptyStateView_uses_LucideThinIcon_for_visual_consistency")
    func EmptyStateView_uses_LucideThinIcon_for_visual_consistency() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/UI/EmptyState/EmptyStateView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(
            stripped.contains("LucideThinIcon("),
            "EmptyStateView MUST render its icon via LucideThinIcon (= 1 PT hairline stroke = unified visual contract)"
        )
    }
}
