//
//  IdeaLibraryViewRound3IconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. IdeaLibraryView
//  sweep round 3 — sweeps the remaining 2 standalone Image(systemName:)
//  sites (remove + cancel action buttons) to SFIcon(.inlineSmall,
//  IconColor.secondary).
//
//  Distinct from IdeaLibraryViewIconMigrationTests (= the round 1 test
//  that swept `DesignTokens.tabIconSize` to `SFIcon(.inlineSmall)`).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("IdeaLibraryView round-3 icon sweep (= 2 standalone remove/cancel to SFIcon)")
struct IdeaLibraryViewRound3IconMigrationTests {

    @Test("IdeaLibraryView round-3 source no naked Image(systemName:) outside Label icon slots")
    func sourceNoNakedImageInStandalone() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return false }
            if trimmed.contains("icon: { Image(systemName:") { return false }
            return true
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "IdeaLibraryView must drop naked Image(systemName:) in standalone sites for the v3.0 sweep round 3")
    }

    @Test("IdeaLibraryView round-3 trash remove button uses SFIcon")
    func trashRemoveButtonUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"trash\", style: .inlineSmall, color: IconColor.secondary)"),
                "IdeaLibraryView trash remove button must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }

    @Test("IdeaLibraryView round-3 xmark cancel button uses SFIcon")
    func xmarkCancelButtonUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/SpecializedTools/IdeaLibraryView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "IdeaLibraryView xmark cancel button must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}