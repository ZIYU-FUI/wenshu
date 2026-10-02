//
//  ForeshadowingViewIconStandardSizeMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ForeshadowingView
//  inline-leading icon migration: staleRow's
//  `Image(systemName: x).imageScale(.small).foregroundStyle(.secondary)
//  .frame(width: DesignTokens.iconStandardSize)` replaced with
//  `SFIcon(x, style: .inlineSmall, color: .secondary)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ForeshadowingView iconStandardSize migration")
struct ForeshadowingViewIconStandardSizeMigrationTests {

    @Test("ForeshadowingView no longer uses DesignTokens.iconStandardSize")
    func noLongerUsesIconStandardSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.iconStandardSize"),
                "ForeshadowingView must drop DesignTokens.iconStandardSize")
    }

    @Test("ForeshadowingView staleRow uses SFIcon(.inlineSmall, .secondary)")
    func staleRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(row.status.icon, style: .inlineSmall, color: .secondary)"),
                "staleRow must render the status icon via SFIcon(.inlineSmall, .secondary)")
    }
}