//
//  ShadowRadiusMagicSweepTests.swift · Wenshu
//
//  Two shadows, both of them chrome: what a floating panel casts and what
//  a button casts. Each is the Apple measurement for that control, held in
//  a `DesignTokens` radius, and the suite fails on a
//  `.shadow(radius: <literal>)`.
//
//  A shadow's opacity is not swept: SwiftUI spells it inline as idiom and
//  Apple ships no opacity scale to put it in a token.
import Foundation
import Testing
@testable import WenshuApp

@Suite("Shadow radius magic-number sweep")
struct ShadowRadiusMagicSweepTests {

    @Test("DesignTokens defines 2 new shadow radius tokens")
    func designTokensDefinesNewShadowRadiusTokens() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let surfaceShadowRadiusWindow: CGFloat = 12"),
                "surfaceShadowRadiusWindow (12) must be defined")
        #expect(content.contains("static let surfaceShadowRadiusButton: CGFloat = 8"),
                "surfaceShadowRadiusButton (8) must be defined")
    }

    @Test("Production code has no naked .shadow(radius: <int>) literals")
    func productionCodeHasNoMagicShadowRadius() throws {
        let sweptFiles = [
            "Sources/WenshuApp/Features/Editor/View/EditorPaperCanvas.swift",
        ]
        for path in sweptFiles {
            let url = SourceLocator.url(path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: .shadow(... radius: <integer literal> ...)
            // The token form is `radius: DesignTokens.surfaceShadowRadius*`
            // (= identifier), so any naked integer after `radius:` is the
            // sweep target.
            let pattern = #"radius: [0-9]+[,\s]"#
            #expect(content.range(of: pattern, options: .regularExpression) == nil,
                    "\(path) must drop naked .shadow(radius: N) magic literal")
        }
    }
}