//
//  ChapterFocusLockBadgeIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. ChapterFocusLockBadge
//  inline icon migration: the pencil-and-outline icon site
//  `Image(systemName: "pencil.and.outline").imageScale(.small).foregroundStyle(.tertiary)`
//  replaced with `SFIcon("pencil.and.outline", style: .inlineSmall, color: IconColor.tertiary)`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockBadge icon sweep")
struct ChapterFocusLockBadgeIconMigrationTests {

    @Test("ChapterFocusLockBadge source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/ChapterFocusLockBadge.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "ChapterFocusLockBadge must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("ChapterFocusLockBadge inline icon uses SFIcon style: .inlineSmall + .tertiary")
    func inlineIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/ChapterFocusLockBadge.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"pencil.and.outline\", style: .inlineSmall, color: IconColor.tertiary)"),
                "ChapterFocusLockBadge inline icon must render via SFIcon(.inlineSmall, IconColor.tertiary)")
    }
}