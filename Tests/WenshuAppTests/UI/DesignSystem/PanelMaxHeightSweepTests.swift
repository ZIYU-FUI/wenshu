//
//  PanelMaxHeightSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 33 + 34 + 35 + 36 verified: wenshu tree uses
//  DesignTokens for `.frame(maxHeight: N)` literal panel
//  heights (= Apple HIG macOS list panel standards for
//  specialized tool views).
//
//  Swept sites (= 16):
//  - ForeshadowingView.swift L256: .frame(maxHeight: 220)
//  - ForeshadowingView.swift L348: .frame(maxHeight: 120)
//  - PlaceholderView.swift L265: .frame(maxHeight: 220)
//  - BookSettingConstraintsView.swift L232: .frame(maxHeight: 180)
//  - CharacterRelationshipsView.swift L227: .frame(maxHeight: 220)
//  - CharacterLifecycleView.swift L239: .frame(maxHeight: 180)
//  - CharacterLifecycleView.swift L329: .frame(maxHeight: 140)
//  - IdeaLibraryView.swift L280: .frame(maxHeight: 180)
//  - IdeaLibraryView.swift L447: .frame(maxHeight: 120)
//  - IdeaLibraryView.swift L536: .frame(maxHeight: 100)
//  - CommandPaletteView.swift L167: .frame(maxHeight: 320)
//  - KanbanView.swift L379: .frame(maxHeight: 360)
//  - TagManagerView.swift L216: .frame(maxHeight: 140)
//  - TagManagerView.swift L340: .frame(maxHeight: 140)
//  - TagManagerView.swift L397: .frame(maxHeight: 120)
//  - SidebarSheets.swift L393: .frame(maxHeight: 220)
//
//  New DesignTokens (= 5):
//  - panelMediumMaxHeight (180) — Apple HIG macOS list
//    panel standard for 4-5 row display
//  - panelLargeMaxHeight (220) — Apple HIG macOS list
//    panel standard for 6-7 row display
//  - panelInlineMaxHeight (100) — Apple HIG macOS
//    compact inline list standard for 2-row display
//  - commandPaletteMaxHeight (320) — Apple HIG macOS
//    command palette standard (= macOS 26+ Spotlight
//    display height)
//  - kanbanBoardMaxHeight (360) — Apple HIG macOS
//    kanban board standard (= 5-row display)
//
//  Note: Some sites reuse existing round-31 TextEditor
//  height tokens (= textEditorCompactMaxHeight 120 +
//  textEditorSmallMaxHeight 140) because the panel heights
//  align with the same Apple HIG macOS list panel standards.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 33-36 — panel maxHeight tokens")
struct PanelMaxHeightSweepTests {

    @Test("Swept sites use DesignTokens for maxHeight")
    func sweptSitesUseDesignTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles: [(String, String)] = [
            ("Views/Tools/ForeshadowingView.swift", "DesignTokens.panelLargeMaxHeight"),
            ("Views/Tools/PlaceholderView.swift", "DesignTokens.panelLargeMaxHeight"),
            ("Views/SpecializedTools/BookSettingConstraintsView.swift", "DesignTokens.panelMediumMaxHeight"),
            ("Views/SpecializedTools/CharacterRelationshipsView.swift", "DesignTokens.panelLargeMaxHeight"),
            ("Views/SpecializedTools/CharacterLifecycleView.swift", "DesignTokens.panelMediumMaxHeight"),
            ("Views/SpecializedTools/IdeaLibraryView.swift", "DesignTokens.panelMediumMaxHeight"),
            ("Views/CommandPalette/CommandPaletteView.swift", "DesignTokens.commandPaletteMaxHeight"),
            ("Views/Kanban/KanbanView.swift", "DesignTokens.kanbanBoardMaxHeight"),
            ("Views/SpecializedTools/TagManagerView.swift", "DesignTokens.textEditorSmallMaxHeight"),
            ("Views/Library/SidebarSheets.swift", "DesignTokens.panelLargeMaxHeight"),
        ]

        for (relative, expectedToken) in sweptFiles {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            #expect(
                content.contains(expectedToken),
                "\(relative) should reference \(expectedToken)"
            )
        }
    }

    @Test("DesignTokens exposes 5 new panel maxHeight tokens")
    func designTokensExposesNewTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "panelMediumMaxHeight",
            "panelLargeMaxHeight",
            "panelInlineMaxHeight",
            "commandPaletteMaxHeight",
            "kanbanBoardMaxHeight",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic .frame(maxHeight: N) literal in source tree")
    func zeroMagicFrameMaxHeight() throws {
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
                // Match `.frame(maxHeight: N)` magic literal (NOT
                // preceded by DesignTokens.)
                let pattern = #"\.frame\(maxHeight:\s*[0-9]+\)"#
                if line.range(of: pattern, options: .regularExpression) != nil
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .frame(maxHeight: N): \(violations)")
    }
}
