//
//  ChatBubbleWidthDragThresholdSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 30 verified: wenshu tree uses DesignTokens for
//  chat-bubble maxWidth (= Apple HIG Messages bubble standard) +
//  metadata-panel maxWidth (= Apple HIG compact inset panel
//  standard) + attachment-preview maxSize (= Apple HIG inline
//  attachment preview standard) + plan-list maxWidth (= Apple
//  HIG inline structured list standard) + onboarding-welcome
//  maxWidth (= Apple HIG first-run welcome card standard) +
//  drag-gesture canvas threshold (= wenshu canvas-specific
//  tighter-than-default drag distance).
//
//  Swept sites (= 10):
//  - ChatToolUsePartView.swift L131: .frame(maxWidth: 360)
//  - ChatPlanPartView.swift L173: .frame(maxWidth: 420)
//  - ChatMessageAttachmentPreview.swift L75: .frame(maxWidth: 240, maxHeight: 240)
//  - ChatToolDiffPreview.swift L53: .frame(maxWidth: 360)
//  - ChatToolResultPartView.swift L116: .frame(maxWidth: 360)
//  - ChatSlashCommandAutocomplete.swift L152: .frame(maxWidth: 360)
//  - ReaderExperienceView.swift L114: .frame(maxWidth: 320, alignment: .trailing)
//  - GenreFitView.swift L116: .frame(maxWidth: 320, alignment: .trailing)
//  - LibraryRootView.swift L388: .frame(maxWidth: 480)
//  - ZoneEditor.swift L186: DragGesture(minimumDistance: 5)
//
//  New DesignTokens (= 6):
//  - chatBubbleMaxWidth (360) — Apple HIG macOS chat bubble
//  - metadataPanelMaxWidth (320) — Apple HIG compact inset
//  - attachmentPreviewMaxSize (240) — Apple HIG inline
//    attachment preview
//  - planListMaxWidth (420) — Apple HIG inline structured list
//  - onboardingWelcomeMaxWidth (480) — Apple HIG macOS
//    first-run welcome card
//  - dragGestureThresholdCanvas (5) — wenshu canvas-specific
//    drag threshold tighter than the macOS default 8 PT
//
//  Preserved sites (= 3, Apple SwiftUI canonical):
//  - LayoutEditBar.swift L79: DragGesture(minimumDistance: 0)
//  - LayoutEditBar.swift L156: DragGesture(minimumDistance: 0,
//    coordinateSpace: .global)
//  - ZoneEditor.swift L263: DragGesture(minimumDistance: 0)
//  (= 0 = canonical SwiftUI drag-anywhere pattern; = no magic)

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 30 — chat-bubble maxWidth + drag threshold tokens")
struct ChatBubbleWidthDragThresholdSweepTests {

    @Test("Swept sites use DesignTokens for maxWidth + drag threshold")
    func sweptSitesUseDesignTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, String)] = [
            ("Views/Chat/ChatToolUsePartView.swift", "chatBubbleMaxWidth"),
            ("Views/Chat/ChatPlanPartView.swift", "planListMaxWidth"),
            ("Views/Chat/ChatMessageAttachmentPreview.swift", "attachmentPreviewMaxSize"),
            ("Views/Chat/ChatToolDiffPreview.swift", "chatBubbleMaxWidth"),
            ("Views/Chat/ChatToolResultPartView.swift", "chatBubbleMaxWidth"),
            ("Views/Chat/ChatSlashCommandAutocomplete.swift", "chatBubbleMaxWidth"),
            ("Views/SpecializedTools/ReaderExperienceView.swift", "metadataPanelMaxWidth"),
            ("Views/SpecializedTools/GenreFitView.swift", "metadataPanelMaxWidth"),
            ("Views/Onboarding/LibraryRootView.swift", "onboardingWelcomeMaxWidth"),
            ("Views/Workspace/LayoutPicker/ZoneEditor.swift", "dragGestureThresholdCanvas"),
        ]

        for (relative, expectedToken) in sweptFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            #expect(
                content.contains("DesignTokens.\(expectedToken)"),
                "\(relative) should reference DesignTokens.\(expectedToken)"
            )
        }
    }

    @Test("DesignTokens exposes 6 new tokens")
    func designTokensExposesNewTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "chatBubbleMaxWidth",
            "metadataPanelMaxWidth",
            "attachmentPreviewMaxSize",
            "planListMaxWidth",
            "onboardingWelcomeMaxWidth",
            "dragGestureThresholdCanvas",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic .frame(maxWidth: N) literal in production source")
    func zeroMagicFrameMaxWidth() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }
            guard !url.path.contains("ComponentIndex.md") else { continue }
            guard !url.path.contains("Core/Agent/Specialized/") else { continue }
            guard !url.path.contains("Core/Agent/LongForm/") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Match `.frame(maxWidth: 240)` or `.frame(maxWidth: 320, ...)`
                // (= magic literal NOT preceded by `DesignTokens.`)
                let pattern = #"\.frame\(maxWidth:\s*[0-9]+"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .frame(maxWidth: N) literal: \(violations)")
    }

    @Test("Zero magic DragGesture(minimumDistance: 5) outside DesignTokens")
    func zeroMagicDragGestureMinimumDistance5() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("IconStyles.swift") else { continue }
            guard !url.path.contains("DesignTokens.swift") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                if line.contains("DragGesture(minimumDistance: 5)")
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic DragGesture(minimumDistance: 5): \(violations)")
    }
}
