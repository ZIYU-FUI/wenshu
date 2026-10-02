//
//  SettingViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. SettingView 2 sites:
//  provider-key leading + AuxTask leading, both migrated to
//  SFIcon(.inlineSmall).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SettingView icon sweep (= inline leading migrated to SFIcon)")
struct SettingViewIconMigrationTests {

    @Test("SettingView source no longer uses DesignTokens.tabIconSize")
    func settingViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Settings/SettingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "SettingView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("SettingView provider key row uses SFIcon style: .inlineSmall + .green/.secondary")
    func providerKeyRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Settings/SettingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"key\", style: .inlineSmall, color: hasKey ? IconColor.green : IconColor.secondary)"),
                "provider key leading must render via SFIcon(.inlineSmall, hasKey ? .green : .secondary)")
    }

    @Test("SettingView AuxTask leading uses SFIcon style: .inlineSmall + .secondary")
    func auxTaskLeadingUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Settings/SettingView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(task.icon, style: .inlineSmall, color: IconColor.secondary)"),
                "AuxTask leading must render via SFIcon(.inlineSmall, .secondary)")
    }
}