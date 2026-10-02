//
//  ChatAttachmentPreviewChipIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ChatAttachmentPreviewChip
//  inline-leading icon migration: the clear-button icon site
//  `Image(systemName: "xmark").imageScale(.small).symbolRenderingMode(.hierarchical)
//  .aspectRatio(contentMode: .fit).frame(width: 14, height: 14)
//  .foregroundStyle(.secondary)` replaced with
//  `SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatAttachmentPreviewChip icon sweep")
struct ChatAttachmentPreviewChipIconMigrationTests {

    @Test("ChatAttachmentPreviewChip source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatAttachmentPreviewChip.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ChatAttachmentPreviewChip must drop naked Image(systemName:) for the v3.0 sweep (= the site now uses SFIcon)")
    }

    @Test("ChatAttachmentPreviewChip clear-button icon uses SFIcon style: .inlineSmall + .secondary")
    func clearButtonIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatAttachmentPreviewChip.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "ChatAttachmentPreviewChip clear-button icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}