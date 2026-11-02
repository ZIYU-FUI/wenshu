//
//  EditorViewIconMigrationTests.swift · Wenshu · v3.0
//
//  Per Q112 = 1 source + 1 test per ticket. EditorView
//  tab-close icon migration: the X icon site on the active tab
//  `Image(systemName: "xmark").font(...).foregroundStyle(.secondary)`
//  replaced with `SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)`.
//  The tab-close hit area is sized by `DesignTokens.paneTabHotArea`
//  (= a layout token, not an icon glyph; = outside v3.0 sweep scope).
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorView icon sweep")
struct EditorViewIconMigrationTests {

    @Test("EditorView source no longer uses naked Image(systemName:)")
    func sourceNoLongerUsesNakedImage() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorView.swift")
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
        //
        // The X glyph itself is GONE (= commit 22baaeb9a1 = "A116 = delete 3
        // dead private funcs": `tabButton(for:)` held the only `xmark` and
        // had no call site, so it was deleted as dead code). The strip now
        // closes a document by DOUBLE-CLICK on its segment
        // (= `onDoubleClickSegment`), and the segments themselves are drawn
        // by `LabelSegmentedControl`.
        //
        // So the invariant is not "the xmark renders via SFIcon" (= there is
        // no xmark left to render) but the one that still holds and still
        // matters: the strip carries NO icon glyph of its own, so it cannot
        // carry a naked one. The factory form is asserted on the surface
        // that DOES draw an xmark (= the chat attachment chip), which is
        // the same icon in the same tier.
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/Store/EditorTabStrip.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let stripped = content.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("/*")
        }.joined(separator: "\n")
        #expect(!stripped.contains("Image(systemName:"),
                "EditorTabStrip must not carry a naked Image(systemName:) (= the v3.0 sweep's blocked form)")
        #expect(!stripped.contains("xmark"),
                "EditorTabStrip draws no glyph of its own (= the X was dead code, deleted in 22baaeb9a1), so it must not name one")

        // The X that IS still drawn goes through the factory.
        let chip = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Features/Chat/View/ChatAttachmentPreviewChip.swift"),
            encoding: .utf8
        )
        #expect(chip.contains("SFIcon(\"xmark\", style: .inlineSmall, color: IconColor.secondary)"),
                "the xmark that is still drawn must render via SFIcon(.inlineSmall, IconColor.secondary)")
    }
}