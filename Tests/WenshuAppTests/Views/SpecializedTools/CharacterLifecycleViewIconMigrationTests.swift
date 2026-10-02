//
//  CharacterLifecycleViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. CharacterLifecycleView
//  inline-leading icon migration: 2 sites (eventRow + contradiction
//  row) replaced their ad-hoc chain with SFIcon(.inlineSmall).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("CharacterLifecycleView icon sweep (= inline leading migrated to SFIcon)")
struct CharacterLifecycleViewIconMigrationTests {

    @Test("CharacterLifecycleView source no longer uses DesignTokens.tabIconSize")
    func characterLifecycleViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "CharacterLifecycleView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("CharacterLifecycleView eventRow uses SFIcon style: .inlineSmall")
    func eventRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(event.stage.icon, style: .inlineSmall, color: .tint)"),
                "eventRow must render the stage icon via SFIcon(.inlineSmall)")
    }

    @Test("CharacterLifecycleView contradiction row uses SFIcon with .orange color")
    func contradictionRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"exclamationmark.triangle\", style: .inlineSmall, color: .orange)"),
                "contradiction row must render the triangle icon via SFIcon(.inlineSmall, .orange)")
    }
}