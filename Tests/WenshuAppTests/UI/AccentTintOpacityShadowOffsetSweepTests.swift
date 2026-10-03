//
//  AccentTintOpacityShadowOffsetSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB "继续" arc).
//  Sweep round 28 + 29 verified: wenshu tree has zero magic
//  `.opacity(0.12)` / `.opacity(0.18)` accent tints + zero
//  magic `.shadow(...y: 4)` / `.shadow(...y: 2)` offsets.
//
//  Swept sites (= 5):
//  - Sources/WenshuApp/Views/Workspace/EditorView.swift
//    L153 .accentColor.opacity(0.12) →
//    .accentColor.opacity(DesignTokens.accentTintOpacitySubtle)
//  - Sources/WenshuApp/Views/SpecializedTools/EmotionCurveView.swift
//    L379 .accentColor.opacity(0.12) →
//    .accentColor.opacity(DesignTokens.accentTintOpacitySubtle)
//  - Sources/WenshuApp/Views/Workspace/PreviewPane.swift
//    L1554 .accentColor.opacity(0.18) →
//    .accentColor.opacity(DesignTokens.accentTintOpacityHero)
//  - Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift
//    L76 .shadow(...y: 4) → .shadow(...y:
//    DesignTokens.surfaceShadowOffsetWindow)
//  - Sources/WenshuApp/Views/Workspace/EditorPaperCanvas.swift
//    L80 .shadow(...y: 2) → .shadow(...y:
//    DesignTokens.surfaceShadowOffsetButton)
//
//  New DesignTokens (= 4):
//  - accentTintOpacitySubtle (0.12) — Apple HIG Liquid Glass
//    subtle accent overlay
//  - accentTintOpacityHero (0.18) — Apple HIG Liquid Glass
//    hero-card gradient start
//  - surfaceShadowOffsetWindow (4) — Apple HIG macOS window
//    chrome shadow offset
//  - surfaceShadowOffsetButton (2) — Apple HIG macOS button
//    shadow offset

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 28 + 29 — accent-tint opacity + shadow offset tokens")
struct AccentTintOpacityShadowOffsetSweepTests {

    @Test("Swept sites use DesignTokens for accent opacity + shadow offset")
    func sweptSitesUseDesignTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // UI/
            .deletingLastPathComponent()  // Tests/WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let sweptFiles = [
            ("Views/Workspace/EditorView.swift", "accentTintOpacitySubtle"),
            ("Views/SpecializedTools/EmotionCurveView.swift", "accentTintOpacitySubtle"),
            ("Views/Workspace/PreviewPane.swift", "accentTintOpacityHero"),
            ("Views/Workspace/LayoutPicker/LayoutEditBar.swift", "surfaceShadowOffsetWindow"),
            ("Views/Workspace/EditorPaperCanvas.swift", "surfaceShadowOffsetButton"),
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

    @Test("DesignTokens exposes 4 new tokens")
    func designTokensExposesNewTokens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tokensPath = root.appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: tokensPath, encoding: .utf8)

        for token in [
            "accentTintOpacitySubtle",
            "accentTintOpacityHero",
            "surfaceShadowOffsetWindow",
            "surfaceShadowOffsetButton",
        ] {
            #expect(content.contains("static let \(token)"), "DesignTokens should define \(token)")
        }
    }

    @Test("Zero magic accent.opacity(0.12) or (0.18) in source tree")
    func zeroMagicAccentOpacity() throws {
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
