//
//  TagManagerViewRound3IconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. TagManagerView
//  sweep round 3 — sweeps the remaining 2 standalone Image(systemName:)
//  sites (= remove + cancel action buttons) to SFIcon(.inlineSmall,
//  IconColor.secondary).
//
//  Distinct from TagManagerViewIconMigrationTests (= the round 1 test
//  that swept `tabIconSize` (= 18 PT frame pin) to `SFIcon(.inlineSmall)`).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TagManagerView round-3 icon sweep (= 2 standalone remove/cancel to SFIcon)")
struct TagManagerViewRound3IconMigrationTests {

    @Test("TagManagerView round-3 source no naked Image(systemName:) outside Label icon slots")
    func sourceNoNakedImageInStandalone() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return false }
            if trimmed.contains("icon: { Image(systemName:") { return false }
            return true
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "TagManagerView must drop naked Image(systemName:) in standalone sites for the v3.0 sweep round 3")
    }

    @Test("TagManagerView round-3 trash remove button uses SFIcon")
    func trashRemoveButtonUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"trash\", style: .inlineSmall, color: IconColor.secondary)"),
                "TagManagerView trash remove button must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }

    @Test("TagManagerView round-3 xmark cancel button uses SFIcon")
    func xmarkCancelButtonUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/TagManagerView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "TagManagerView xmark cancel button must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}