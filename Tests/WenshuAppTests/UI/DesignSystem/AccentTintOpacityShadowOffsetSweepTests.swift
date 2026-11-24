//
//  AccentTintOpacityShadowOffsetSweepTests.swift · Wenshu
//
//  Two values the app decided once and then repeated: the wash an
//  accent-filled surface sits on, and the vertical offset a window or a
//  button casts. Each is a DesignTokens figure now, and a call site that
//  spells one again is a second opinion nobody reconciled.

import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("Accent-tint opacity + shadow offset tokens")
struct AccentTintOpacityShadowOffsetSweepTests {

    @Test("Swept sites use DesignTokens for accent opacity + shadow offset")
    func sweptSitesUseDesignTokens() throws {
        let root = SourceLocator.repoRoot
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        // The swept sites MOVED (= the editor rework moved the accent
        // tint off the editor surfaces and onto the tree / kanban
        // surfaces). The invariant is unchanged: wherever an accent
        // tint is applied, the opacity comes from the token (= never
        // a magic literal).
        //
        // The site that applies it is `KanbanTicketDetailSheet.swift`
        // (= the board's own cards carry the group's status tone, so the
        // board applies no accent tint at all).
        let sweptFiles = [
            ("Features/Kanban/View/KanbanTicketDetailSheet.swift", "accentTintOpacityHero"),
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

    @Test("DesignTokens exposes 3 new tokens")
    func designTokensExposesNewTokens() throws {
        let root = SourceLocator.repoRoot
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "accentTintOpacityHero",
            "surfaceShadowOffsetWindow",
            "surfaceShadowOffsetButton",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic accent.opacity(0.12) or (0.18) in source tree")
    func zeroMagicAccentOpacity() throws {
        let root = SourceLocator.repoRoot
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
                if line.contains("Color.accentColor.opacity(0.12)")
                    || line.contains("Color.accentColor.opacity(0.18)") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic accent.opacity: \(violations)")
    }

    @Test("Zero magic .shadow(...y: 4) or (...y: 2) in source tree")
    func zeroMagicShadowOffset() throws {
        let root = SourceLocator.repoRoot
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
                // Magic literal y: 4 / y: 2 (not DesignTokens. surfaceShadowOffset...)
                if (line.contains("y: 4") || line.contains("y: 2"))
                    && line.contains(".shadow")
                    && !line.contains("DesignTokens.") {
                    violations.append("\(url.lastPathComponent):\(index + 1)")
                }
            }
        }

        #expect(violations.isEmpty, "Unexpected magic .shadow y: literal: \(violations)")
    }
}
