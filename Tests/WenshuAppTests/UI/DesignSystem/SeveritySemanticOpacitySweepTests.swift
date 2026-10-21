//
//  SeveritySemanticOpacitySweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB sweep closure mode).
//
//  Sweep round 74 migrated TodoListView's chipStyle to AnyShapeStyle
//  + DesignTokens.accentTintOpacityHero. TodoListView was later
//  deleted with the right-rail todo chain (= PaneView ->
//  DynamicZoneView -> TodoListView), so its chipStyle test went with
//  it. The 2 remaining tests guard the severity-opacity invariants
//  that still have live owners.
//
//  Apple HIG semantic mapping (= severity hierarchy):
//  - `.low`    → AnyShapeStyle(.secondary.opacity(0.15))   (= neutral subtle)
//  - `.medium` → AnyShapeStyle(.secondary.opacity(0.2))    (= neutral medium)
//  - `.high`   → AnyShapeStyle(.orange.opacity(accentTintOpacityHero))  (= warning)
//  - `.urgent` → AnyShapeStyle(.red.opacity(accentTintOpacityHero))    (= critical)
//
//  Other severity-opacity sites preserved at call site:
//  - LongFormGuardrailsView L227-229 (.strict/.warn/.off) → 0.18 literal
//  - ReaderExperienceView L207-209 (score-based) → 0.22 literal
//  - GenreFitView L216-218 (score-based) → 0.22 literal
//  - ChatToolUsePartView L169/171 (.green/.red) → 0.06 literal
//  - BookSettingConstraintsView L284 (.red) → 0.15 literal
//
//  These preserved values are wenshu-specific severity tiers
//  (= Apple HIG has no canonical severity opacity scale).

import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("Severity semantic opacity sweep (= LongFormGuardrailsView badge)")
struct SeveritySemanticOpacitySweepTests {

    @Test("ReaderExperienceView scoreBadge preserved at call site (= severity 0.22)")
    func readerExperienceScoreBadgePreserved() throws {
        let url = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/Features/Agent/View/ReaderExperienceView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        // ReaderExperienceView is preserved (= wenshu-specific 0.22)
        #expect(content.contains(".green.opacity(0.22)"),
                "ReaderExperienceView high score should keep 0.22 literal")
        #expect(content.contains(".orange.opacity(0.22)"),
                "ReaderExperienceView mid score should keep 0.22 literal")
        #expect(content.contains(".gray.opacity(0.22)"),
                "ReaderExperienceView low score should keep 0.22 literal")
    }

    @Test("accentTintOpacityHero = 0.18 (round 73 + 74 unified value)")
    func accentTintOpacityHeroUnifiedValue() throws {
        let url = SourceLocator.repoRoot
            .appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("accentTintOpacityHero: Double = 0.18"),
                "DesignTokens.accentTintOpacityHero should be 0.18")
    }
}
