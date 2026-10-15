//
//  ShadowRadiusMagicSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= sweep round 12 = boss 2026-10-02
//  OOB "继续"; = sweep magic-number .shadow(radius: N) literals to
//  DesignTokens tokens).
//
//  2 new DesignTokens added (= Apple HIG measured values, not wenshu
//  ad-hoc):
//    - surfaceShadowRadiusWindow (12) — Apple HIG macOS window chrome shadow
//    - surfaceShadowRadiusButton (8) — Apple HIG macOS button shadow
//
//  Sites swept: 2 (= LayoutEditBar L76 floating edit-bar shadow +
//  EditorPaperCanvas L80 editor paper canvas shadow).
//
//  Note: opacity literal values (.opacity(0.5), .opacity(0.12), etc.)
//  are NOT swept (= per round 12 decision: opacity is a SwiftUI
//  idiomatic literal, no Apple HIG canonical opacity scale exists;
//  = preserving the literal pattern as SwiftUI idiomatic).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 12 shadow radius magic-number sweep")
struct ShadowRadiusMagicSweepTests {

    @Test("Round 12 — DesignTokens defines 2 new shadow radius tokens")
    func designTokensDefinesNewShadowRadiusTokens() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let surfaceShadowRadiusWindow: CGFloat = 12"),
                "surfaceShadowRadiusWindow (12) must be defined (= round 12 new)")
        #expect(content.contains("static let surfaceShadowRadiusButton: CGFloat = 8"),
                "surfaceShadowRadiusButton (8) must be defined (= round 12 new)")
    }

    @Test("Round 12 — production code has no naked .shadow(radius: <int>) literals")
    func productionCodeHasNoMagicShadowRadius() throws {
        let sweptFiles = [
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutEditBar.swift",
            "Sources/WenshuApp/Views/Workspace/EditorPaperCanvas.swift",
        ]
        for path in sweptFiles {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for: .shadow(... radius: <integer literal> ...)
            // The token form is `radius: DesignTokens.surfaceShadowRadius*`
            // (= identifier), so any naked integer after `radius:` is the
            // sweep target.
            let pattern = #"radius: [0-9]+[,\s]"#
            #expect(content.range(of: pattern, options: .regularExpression) == nil,
                    "\(path) must drop naked .shadow(radius: N) magic literal (= round 12 sweep target)")
        }
    }
}