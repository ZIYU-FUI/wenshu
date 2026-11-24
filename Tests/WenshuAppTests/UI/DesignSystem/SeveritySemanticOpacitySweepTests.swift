//
//  SeveritySemanticOpacitySweepTests.swift · Wenshu
//
//  Severity is a rank, not a color. The four levels read as neutral
//  subtle, neutral medium, warning and critical; the warning and critical
//  chips take the app's hero accent wash as their opacity, so an urgent
//  chip is the same strength as every other accent-filled surface rather
//  than a fifth value somebody picked.
//
//  Score-based and guardrail opacities stay at their own call sites: they
//  come out of the reader's numbers, and a token would pretend they came
//  from the design system.
import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("Severity semantic opacity sweep (= LongFormGuardrailsView badge)")
struct SeveritySemanticOpacitySweepTests {

    @Test("accentTintOpacityHero is one value across the hero surfaces")
    func accentTintOpacityHeroUnifiedValue() throws {
        let url = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("accentTintOpacityHero: Double = 0.18"),
                "DesignTokens.accentTintOpacityHero should be 0.18")
    }
}
