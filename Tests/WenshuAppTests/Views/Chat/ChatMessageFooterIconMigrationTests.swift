//
//  ChatMessageFooterIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ChatMessageFooter
//  4 metadata-prefix icons swept to SFIcon(.inlineSmall, .quaternary):
//  - clock prefix (= T65-CLOCK-PREFIX)
//  - checkmark after timestamp (= T84-DELIVERED-CHECK; Apple Messages
//    read-receipts affordance)
//  - number prefix (= T63-TOKEN-ICON)
//  - dollarsign.circle prefix (= T64-DOLLAR-ICON)
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatMessageFooter icon sweep")
struct ChatMessageFooterIconMigrationTests {

    @Test("ChatMessageFooter source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ChatMessageFooter must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("ChatMessageFooter 4 metadata icons use SFIcon(.inlineSmall, IconColor.quaternary)")
    func metadataIconsUseSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"clock\", style: .inlineSmall, color: IconColor.quaternary)"),
                "ChatMessageFooter clock prefix must use SFIcon")
        #expect(content.contains("SFIcon(\"checkmark\", style: .inlineSmall, color: IconColor.quaternary)"),
                "ChatMessageFooter checkmark must use SFIcon")
        #expect(content.contains("SFIcon(\"number\", style: .inlineSmall, color: IconColor.quaternary)"),
                "ChatMessageFooter number prefix must use SFIcon")
        #expect(content.contains("SFIcon(\"dollarsign.circle\", style: .inlineSmall, color: IconColor.quaternary)"),
                "ChatMessageFooter dollarsign.circle prefix must use SFIcon")
    }
}