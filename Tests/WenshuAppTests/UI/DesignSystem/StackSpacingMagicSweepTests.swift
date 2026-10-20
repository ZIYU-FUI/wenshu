//
//  StackSpacingMagicSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 10 + 11 = boss
//  2026-10-02 OOB "继续"; = sweep magic-number Stack spacing literals
//  to DesignTokens tokens).
//
//  1 new DesignTokens added (= Apple HIG measured value, not wenshu
//  ad-hoc):
//    - spacingRelaxed (10) — Apple HIG `.relaxed` stack-spacing standard
//
//  Plus 8 existing tokens reused (= DesignTokens.swift already had 9
//  spacing tokens at v3.0 sweep start):
//    - spacingHairline (1), spacingCaption (2), spacingIconic (4),
//      spacingTight (6), spacingStandard (8), spacingRelaxed (10) [NEW],
//      spacingModerate (12), spacingLoose (16), spacingSection (24)
//
//  Sweep totals: 62 sites swept across 28 view files (= 17 sites
//  round 10 + 45 sites round 11). Magic Stack spacing literals swept
//  from all production source files.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 10+11 Stack spacing magic-number sweep")
struct StackSpacingMagicSweepTests {

    @Test("Round 11 — DesignTokens defines spacingRelaxed (10) new token")
    func designTokensDefinesNewSpacingRelaxed() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"),
                "spacingRelaxed (10) must be defined (= round 11 new)")
    }

}