//
//  AccentTintOpacitySweepTests.swift · Wenshu
//
//  The hero accent wash — the tint an accent-filled pill, badge or card
//  sits on — is one value, `DesignTokens.accentTintOpacityHero`, and every
//  surface that wants it asks for it by name.
//
//  The figure is the app's own: Apple ships no accent-wash scale. That is
//  the reason it may not be repeated at a call site. Three surfaces
//  reading 0.18 by hand are three surfaces that can drift apart with
//  nothing left to compare them against.
//
//  A bare `.opacity(0.X)` elsewhere is not a defect. SwiftUI spells an
//  opacity inline as idiom; what gets tokenized is a value the app has
//  decided is canonical.

import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("AccentTintOpacityHero kanban migration")
struct AccentTintOpacitySweepTests {

    @Test("Zero magic .tint.opacity(0.18) literal")
    func zeroMagicTintOpacity18() throws {
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
        //
        // The accent tint MOVED off `KanbanView.swift` (the board's cards
        // carry the group's status tone, = `status.boardTone`, so the
        // board applies no accent tint at all) and onto
        // `KanbanTicketDetailSheet.swift`, which is the surface that
        // draws it (= `.tint.opacity(DesignTokens.accentTintOpacityHero)`
        // in a Capsule). This file's own comment already said the sites
        // moved; the expectation now names where they moved TO.
        let content = try String(
            contentsOf: SourceLocator.repoRoot
                .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift"),
            encoding: .utf8
        )
        let content2 = try String(
            contentsOf: SourceLocator.repoRoot
                .appendingPathComponent("Sources/WenshuApp/Features/Kanban/View/KanbanTicketDetailSheet.swift"),
            encoding: .utf8
        )

        // KanbanTicketDetailSheet is the surface that applies the accent
        // tint, so it is the one that must read the token.
        #expect(content2.contains("DesignTokens.accentTintOpacityHero"),
                "KanbanTicketDetailSheet should use DesignTokens.accentTintOpacityHero")
        // KanbanView applies the group's status tone instead of an accent
        // tint, so it must NOT carry the token (= the tint belongs to the
        // detail sheet alone).
        #expect(!content.contains("DesignTokens.accentTintOpacityHero"),
                "KanbanView applies the group's status tone, not the accent tint")
    }

    @Test("accentTintOpacityHero value is 0.18 (hero accent canonical)")
    func accentTintOpacityHeroValueIs018() throws {
        // Verify the DesignTokens token value (= the source of truth).
        let designTokens = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: designTokens, encoding: .utf8)
        #expect(content.contains("accentTintOpacityHero: Double = 0.18"),
                "DesignTokens.accentTintOpacityHero should be 0.18")
    }
}
