//
//  AppleSidebarBottomNewButtonIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. AppleSidebarBottomNewButton
//  inline-leading icon migration: the new-button icon site
//  `Image(systemName: "plus").imageScale(.small).foregroundStyle(.secondary)`
//  replaced with `SFIcon("plus", style: .inlineSmall, color: IconColor.secondary)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("AppleSidebarBottomNewButton icon sweep")
struct AppleSidebarBottomNewButtonIconMigrationTests {

    @Test("AppleSidebarBottomNewButton source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/AppleSidebarBottomNewButton.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "AppleSidebarBottomNewButton must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("AppleSidebarBottomNewButton new-button icon uses SFIcon style: .inlineSmall + .secondary")
    func newButtonIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Library/AppleSidebarBottomNewButton.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"plus\", style: .inlineSmall, color: IconColor.secondary)"),
                "AppleSidebarBottomNewButton new-button icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}