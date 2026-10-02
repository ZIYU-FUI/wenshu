//
//  CharacterRelationshipsViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. CharacterRelationshipsView
//  2 sites: relationshipRow + inconsistency row, both migrated to
//  SFIcon(.inlineSmall).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("CharacterRelationshipsView icon sweep (= inline leading migrated to SFIcon)")
struct CharacterRelationshipsViewIconMigrationTests {

    @Test("CharacterRelationshipsView source no longer uses DesignTokens.tabIconSize")
    func relationshipsViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "CharacterRelationshipsView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("CharacterRelationshipsView relationshipRow uses SFIcon style: .inlineSmall + .tint")
    func relationshipRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(row.kind.icon, style: .inlineSmall, color: IconColor.tint)"),
                "relationshipRow must render kind icon via SFIcon(.inlineSmall, .tint)")
    }

    @Test("CharacterRelationshipsView inconsistency row uses SFIcon with .orange color")
    func inconsistencyRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"exclamationmark.triangle\", style: .inlineSmall, color: IconColor.orange)"),
                "inconsistency row must render triangle via SFIcon(.inlineSmall, .orange)")
    }
}