//
//  PresetCardIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. PresetCard
//  hover-delete X icon migration: the X icon site
//  `Image(systemName: "xmark").imageScale(.small).foregroundStyle(.secondary)`
//  replaced with `SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)`.
//  The surrounding .frame(width: DesignTokens.paneTabHotArea,
//  height: DesignTokens.paneTabHotArea) is a layout token (= the
//  Apple HIG NSToolbar small item hot area = 28×28 PT) and is
//  preserved (= not an icon glyph; = outside v3.0 sweep scope).
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("PresetCard icon sweep")
struct PresetCardIconMigrationTests {

    @Test("PresetCard source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/PresetCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "PresetCard must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("PresetCard hover-delete icon uses SFIcon style: .inlineSmall + .secondary")
    func hoverDeleteIconUsesSFIcon() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/PresetCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "PresetCard hover-delete icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}