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

    /// The view's two files, joined.
    ///
    /// The view's provider pane, model pane and SettingsOps plumbing live
    /// in their own file, and the rows this sweep asserts on live there,
    /// so the sweep reads both.
    private static func settingViewSource() throws -> String {
        let paths = [
            "Sources/WenshuApp/Features/Settings/View/SettingView.swift",
            "Sources/WenshuApp/Features/Settings/View/SettingView+Providers.swift",
        ]
        return try paths
            .map { try String(contentsOf: SourceLocator.url($0), encoding: .utf8) }
            .joined(separator: "\n")
    }

    @Test("SettingView source no longer uses DesignTokens.tabIconSize")
    func settingViewNoLongerUsesTabIconSize() throws {
        let content = try Self.settingViewSource()
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "SettingView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("SettingView provider key row uses SFIcon style: .inlineSmall + .green/.secondary")
    func providerKeyRowUsesSFIcon() throws {
        let content = try Self.settingViewSource()
        #expect(content.contains("SFIcon(\"key\", style: .inlineSmall, color: hasKey ? IconColor.green : IconColor.secondary)"),
                "provider key leading must render via SFIcon(.inlineSmall, hasKey ? .green : .secondary)")
    }

    @Test("SettingView AuxTask leading uses SFIcon style: .inlineSmall + .secondary")
    func auxTaskLeadingUsesSFIcon() throws {
        let content = try Self.settingViewSource()
        #expect(content.contains("SFIcon(task.icon, style: .inlineSmall, color: IconColor.secondary)"),
                "AuxTask leading must render via SFIcon(.inlineSmall, .secondary)")
    }
}