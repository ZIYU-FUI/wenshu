//
//  ForeshadowingViewRound3IconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ForeshadowingView
//  sweep round 3 — sweeps the remaining 2 standalone Image(systemName:)
//  sites (remove + warning action buttons) to SFIcon(.inlineSmall).
//
//  Distinct from ForeshadowingViewIconMigrationTests (= the round 1 test
//  that swept `DesignTokens.tabIconSize` to `SFIcon(.inlineSmall)`).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ForeshadowingView round-3 icon sweep (= 2 standalone remove/warning to SFIcon)")
struct ForeshadowingViewRound3IconMigrationTests {

    @Test("ForeshadowingView round-3 source no naked Image(systemName:) outside Label icon slots")
    func sourceNoNakedImageInStandalone() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return false }
            if trimmed.contains("icon: { Image(systemName:") { return false }
            return true
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ForeshadowingView must drop naked Image(systemName:) in standalone sites for the v3.0 sweep round 3")
    }

    @Test("ForeshadowingView round-3 trash remove button uses SFIcon")
    func trashRemoveButtonUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"trash\", style: .inlineSmall, color: IconColor.secondary)"),
                "ForeshadowingView trash remove button must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }

    @Test("ForeshadowingView round-3 exclamationmark.triangle warning uses SFIcon")
    func exclamationmarkTriangleWarningUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"exclamationmark.triangle\", style: .inlineSmall, color: IconColor.orange)"),
                "ForeshadowingView exclamationmark.triangle warning must render via SFIcon(.inlineSmall, IconColor.orange)")
    }
}