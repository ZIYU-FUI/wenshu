//
//  EmptyStateViewDesignTokensTests.swift · Wenshu · v0.71 P1 batch 3
//
// 
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

    /// iron-rule 6 = 'no magic numbers in view code'; v3.0 sweep
    /// migrates the 76 PT empty-state icon size into
    /// `IconStyle.emptyStateHero` (= the canonical Apple HIG surface);
    /// the v3.0 sweep deleted `DesignTokens.emptyStateIconSize`
    /// (= commit 63a83f168) because every production-code caller was
    /// migrated.
    @Test("icon_size_uses_IconStyle_emptyStateHero")
    func icon_size_usesDesignTokens_emptyStateIconSize() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("IconStyle.emptyStateHero") || src.contains(".emptyStateHero"),
            "EmptyStateView must reference IconStyle.emptyStateHero (= the v3.0 canonical surface; = replaces the pre-v3.0 DesignTokens.emptyStateIconSize)"
        )
    }

    /// 
    /// `DesignTokens.spacingSection`.
    @Test("icon_title_gap_usesDesignTokens_chromePaddingEmptyStateGap")
    func icon_title_gap_usesDesignTokens_chromePaddingEmptyStateGap() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("DesignTokens.spacingSection"),
            "EmptyStateView must reference DesignTokens.spacingSection"
        )
    }

    /// 
    /// `DesignTokens.spacingTight`.
    @Test("title_body_gap_usesDesignTokens_chromePaddingSmall")
    func title_body_gap_usesDesignTokens_chromePaddingSmall() throws {
        let src = try Self.loadEmptyStateSource()
        #expect(
            src.contains("DesignTokens.spacingTight"),
            "EmptyStateView must reference DesignTokens.spacingTight"
        )
    }

    /// 
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

    /// 
    /// 22 PT gap, 6 PT title-body gap, 360 PT max-width) MUST be defined
    /// in DesignTokens.swift (= the single source of truth).
    ///
    /// As of the v3.0 icon sweep (= commit 63a83f168) the
    /// emptyStateIconSize token is deleted (= the empty-state icon
    /// size now lives in IconStyle.emptyStateHero); = the test
    /// pins the canonical contract that the token is gone and the
    /// value is no longer a magic-number duplicate.
    @Test("design_tokens_drops_emptyStateIconSize_in_favor_of_IconStyle")
    func design_tokens_defines_canonical_empty_state_values() throws {
        let tokensURL = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let tokens = try String(contentsOf: tokensURL, encoding: .utf8)
        #expect(
            !tokens.contains("emptyStateIconSize: CGFloat = 76"),
            "DesignTokens.emptyStateIconSize must be deleted (= the v3.0 sweep migrated all callers into IconStyle.emptyStateHero; = the size now lives in one canonical surface, not two)"
        )
        #expect(
            tokens.contains("spacingSection: CGFloat = 24"),
            "DesignTokens.spacingSection must be 24 PT (= the v3.0 HIG calibration; = empty-state icon→title gap)"
        )
    }
}
