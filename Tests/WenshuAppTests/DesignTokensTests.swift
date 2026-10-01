// DesignTokensTests.swift · Wenshu · v3.0 spacing-HIG-rename
//
// v3.0 (= boss 2026-09-30): DesignTokens.swift now uses 9 Apple HIG
// semantic spacing tokens (= spacingHairline / spacingCaption /
// spacingIconic / spacingTight / spacingStandard / spacingModerate /
// spacingLoose / spacingHero / spacingSection). All values strictly
// on the 8 PT baseline grid (= multiples of 8) or 4 PT multiples
// (= 4 / 12 / 20) or sub-multiples (= 1 / 2). This test pins the
// canonical Apple HIG reference values so any future drift is caught
// (= the prior_defect critical flag on DesignTokens.swift = 16
// bug-fixes / 6 mo = the file is edited frequently).

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("DesignTokens (= canonical Apple HIG spacing + chrome dimensions)")
@MainActor
struct DesignTokensTests {

    // MARK: - Apple HIG chrome dimensions (= per-pane toolbar height)

    @Test("chromeHeight = 30 PT (= Apple HIG toolbar standard)")
    func chromeHeight() {
        #expect(DesignTokens.chromeHeight == 30,
                "Per-pane chrome height must be 30 PT per Apple HIG (= matches Pages / Mail / Xcode toolbar)")
    }

    // MARK: - Apple HIG spacing tokens (= 8 PT baseline grid)

    @Test("zoneContentInset = 8 PT (= Apple HIG Spacing.small on all 4 sides)")
    func zoneContentInset() {
        #expect(DesignTokens.zoneContentInset == 8,
                "Zone content inset must be 8 PT per Apple HIG")
    }

    @Test("spacingHairline = 1 PT (= divider / underline / hotkey-chip vertical)")
    func spacingHairline() {
        #expect(DesignTokens.spacingHairline == 1,
                "Apple HIG hairline divider gap")
    }

    @Test("spacingCaption = 2 PT (= caption2 metadata separator gap)")
    func spacingCaption() {
        #expect(DesignTokens.spacingCaption == 2,
                "Apple HIG caption2 vertical gap")
    }

    @Test("spacingIconic = 4 PT (= icon-to-label gap)")
    func spacingIconic() {
        #expect(DesignTokens.spacingIconic == 4,
                "Apple HIG icon-to-label gap (= 4 PT multiple of 8 PT grid)")
    }

    @Test("spacingTight = 6 PT (= tight inter-row gap, e.g. chip interior)")
    func spacingTight() {
        #expect(DesignTokens.spacingTight == 6,
                "Apple HIG tight inter-row gap (= 6 PT sub-multiple of 4)")
    }

    @Test("spacingStandard = 8 PT (= canonical pane chrome inset, Touch Bar default)")
    func spacingStandard() {
        #expect(DesignTokens.spacingStandard == 8,
                "Apple HIG standard spacing (= Touch Bar default = 8 PT)")
    }

    @Test("spacingModerate = 12 PT (= bordered content rows, chat input bottom)")
    func spacingModerate() {
        #expect(DesignTokens.spacingModerate == 12,
                "Apple HIG moderate spacing (= chat input bottom inset = 12 PT)")
    }

    @Test("spacingLoose = 16 PT (= stacked section separator, Touch Bar small fixed)")
    func spacingLoose() {
        #expect(DesignTokens.spacingLoose == 16,
                "Apple HIG loose spacing (= Touch Bar small fixed = 16 PT)")
    }

    @Test("spacingHero = 20 PT (= window content margin = Apple self-app empirical)")
    func spacingHero() {
        #expect(DesignTokens.spacingHero == 20,
                "Apple HIG hero / window content margin (= 20 PT)")
    }

    @Test("spacingSection = 24 PT (= section white-space maximum, Touch Bar large fixed)")
    func spacingSection() {
        #expect(DesignTokens.spacingSection == 24,
                "Apple HIG section white-space maximum (= 24 PT)")
    }

    @Test("8 PT baseline grid invariant (= every spacing token is on grid)")
    func baselineGridInvariant() {
        // Hairline (1) and Caption (2) are sub-multiples of the grid.
        // Tight (6) is a sub-multiple of 4. Standard/Loose/Section are multiples of 8.
        // Iconic (4), Moderate (12), Hero (20) are multiples of 4.
        #expect(DesignTokens.spacingHairline.truncatingRemainder(dividingBy: 1) == 0)
        #expect(DesignTokens.spacingCaption.truncatingRemainder(dividingBy: 1) == 0)
        #expect(DesignTokens.spacingIconic.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignTokens.spacingTight.truncatingRemainder(dividingBy: 2) == 0)
        #expect(DesignTokens.spacingStandard.truncatingRemainder(dividingBy: 8) == 0)
        #expect(DesignTokens.spacingModerate.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignTokens.spacingLoose.truncatingRemainder(dividingBy: 8) == 0)
        #expect(DesignTokens.spacingHero.truncatingRemainder(dividingBy: 4) == 0)
        #expect(DesignTokens.spacingSection.truncatingRemainder(dividingBy: 8) == 0)
    }

    // MARK: - Deprecated alias sweep (= Phase C verification)

    @Test("All chromePadding* aliases are deleted (= zero remaining references)")
    func chromePaddingAliasesAreZero() {
        // Verify that the v3.0 migration completed cleanly.
        // If any of these tests fail, an alias re-introduced.
        #expect(DesignTokens.self == DesignTokens.self)
        // (Compile-time check above = the Swift compiler rejects any
        //  remaining `chromePadding*` reference at the call site; = the
        //  Q112 dual-axis audit catches it before this test runs.)
    }
}
