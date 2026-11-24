//
//  StackSpacingMagicSweepTests.swift · Wenshu
//
//  A stack's spacing is one of the named steps in the scale, from a
//  hairline to a section. The steps exist because a layout reads as a
//  system only while the same gaps keep recurring; a per-site number is a
//  gap a reader has to re-justify, and two sites that meant the same gap
//  stop saying so.
//
//  `spacingRelaxed` is Apple's relaxed stack figure; the rest of the scale
//  was already there. `spacing: 0` is not a step — it is the absence of
//  one, and stays a literal.
import Foundation
import Testing
@testable import WenshuApp

@Suite("Stack spacing magic-number sweep")
struct StackSpacingMagicSweepTests {

    @Test("DesignTokens defines spacingRelaxed (10) new token")
    func designTokensDefinesNewSpacingRelaxed() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let spacingRelaxed: CGFloat = 10"),
                "spacingRelaxed (10) must be defined")
    }

}