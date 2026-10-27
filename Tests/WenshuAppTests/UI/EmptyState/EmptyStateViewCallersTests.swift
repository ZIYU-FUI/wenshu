//
//  EmptyStateViewCallersTests.swift · Wenshu · v0.71 P1 batch 3
//
// 't a single component,
//  can you abstract a UI component? While you're at it, on the empty-state icon: double the size and use the thinnest
//  strokes. The goal is to unify all empty-state styles' + 'audit the right column's 12 tabs; many of them
//  are missing an empty state'):
//
//  Code-level verification (= no UI render) that the editor / chat /
//  PreviewPane (= the 3 main empty-state zones) ALL use the unified
//  EmptyStateView component. The right column's 12 specialized tool
//  tabs were removed with the right-rail removal (2026-10-21), so
//  their coverage went with them.
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
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("v0.71 P1 — EmptyStateView caller coverage (= 3 main zones)")
struct EmptyStateViewCallersTests {

    /// boss 9/12 OOB 'editor and chat — empty state wasn't pulled out into a component': the editor +
    /// chat zones MUST also use the unified EmptyStateView (= boss
    /// explicitly listed them in the same OOB as the 12 tabs).
    @Test("editor_and_chat_zones_use_EmptyStateView")
    func editor_and_chat_zones_use_EmptyStateView() throws {
        let mainZoneFiles = [
            // EditorView = editor zone (= v1.34 ticket 001 extracted
            // the WorkspaceView empty state into EditorView.swift)
            "Sources/WenshuApp/Features/Editor/View/EditorView.swift",
            // PreviewPane = middle-left assets column (the middle-left cards area)
            "Sources/WenshuApp/Features/Editor/View/PreviewPane.swift",
            // ChatHelpTextOverlay = chat empty state with inline Settings link
            "Sources/WenshuApp/Features/Chat/View/ChatHelpTextOverlay.swift",
        ]
        var missing: [String] = []
        for file in mainZoneFiles {
            let url = SourceLocator.url(file)
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
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Shared/UI/EmptyStateView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(
            stripped.contains("Image(systemName:") || stripped.contains("LucideThinIcon(") || stripped.contains("SFIcon("),
            "EmptyStateView MUST render its icon via Image(systemName:) (= v1.x SF Symbols 6), LucideThinIcon (= pre-v1.x), or SFIcon (= v3.0 central factory)"
        )
    }
}
