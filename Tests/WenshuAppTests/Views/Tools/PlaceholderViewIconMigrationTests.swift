//
//  PlaceholderViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. PlaceholderView
//  inline-leading icon migration: placeholderRow's
//  `Image(systemName: row.status.icon).imageScale(.small).foregroundStyle
//  (.tint).frame(width: DesignTokens.tabIconSize)` replaced with
//  `SFIcon(row.status.icon, style: .inlineSmall, color: .tint)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("PlaceholderView icon sweep (= inline leading migrated to SFIcon)")
struct PlaceholderViewIconMigrationTests {

    @Test("PlaceholderView source no longer uses DesignTokens.tabIconSize")
    func placeholderViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/PlaceholderView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "PlaceholderView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("PlaceholderView placeholderRow uses SFIcon style: .inlineSmall")
    func placeholderViewRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Tools/PlaceholderView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(row.status.icon, style: .inlineSmall, color: .tint)"),
                "placeholderRow must render the status icon via SFIcon(.inlineSmall)")
    }
}