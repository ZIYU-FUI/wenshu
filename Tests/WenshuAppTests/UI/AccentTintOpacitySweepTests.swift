//
//  AccentTintOpacitySweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB sweep round 73).
//
//  Sweep round 73: tokenize remaining `.tint.opacity(0.18)` sites
//  (= kanban status badge background = hero accent tint pattern).
//
//  This test verifies the FINAL tokenization state for the
//  `.tint.opacity(DesignTokens.accentTintOpacityHero)` pattern:
//
//  - KanbanView.swift: `.background(.tint.opacity(DesignTokens.accentTintOpacityHero), in: Capsule())`
//  - KanbanTicketDetailSheet.swift: `.background(.tint.opacity(DesignTokens.accentTintOpacityHero), in: Capsule())`
//  - PreviewPane.swift: `Color.accentColor.opacity(DesignTokens.accentTintOpacityHero)` (round 28 baseline)
//
//  Why this matters:
//  - The .tint.opacity(0.18) literal is the canonical "hero accent tint"
//    pattern (= 18% hero accent for badge / pill / chip backgrounds).
//  - Apple's HIG has no canonical opacity scale for "hero accent" — wenshu
//    invented 0.18 as a sensible middle-ground between subtle (0.12) and
//    prominent (0.25+).
//  - Pre-v3.0 call sites hardcoded 0.18 (= 2 sites). Round 28 added
//    `DesignTokens.accentTintOpacityHero` but only PreviewPane adopted it.
//  - Round 73 migrates the 2 kanban sites so all 3 hero-accent call sites
//    share one DesignTokens token (= canonical + auditable).
//
//  Pre-v3.0 round 28 boundary (= preserved): the SwiftUI idiomatic opacity
//  literal (.tint.opacity(0.X)) is NOT itself deprecated — only the magic
//  0.X literal is the tokenization target. Sites that need a value NOT in
//  the DesignTokens opacity scale (= 0.15 / 0.22 / 0.4 / etc.) preserve
//  their literal at call site (= wenshu-specific visual decisions).

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 73 — accentTintOpacityHero kanban migration")
struct AccentTintOpacitySweepTests {

    @Test("Zero magic .tint.opacity(0.18) literal")
    func zeroMagicTintOpacity18() throws {
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

            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
                    continue
                }
                // Skip lines that contain `//` before the magic literal
                let codePart: String
                if let commentStart = line.range(of: "//") {
                    codePart = String(line[..<commentStart.lowerBound])
                } else {
                    codePart = line
                }
                let pattern = #"\.tint\.opacity\(0\.18\)"#
                if codePart.range(of: pattern, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent): \(trimmed)")
                }
            }
        }

        #expect(violations.isEmpty, "Found magic .tint.opacity(0.18): \(violations)")
    }

    @Test("DesignTokens.accentTintOpacityHero usage covers kanban sites")
    func accentTintOpacityHeroUsage() throws {
        // Verify the 3 known call sites use the token (not the literal).
        let content = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/WenshuApp/Views/Kanban/KanbanView.swift"),
            encoding: .utf8
        )
        let content2 = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/WenshuApp/Views/Kanban/KanbanTicketDetailSheet.swift"),
            encoding: .utf8
        )

        // KanbanView + KanbanTicketDetailSheet should both use the token.
        #expect(content.contains("DesignTokens.accentTintOpacityHero"),
                "KanbanView should use DesignTokens.accentTintOpacityHero")
        #expect(content2.contains("DesignTokens.accentTintOpacityHero"),
                "KanbanTicketDetailSheet should use DesignTokens.accentTintOpacityHero")
    }

    @Test("accentTintOpacityHero value is 0.18 (hero accent canonical)")
    func accentTintOpacityHeroValueIs018() throws {
        // Verify the DesignTokens token value (= the source of truth).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let designTokens = root
            .appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: designTokens, encoding: .utf8)
        #expect(content.contains("accentTintOpacityHero: Double = 0.18"),
                "DesignTokens.accentTintOpacityHero should be 0.18")
    }
}
