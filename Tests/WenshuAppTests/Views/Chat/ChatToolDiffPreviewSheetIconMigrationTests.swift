//
//  ChatToolDiffPreviewSheetIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ChatToolDiffPreviewSheet
//  inline-leading icon migration: doc icon site
//  `Image(systemName: "doc.text").imageScale(.small).foregroundStyle(.secondary)`
//  replaced with `SFIcon("doc.text", style: .inlineSmall, color: IconColor.secondary)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolDiffPreviewSheet icon sweep")
struct ChatToolDiffPreviewSheetIconMigrationTests {

    @Test("ChatToolDiffPreviewSheet source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ChatToolDiffPreviewSheet must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("ChatToolDiffPreviewSheet doc icon uses SFIcon style: .inlineSmall + .secondary")
    func docIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"doc.text\", style: .inlineSmall, color: IconColor.secondary)"),
                "ChatToolDiffPreviewSheet doc icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}