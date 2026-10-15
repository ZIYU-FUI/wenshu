//
//  BookSettingConstraintsViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. BookSettingConstraintsView
//  2 sites: constraintRow + violationRow, both migrated to
//  SFIcon(.inlineSmall) with severity-based color.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookSettingConstraintsView icon sweep (= inline leading migrated to SFIcon)")
struct BookSettingConstraintsViewIconMigrationTests {

    @Test("BookSettingConstraintsView source no longer uses DesignTokens.tabIconSize")
    func constraintsViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "BookSettingConstraintsView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("BookSettingConstraintsView constraintRow uses SFIcon with severity color")
    func constraintRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(constraint.severity.icon, style: .inlineSmall, color: constraint.severity == .hard ? IconColor.red : IconColor.tint)"),
                "constraintRow must render severity icon via SFIcon with .red / .tint ternary")
    }

    @Test("BookSettingConstraintsView violationRow uses SFIcon with octagon / triangle icons")
    func violationRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("violation.severity == .hard ? \"octagon\" : \"exclamationmark.triangle\""),
                "violationRow must use the octagon / triangle icon pair")
    }
}