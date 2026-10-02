//
//  SidebarZoneHeaderButtonsIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. SidebarZoneHeaderButtons
//  zone header icon migration: the iconName icon site
//  `Image(systemName: iconName).imageScale(.medium)`
//  replaced with `SFIcon(iconName, style: .paneTab, color: IconColor.tint)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SidebarZoneHeaderButtons icon sweep")
struct SidebarZoneHeaderButtonsIconMigrationTests {

    @Test("SidebarZoneHeaderButtons source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarZoneHeaderButtons.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "SidebarZoneHeaderButtons must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("SidebarZoneHeaderButtons zone header icon uses SFIcon style: .paneTab + .tint")
    func zoneHeaderIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarZoneHeaderButtons.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(iconName, style: .paneTab, color: IconColor.tint)"),
                "SidebarZoneHeaderButtons zone header icon must render via SFIcon(.paneTab, IconColor.tint)")
    }
}