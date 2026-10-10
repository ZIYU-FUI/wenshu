//
//  EditorViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. EditorView
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

@Suite("EditorView icon sweep")
struct EditorViewIconMigrationTests {

    @Test("EditorView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Views/Workspace/EditorView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "EditorView must drop naked Image(systemName:) for the v3.0 sweep")
    }

    @Test("EditorTabStrip tab-close icon uses SFIcon style: .inlineSmall + .secondary")
    func tabCloseIconUsesSFIcon() throws {
        // v2.x editor-tab-strip: the tab-close button moved from
        // EditorView's ad-hoc HStack into the new EditorTabStrip
        // component (= boss OOB 2026-10-10). The source-level
        // migration check now lives on EditorTabStrip.swift.
        let url = URL(fileURLWithPath: "Sources/WenshuApp/Editor/EditorTabStrip.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "EditorTabStrip tab-close icon must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}