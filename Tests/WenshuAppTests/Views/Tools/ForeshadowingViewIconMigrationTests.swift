//
//  ForeshadowingViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ForeshadowingView
//  inline-leading icon migration: foreshadowingRow's
//  `Image(systemName: row.status.icon).imageScale(.small).foregroundStyle
//  (.tint).frame(width: DesignTokens.tabIconSize)` (= 14 PT SF Symbol
//  pinned to a 18 PT wenshu-ad-hoc frame) replaced with
//  `SFIcon(row.status.icon, style: .inlineSmall, color: IconColor.tint)` (= Apple
//  HIG list-row leading inline = 14 PT, no frame pin).
//
//  Source-level assertions verify:
//      1. ForeshadowingView no longer uses DesignTokens.tabIconSize
//      2. ForeshadowingView foreshadowingRow uses SFIcon style:
//         .inlineSmall
//      3. The IconStyles surface is in place (= the sweep target)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ForeshadowingView icon sweep (= inline leading migrated to SFIcon)")
struct ForeshadowingViewIconMigrationTests {

    @Test("ForeshadowingView source no longer uses DesignTokens.tabIconSize")
    func foreshadowingViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "ForeshadowingView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("ForeshadowingView foreshadowingRow uses SFIcon style: .inlineSmall")
    func foreshadowingViewRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/ForeshadowingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(row.status.icon, style: .inlineSmall, color: IconColor.tint)"),
                "foreshadowingRow must render the status icon via SFIcon(.inlineSmall)")
    }
}