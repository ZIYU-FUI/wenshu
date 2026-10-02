//
//  TabContentDispatcherIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. TabContentDispatcher
//  pane close-button icon migration: the X icon site
//  `Image(systemName: "xmark").imageScale(.small).foregroundStyle(.secondary)`
//  replaced with `SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)`.
//  The surrounding .frame(width: DesignTokens.bulletSizeSmall,
//  height: DesignTokens.bulletSizeSmall) is a layout token and is
//  preserved (= not an icon glyph; = outside v3.0 sweep scope).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TabContentDispatcher icon sweep")
struct TabContentDispatcherIconMigrationTests {

    @Test("TabContentDispatcher source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "TabContentDispatcher must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("TabContentDispatcher pane close icon uses SFIcon style: .inlineSmall + .secondary")
    func paneCloseIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "TabContentDispatcher pane close icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}