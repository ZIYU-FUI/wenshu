//
//  IdeaLibraryViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. IdeaLibraryView 2 sites:
//  ideaRow + linkRow, both migrated to SFIcon(.inlineSmall).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("IdeaLibraryView icon sweep (= inline leading migrated to SFIcon)")
struct IdeaLibraryViewIconMigrationTests {

    @Test("IdeaLibraryView source no longer uses DesignTokens.tabIconSize")
    func ideaLibraryViewNoLongerUsesTabIconSize() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DesignTokens.tabIconSize"),
                "IdeaLibraryView must drop DesignTokens.tabIconSize for inline leading icons")
    }

    @Test("IdeaLibraryView ideaRow uses SFIcon style: .inlineSmall + .tint")
    func ideaRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(idea.status.icon, style: .inlineSmall, color: IconColor.tint)"),
                "ideaRow must render status icon via SFIcon(.inlineSmall, .tint)")
    }

    @Test("IdeaLibraryView linkRow uses SFIcon style: .inlineSmall + .tint")
    func linkRowUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(link.target.icon, style: .inlineSmall, color: IconColor.tint)"),
                "linkRow must render target icon via SFIcon(.inlineSmall, .tint)")
    }
}