//
//  SeveritySemanticOpacitySweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule (= boss 2026-10-02 OOB sweep closure mode).
//
//  Sweep round 74: refactor TodoListView chipStyle to use
//  AnyShapeStyle + DesignTokens.accentTintOpacityHero. This enables
//  the future Apple HIG migration to HierarchicalShapeStyle.tertiary
//  (= documented in the chipStyle doc comment block).
//
//  Why AnyShapeStyle matters:
//  - Pre-v3.0: chipStyle returned `(String, Color, Color)` tuple.
//    The third tuple element was a static `Color.X.opacity(N)` that
//    resolved to a flat gray (NOT auto-adapting to dark mode +
//    Liquid Glass).
//  - Post-v3.0: chipStyle returns `(String, Color, AnyShapeStyle)`.
//    The third tuple element is now wrapped in AnyShapeStyle, which
//    preserves the original ShapeStyle (= `.secondary`, `.orange`,
//    `.red`) AND lets future code swap to `.tertiary` without a
//    refactor at every call site.
//
//  Sites touched (1 source file = 1 ticket Q112 atomic):
//  - TodoListView.swift L481: chipStyle signature
//    `(String, Color, Color)` → `(String, Color, AnyShapeStyle)`
//  - TodoListView.swift L498-501: 4 cases
//    `Color.X.opacity(N)` → `AnyShapeStyle(.X.opacity(N))`
//    + 2 sites use `DesignTokens.accentTintOpacityHero` for the
//    severity semantic opacity (= mirrors round 73 kanban migration).
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
//  (= Apple HIG has no canonical severity opacity scale). Round 74
//  migrates ONLY the 4 TodoListView cases (= 1 ticket Q112 atomic)
//  + reuses `accentTintOpacityHero` (= canonical token introduced in
//  round 28 + extended in round 73) for the 2 severity semantic
//  badges (.high / .urgent).

import Testing
import Foundation
@testable import WenshuApp

@Suite("Sweep round 74 — TodoListView chipStyle AnyShapeStyle migration")
struct SeveritySemanticOpacitySweepTests {

    @Test("chipStyle returns AnyShapeStyle for bg")
    func chipStyleReturnsAnyShapeStyle() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root
            .appendingPathComponent("Sources/WenshuApp/Views/Todo/TodoListView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        // Verify chipStyle signature uses AnyShapeStyle for bg
        let sig = #"private func chipStyle(for priority: TodoPriority) -> (String, Color, AnyShapeStyle)"#
        #expect(content.contains(sig),
                "TodoListView.chipStyle should return AnyShapeStyle for bg")

        // Verify 4 priority cases use AnyShapeStyle wrapper
        #expect(content.contains(#"AnyShapeStyle(.secondary.opacity(0.15))"#),
                "low priority should use AnyShapeStyle(.secondary.opacity(0.15))")
        #expect(content.contains(#"AnyShapeStyle(.secondary.opacity(0.2))"#),
                "medium priority should use AnyShapeStyle(.secondary.opacity(0.2))")
        #expect(content.contains(#"AnyShapeStyle(.orange.opacity(DesignTokens.accentTintOpacityHero))"#),
                "high priority should use AnyShapeStyle(.orange.opacity(DesignTokens.accentTintOpacityHero))")
        #expect(content.contains(#"AnyShapeStyle(.red.opacity(DesignTokens.accentTintOpacityHero))"#),
                "urgent priority should use AnyShapeStyle(.red.opacity(DesignTokens.accentTintOpacityHero))")
    }

    @Test("LongFormGuardrailsView badgeColor preserved at call site (= severity 0.18)")
    func longFormGuardrailsBadgeColorPreserved() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        // LongFormGuardrailsView is preserved (= wenshu-specific 0.18)
        #expect(content.contains(".red.opacity(0.18)"),
                "LongFormGuardrailsView .strict should keep 0.18 literal")
        #expect(content.contains(".orange.opacity(0.18)"),
                "LongFormGuardrailsView .warn should keep 0.18 literal")
        #expect(content.contains(".gray.opacity(0.18)"),
                "LongFormGuardrailsView .off should keep 0.18 literal")
    }

    @Test("ReaderExperienceView scoreBadge preserved at call site (= severity 0.22)")
    func readerExperienceScoreBadgePreserved() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift")
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
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root
            .appendingPathComponent("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("accentTintOpacityHero: Double = 0.18"),
                "DesignTokens.accentTintOpacityHero should be 0.18")
    }
}
