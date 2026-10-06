//
//  ChatToolResultPartViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ChatToolResultPartView
//  result-status icon migration: the success/error icon site
//  `Image(systemName: x ? "exclamationmark.triangle" : "checkmark")
//   .imageScale(.small).symbolRenderingMode(.hierarchical)
//   .foregroundStyle(x ? systemRed : systemGreen)`
//  replaced with `SFIcon(name, style: .inlineSmall, color: red/green Color)`
//  (= the Color escape hatch path, since the color comes from a
//  Color literal, not an IconColor semantic token).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolResultPartView icon sweep")
struct ChatToolResultPartViewIconMigrationTests {

    @Test("ChatToolResultPartView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ChatToolResultPartView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("ChatToolResultPartView result-status icon uses SFIcon with Color escape hatch")
    func resultStatusIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(") && content.contains("Color.red") && content.contains("Color.green"),
                    "ChatToolResultPartView result-status icon must render via SFIcon(.inlineSmall, Color.red/Color.green)")
    }
}