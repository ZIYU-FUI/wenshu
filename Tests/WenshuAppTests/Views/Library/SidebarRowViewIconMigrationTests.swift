//
//  SidebarRowViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. SidebarRowView
//  row leading icon migration: the node.systemImage icon site
//  `Image(systemName: node.systemImage).frame(width: 18)`
//  replaced with `SFIcon(node.systemImage, style: .paneTab, color: IconColor.tint).frame(width: 18)`.
//  The .frame(width: 18) is a layout token (= list-row leading icon
//  column width = 18 PT = Apple HIG sidebar list row inline) and is
//  preserved (= not an icon glyph; = outside v3.0 sweep scope).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("SidebarRowView icon sweep")
struct SidebarRowViewIconMigrationTests {

    @Test("SidebarRowView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "SidebarRowView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("SidebarRowView row leading icon uses SFIcon style: .paneTab + .tint")
    func rowLeadingIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/SidebarRowView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(node.systemImage, style: .paneTab, color: IconColor.tint)"),
                "SidebarRowView row leading icon must render via SFIcon(.paneTab, IconColor.tint)")
    }
}