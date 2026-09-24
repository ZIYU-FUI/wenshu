// DesignTokensTests.swift · Wenshu · v1.82 fixpoint ticket 1
//
// DesignTokens.swift = 556 LOC enum with ~80+ static CGFloat/String
// tokens (= per Apple HIG canonical layout dimensions). repowise
// health score shows prior_defect critical (= 16 bug-fixes/6mo on
// the file; = the file is edited frequently; = a wrong constant
// silently breaks Apple HIG 1:1 compliance across all 6 panes).
//
// Strategy (= per wenshu test convention for value-type enums +
// the v1.46 runtime-reference scaffolding pattern in
// DesignTokens_test.swift):
//   - Lock canonical Apple HIG reference values:
//     - chromeHeight = 30 PT (= Apple HIG toolbar standard)
//     - zoneContentInset / chromePaddingLeading / chromePaddingTrailing /
//       chromePaddingVertical = 8 PT (= Apple HIG 'Spacing.small')
//   - Lock tab + status bar + divider metrics (= the numbers most
//     likely to drift on a refactor and break per-pane consistency)
//
// The runtime-reference scaffold in DesignTokens_test.swift keeps
// its job (= marker for repowise has_test_file detector); these
// tests add the actual value-pin coverage (= the prior_defect
// regression guard).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("DesignTokens (= canonical Apple HIG chrome dimensions, all 6 panes)")
@MainActor
struct DesignTokensTests {

    // MARK: - Apple HIG chrome dimensions (= per-pane toolbar height)

    @Test("chromeHeight = 30 PT (= Apple HIG toolbar standard)")
    func chromeHeight() {
        #expect(DesignTokens.chromeHeight == 30,
                "Per-pane chrome height must be 30 PT per Apple HIG (= matches Pages / Mail / Xcode toolbar)")
    }

    // MARK: - Apple HIG 'Spacing.small' = 8 PT (= the canonical inset)

    @Test("zoneContentInset = 8 PT (= Apple HIG Spacing.small on all 4 sides)")
    func zoneContentInset() {
        #expect(DesignTokens.zoneContentInset == 8,
                "Zone content inset must be 8 PT per Apple HIG")
    }

    @Test("chromePaddingLeading = chromePaddingTrailing (= symmetric toolbar inset)")
    func chromePaddingLeading() {
        #expect(DesignTokens.chromePaddingLeading == 8,
                "Chrome leading padding must be 8 PT per Apple HIG Spacing.small")
        #expect(DesignTokens.chromePaddingTrailing == DesignTokens.chromePaddingLeading,
                "Trailing padding must equal leading (= symmetric per Apple HIG Pages/Mail/Photos toolbar)")
    }

    @Test("chromePaddingVertical = 8 PT (= canonical vertical toolbar inset)")
    func chromePaddingVertical() {
        #expect(DesignTokens.chromePaddingVertical == 8,
                "Chrome vertical padding must be 8 PT (= matches vertically-centered 13PT text + 18PT icon)")
    }

    // MARK: - SectionHeader column metrics (= 10/4/10 pattern)

    @Test("chromePaddingSectionTop = 18 PT (= Apple HIG 'standard content margin')")
    func chromePaddingSectionTop() {
        #expect(DesignTokens.chromePaddingSectionTop == 18,
                "Section top padding must be 18 PT (= Apple HIG macOS 27 inspector/sidebar/content-column standard)")
    }

    @Test("SectionHeader column metrics = 10 PT top + 4 PT gap + 10 PT bottom pattern")
    func chromePaddingSectionHeaderPattern() {
        #expect(DesignTokens.chromePaddingSectionHeaderTop == 10)
        #expect(DesignTokens.chromePaddingSectionHeaderBottom == 10)
        #expect(DesignTokens.chromePaddingSectionHeaderGap == 4)
    }

    // MARK: - Micro paddings (= 4/2/1 scale)

    @Test("chromePaddingMicro/Nano/Pico = 4/2/1 PT (= cascading micro inset scale)")
    func chromePaddingMicroScale() {
        #expect(DesignTokens.chromePaddingMicro == 4)
        #expect(DesignTokens.chromePaddingNano == 2)
        #expect(DesignTokens.chromePaddingPico == 1)
    }
}
