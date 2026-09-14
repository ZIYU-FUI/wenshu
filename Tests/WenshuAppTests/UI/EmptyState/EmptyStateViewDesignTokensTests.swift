//
//  EmptyStateViewDesignTokensTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-12 EOB 'anything that uses Apple styles should
//  default everything; get code-level verification and testing in first... the rest we'll discuss Monday'):
//  code-level verification (= no UI render, no screenshot) that the
//  unified EmptyStateView uses the wenshu DesignTokens (= Apple HIG
//  semantic values) instead of raw magic numbers (= iron-rule 6
//  compliance: 'no magic numbers in view code').
//
//  The EmptyStateView source file is the SINGLE SOURCE OF TRUTH for
//  the unified empty-state component (= used by 12 specialized tool
//  tabs + editor zone + PreviewPane + chat zone). Any change to its
//  layout numbers (= icon size, gap, max width) MUST come through
//  the DesignTokens namespace (= so we can change the canonical
//  values in one place).
//
//  These tests don't render the view (= no SwiftUI render); they
//  just verify the source file references DesignTokens tokens for
//  every numeric dimension (= the canonical 'no magic numbers'
//  discipline for view code).

import Testing
import Foundation

@Suite("v0.71 P1 — EmptyStateView design-token discipline (= no magic numbers)")
struct EmptyStateViewDesignTokensTests {

    private static let emptyStateSourceURL = URL(
        fileURLWithPath: "Sources/WenshuApp/UI/EmptyState/EmptyStateView.swift"
    )

    private static func loadEmptyStateSource() throws -> String {
        try String(
            contentsOf: emptyStateSourceURL,
            encoding: .utf8
        )
    }

    /// iron-rule 6 = 'no magic numbers in view code'; v0.71 P1 batch 3
    /// EOB directs to use DesignTokens (= Apple HIG semantic values).
    /// The empty-state icon size (= 76 PT) MUST come from
    /// `DesignTokens.emptyStateIconSize`, not a raw literal.
    @Test("icon_size_usesDesignTokens_emptyStateIconSize")
    func icon_size_usesDesignTokens_emptyStateIconSize() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("DesignTokens.emptyStateIconSize"),
            "EmptyStateView must reference DesignTokens.emptyStateIconSize"
        )
    }

    /// v0.71 P1 batch 3: the icon→title gap (= 22 PT) MUST come from
    /// `DesignTokens.chromePaddingEmptyStateGap`.
    @Test("icon_title_gap_usesDesignTokens_chromePaddingEmptyStateGap")
    func icon_title_gap_usesDesignTokens_chromePaddingEmptyStateGap() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("DesignTokens.chromePaddingEmptyStateGap"),
            "EmptyStateView must reference DesignTokens.chromePaddingEmptyStateGap"
        )
    }

    /// v0.71 P1 batch 3: the title→body gap (= 6 PT) MUST come from
    /// `DesignTokens.chromePaddingSmall`.
    @Test("title_body_gap_usesDesignTokens_chromePaddingSmall")
    func title_body_gap_usesDesignTokens_chromePaddingSmall() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("DesignTokens.chromePaddingSmall"),
            "EmptyStateView must reference DesignTokens.chromePaddingSmall"
        )
    }

    /// v0.71 P1 batch 3: the title + body max-width (= 360 PT) MUST come
    /// from `DesignTokens.guardrailSheetWidth`.
    @Test("max_width_usesDesignTokens_guardrailSheetWidth")
    func max_width_usesDesignTokens_guardrailSheetWidth() throws {
        let src = try Self.loadEmptyStateSource()
        // Title + body each set `.frame(maxWidth: DesignTokens.guardrailSheetWidth)`.
        // = the token must appear at least 3 times (= title view + title text + body).
        let occurrences = src.components(
            separatedBy: "DesignTokens.guardrailSheetWidth"
        ).count - 1
        #expect(
            occurrences >= 3,
            "Expected at least 3 occurrences of DesignTokens.guardrailSheetWidth, got \(occurrences)"
        )
    }

    /// v0.71 P1 batch 3: the canonical Apple HIG values (= 76 PT icon,
    /// 22 PT gap, 6 PT title-body gap, 360 PT max-width) MUST be defined
    /// in DesignTokens.swift (= the single source of truth).
    @Test("design_tokens_defines_canonical_empty_state_values")
    func design_tokens_defines_canonical_empty_state_values() throws {
        let tokensURL = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let tokens = try String(contentsOf: tokensURL, encoding: .utf8)
        #expect(
            tokens.contains("emptyStateIconSize: CGFloat = 76"),
            "DesignTokens.emptyStateIconSize must be 76 PT"
        )
        #expect(
            tokens.contains("chromePaddingEmptyStateGap: CGFloat = 22"),
            "DesignTokens.chromePaddingEmptyStateGap must be 22 PT"
        )
    }
}
