//
//  EditorPlaceholderIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. EditorPlaceholder
//  tab-close icon migration: the X icon site on the active tab
//  `Image(systemName: "xmark").font(...).foregroundStyle(.secondary)`
//  replaced with `SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)`.
//  The surrounding .frame(width: DesignTokens.tabCloseFrameSize,
//  height: DesignTokens.tabCloseFrameSize) is a layout token and
//  is preserved (= not an icon glyph; = outside v3.0 sweep scope).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("EditorPlaceholder icon sweep")
struct EditorPlaceholderIconMigrationTests {

    @Test("EditorPlaceholder source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "EditorPlaceholder must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("EditorPlaceholder tab-close icon uses SFIcon style: .inlineSmall + .secondary")
    func tabCloseIconUsesSFIcon() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "EditorPlaceholder tab-close icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}